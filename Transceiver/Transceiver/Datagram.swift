//  Datagram.swift
//  Simplenet Datagram module
//  Copyright (c) 2018 Vladimir Raisov. All rights reserved.
//  Licensed under MIT License

import Darwin.POSIX
import struct Foundation.Data
import Sockets
import Interfaces

/// A type of `delegate` property in `Receiver` and `Transmitter` classes
public protocol DatagramHandler {
    /// Сalled when a datagram is received.
    /// - parameter datagram: incomming datagram
    func dataDidRead(_ datagram: Datagram)
    /// Called when error occured during datagram reception;
    /// can also be called for an asynchronous error associated with the sent datagram.
    /// - parameter error: should be casted to SocketError type
    func errorDidOccur(_ error: Error)
}

/// Default handler demonstrating the simplest error handling method
extension DatagramHandler {
    public func errorDidOccur(_ error: Error) {
    }
}

extension msghdr {
    /// Enumerated ancillary data from incomming datagram;
    /// performs the functions of the CMSG_FIRSTHDR, CMSG_NXTHDR and CMSG_DATA C macros.
    var ancillaries: AnySequence<UnsafePointer<cmsghdr>> {
        func align(_ n: Int) -> Int {return (n + 3) & ~3}
        guard let p = UnsafeRawPointer(self.msg_control) else {
            return AnySequence(AnyIterator{nil})
        }
        var loc = 0
        let length = Int(self.msg_controllen)
        return AnySequence(
            AnyIterator {
                guard loc + align(MemoryLayout<cmsghdr>.size) < length else {return nil}
                let cmsg_p = p.advanced(by: loc).bindMemory(to: cmsghdr.self, capacity: 1)
                loc += Int(cmsg_p.pointee.cmsg_len)
                guard loc <= length else {return nil}
                return cmsg_p
            }
        )
    }
}

/// Represents incoming datagram
public struct Datagram {
    private let buf: Data
    private var iov: iovec
    private var msg: msghdr

    private var socket: Socket

    /// Creates Datagram using `recvmsg` function.
    /// - Parameters:
    ///     - socket: socket from which the datagram should be read.
    ///     - maxDataLength: maximum expected length of the data to read.
    ///     - maxAncillaryLength: maximum expected ancillary data length.
    /// - Throws: SocketError
    public init(_ handle: Int32, maxDataLength: Int, maxAncillaryLength: Int = 256) throws {
        let prefixLength = maxAncillaryLength + MemoryLayout<sockaddr_storage>.size
        let capacity = prefixLength + maxDataLength
        let buf_p = UnsafeMutableRawPointer.allocate(bytes: capacity, alignedTo: MemoryLayout<cmsghdr>.alignment)
        // FIXME: when 9.3 will be available, replace with .allocate(bytesCount: needed, alignment: MemoryLayout<rt_msghdr>.alignment
        self.buf = Data(bytesNoCopy: buf_p, count: capacity, deallocator: .custom {
            $0.deallocate(bytes: $1, alignedTo: MemoryLayout<cmsghdr>.alignment)
            // FIXME: when 9.3 will be available, replace with .deallocate()
            })

        self.iov = iovec(
            iov_base: buf_p.advanced(by: prefixLength),
            iov_len: maxDataLength
        )
        self.msg = msghdr(
            msg_name: buf_p.advanced(by: maxAncillaryLength),
            msg_namelen: socklen_t(MemoryLayout<sockaddr_storage>.size),
            msg_iov: &self.iov,
            msg_iovlen: 1,
            msg_control: buf_p,
            msg_controllen: numericCast(maxAncillaryLength),
            msg_flags: 0
        )
        self.socket = try Socket(handle)
        self.iov.iov_len = try bsd(Darwin.recvmsg(handle, &self.msg, 0))
        assert(!self.ancillaryDataTruncated)
    }

    /// Datagram payload.
    public var data: Data {
        return Data(bytes: self.iov.iov_base, count: self.iov.iov_len)
    }

    /// `true`, if `maxDataLength` value is not enough to read all received data.
    public var dataTruncated: Bool {
        return self.msg.msg_flags & MSG_TRUNC != 0
    }

    /// `true`, if `maxAncillaryLength` value is not enough to place ancillary data.
    public var ancillaryDataTruncated: Bool {
        return self.msg.msg_flags & MSG_CTRUNC != 0
    }

    /// Datagram sender address.
    public var sender: InternetAddress? {
        return self.msg.msg_name.assumingMemoryBound(to: sockaddr.self).internetAddress
    }

    /// Recipient address, broadcast or multicast group address.
    public var destination: IPAddress? {
        for p in self.msg.ancillaries {
            if p.pointee.cmsg_level == IPPROTO_IP && p.pointee.cmsg_type == IP_RECVDSTADDR {
                return p.advanced(by: 1).withMemoryRebound(to: in_addr.self, capacity: 1) {
                    $0.pointee
                }
            }
            if p.pointee.cmsg_level == IPPROTO_IP && p.pointee.cmsg_type == IP_RECVPKTINFO {
                return p.advanced(by: 1).withMemoryRebound(to: in_pktinfo.self, capacity: 1) {
                    $0.pointee.ipi_addr
                }
            }
            if p.pointee.cmsg_level == IPPROTO_IPV6 && p.pointee.cmsg_type == IPV6_2292PKTINFO {
                return p.advanced(by: 1).withMemoryRebound(to: in6_pktinfo.self, capacity: 1) {
                    $0.pointee.ipi6_addr
                }
            }
       }
        return nil
    }

    /// Interface through which the datagram was received.
    public var interface: Interface? {
        let index = {() -> Int32 in
            for p in self.msg.ancillaries {
                if p.pointee.cmsg_level == IPPROTO_IP && p.pointee.cmsg_type == IP_RECVIF {
                    return p.advanced(by: 1).withMemoryRebound(to: sockaddr_dl.self, capacity: 1) {
                        numericCast($0.pointee.sdl_index)
                    }
                }
                if p.pointee.cmsg_level == IPPROTO_IP && p.pointee.cmsg_type == IP_RECVPKTINFO {
                    return p.advanced(by: 1).withMemoryRebound(to: in_pktinfo.self, capacity: 1) {
                        numericCast($0.pointee.ipi_ifindex)
                    }
                }
                if p.pointee.cmsg_level == IPPROTO_IPV6 && p.pointee.cmsg_type == IPV6_2292PKTINFO {
                    return p.advanced(by: 1).withMemoryRebound(to: in6_pktinfo.self, capacity: 1) {
                        numericCast($0.pointee.ipi6_ifindex)
                    }
                }
            }
            return 0
        }()
        return Interfaces().first{$0.index == index}
    }

    /// Sends a rеsponce to this datagram.
    /// - parameter data: content of the responce.
    /// - Throws: SocketError
    public func reply(with data: Data) throws {
        let localAddress = self.socket.localAddress!
        let family = type(of: localAddress.ip).family
        assert(self.sender != nil)
        guard let peer = self.sender else {return}
        if family == .ip4 && localAddress.isWildcard || localAddress.isMulticast,
            let interface = self.interface {
            let replySocket = try Socket(family: SocketAddressFamily(family), type: .datagram)
            switch family {
            case .ip4:
                try replySocket.set(option: IP_BOUND_IF, level: IPPROTO_IP, value: interface.index)
            case .ip6:
                try replySocket.set(option: IPV6_BOUND_IF, level: IPPROTO_IPV6, value: interface.index)
            }
            try replySocket.sendTo(peer, data: data)
        } else {
            try self.socket.sendTo(peer, data: data)
        }
    }
}

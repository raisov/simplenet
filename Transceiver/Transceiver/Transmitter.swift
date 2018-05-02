//  Transmitter.swift
//  Simplenet Datagram module
//  Copyright (c) 2018 Vladimir Raisov. All rights reserved.
//  Licensed under MIT License

import Darwin.POSIX
import Dispatch
import struct Foundation.Data
import Sockets
import Interfaces

public class Transmitter {
    private let socket: Socket
    private var source: DispatchSourceRead

    public var delegate: DatagramHandler? {
        willSet {
            guard self.delegate != nil else {return}
            self.source.suspend()
        }
        didSet {
            guard let handler = delegate else {return}
            source.setEventHandler {[handler, source] in
                let handle = Int32(source.handle)
                let length = Int(source.data)
                do {
                    handler.dataDidRead(try Datagram(handle,
                                                     maxDataLength: length,
                                                     maxAncillaryLength: 72))
                } catch {
                    handler.errorDidOccur(error)
                }
            }
            source.resume()
        }
    }

    /// Creates transmitter to send unicast, multicast and broadcast datagram
    /// - Parameters:
    ///     - host: host to which datagrams will be sent;
    ///       for multicast, IPv4 of IPv6 multicast groupaddress;
    ///       if omitted, broadcast datagrams will be sent.
    ///     - port: port to which datagrams will be sent.
    ///     - interface: network interface through wich datagrams will be sent;
    ///       if omitted, default interface, selected by operating system, will be used.
    /// - Throws: SocketError, InternetAddressError
    public init(host: String? = nil, port: UInt16,  interface: Interface? = nil) throws {
        let address = try host.map{try getInternetAddresses(for: $0, port: port).first!} ??
            (interface?.broadcast ?? in_addr(s_addr: INADDR_BROADCAST)).with(port: port)
        let multicast = address.isMulticast
        let family = type(of: address.ip).family
        self.socket = try Socket(family: SocketAddressFamily(family), type: .datagram)
        if let index = interface?.index ?? ((address as? sockaddr_in6)?.sin6_scope_id).map(numericCast) {
            switch family {
            case .ip4:
                try self.socket.set(option: IP_BOUND_IF, level: IPPROTO_IP, value: index)
            case .ip6:
                try self.socket.set(option: IPV6_BOUND_IF, level: IPPROTO_IPV6, value: index)
                if multicast {
                   try self.socket.set(option: IPV6_MULTICAST_IF, level: IPPROTO_IPV6, value: index)
                   try self.socket.enable(option: IPV6_MULTICAST_LOOP, level: IPPROTO_IPV6)
                }
            }
        }
        self.socket.nonBlockingOperations = true
        try self.socket.connectTo(address)
        let localAddress = self.socket.localAddress!

        func broadcast() -> Bool {
            guard let ip4local = localAddress.ip as? in_addr else {return false}
            guard let brd = (Interfaces().first{$0.ip4.contains(ip4local)})?.broadcast else {return false}
            guard let ip4 = address.ip as? in_addr else {return false}
            return ip4 == brd || ip4.s_addr == INADDR_BROADCAST
        }

        if multicast {
            let socket = try Socket(family: SocketAddressFamily(family), type: .datagram)
            if let ip4 = localAddress.ip as? in_addr {
                let index = (Interfaces().first{$0.ip4.contains(ip4)})?.index ?? 0
                try self.socket.enable(option: IP_MULTICAST_LOOP, level: IPPROTO_IP)
                try self.socket.set(option: IP_MULTICAST_IFINDEX, level: IPPROTO_IP, value: index)
            }
            try socket.enable(option: SO_REUSEADDR, level: SOL_SOCKET)
            try socket.enable(option: SO_REUSEPORT, level: SOL_SOCKET)
            try socket.bind(localAddress)
            let handle = try socket.duplicateDescriptor()
            self.source = DispatchSource.makeReadSource(fileDescriptor: handle)
        } else if broadcast() {
            try self.socket.enable(option: SO_BROADCAST, level: SOL_SOCKET)
            let socket = try Socket(family: .inet, type: .datagram)
            try socket.enable(option: SO_REUSEADDR, level: SOL_SOCKET)
            try socket.enable(option: SO_REUSEPORT, level: SOL_SOCKET)
            try socket.bind(localAddress)
            let handle = try socket.duplicateDescriptor()
            self.source = DispatchSource.makeReadSource(fileDescriptor: handle)
        } else {
            let handle = try self.socket.duplicateDescriptor()
            self.source = DispatchSource.makeReadSource(fileDescriptor: handle)
        }
        let socket = try Socket(numericCast(self.source.handle))
        socket.nonBlockingOperations = true
        switch family {
        case .ip4:
            try socket.enable(option: IP_RECVIF, level: IPPROTO_IP) // 32
            try socket.enable(option: IP_RECVDSTADDR, level: IPPROTO_IP) // 16
            try socket.enable(option: IP_RECVPKTINFO, level: IPPROTO_IP) // 24
        case .ip6:
            try socket.enable(option: IPV6_2292PKTINFO, level: IPPROTO_IPV6)
        }
        source.setCancelHandler{[handle = source.handle] in
            Darwin.close(Int32(handle))
        }
    }

    /// Sends datagram to destination specified when transmitter created.
    /// - parameter data: payload of a datagram.
    /// - Throws: SocketError
    public func send(data: Data) throws {
        try self.socket.send(data)
    }
}

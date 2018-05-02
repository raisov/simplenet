//  Socket.swift
//  Simplenet Socket module
//  Copyright (c) 2018 Vladimir Raisov. All rights reserved.
//  Licensed under MIT License

import Darwin.POSIX
import struct Foundation.Data

/// Simply wraps the raw socket handle to create
/// namespace for socket related functions
/// and for using Swift memory management
/// to control socket life time.
public class Socket {

    public enum SocketType: RawRepresentable {
        case stream, datagram, raw, seqpacket
        public init?(rawValue: Int32) {
            switch rawValue {
            case SOCK_STREAM: self = .stream
            case SOCK_DGRAM: self = .datagram
            case SOCK_RAW: self = .raw
            case SOCK_SEQPACKET: self = .seqpacket
            default:
                return nil
            }
        }
        public var rawValue: Int32 {
            switch self {
            case .stream: return SOCK_STREAM
            case .datagram: return SOCK_DGRAM
            case .raw: return SOCK_RAW
            case .seqpacket: return SOCK_SEQPACKET
            }
        }
    }

    public enum `Protocol`: RawRepresentable {
        case tcp, udp, icmp, icmpv6
        public init?(rawValue: Int32) {
            switch rawValue {
            case IPPROTO_TCP: self = .tcp
            case IPPROTO_UDP: self = .udp
            case IPPROTO_ICMP: self = .icmp
            case IPPROTO_ICMPV6: self = .icmpv6
            default:
                return nil
            }
        }
        public var rawValue: Int32 {
            switch self {
            case .tcp: return IPPROTO_TCP
            case .udp: return IPPROTO_UDP
            case .icmp: return IPPROTO_ICMP
            case .icmpv6: return IPPROTO_ICMPV6
            }
        }
    }



    /// Native socket handle
    fileprivate let handle: Int32

    /// Creates Socket by duplicating given handle.
    /// - Parameter handle: active socket descriptor.
    /// - Throws: SocketError (.badDescriptor or .tooManyDescriptors)
    public required init(_ handle: Int32) throws {
        self.handle = try bsd(Darwin.dup(handle))
    }

    /// Creates Socket from scratch.
    /// - Parameters:
    ///     - family: selects the protocol family which should be used;
    ///       has a same values as a socket address family.
    ///     - type: specifies the mode of socket communication.
    ///     - protocol: communication protocol to be used; when omitted is
    ///                 determined by the values of `type` and` family`.
    /// - Throws: SocketError.
    /// - SeeAlso: man 2 socket.
    public init(family: SocketAddressFamily, type: SocketType = .datagram, protocol: Protocol? = nil) throws {
        self.handle = try bsd(Darwin.socket(family.rawValue, type.rawValue, `protocol`?.rawValue ?? 0))
    }

    /// Duplicate self socket descriptor for external use.
    /// - Returns: duplicated socket descriptor.
    /// - Throws: SocketError .tooManyDescriptor.
    public func duplicateDescriptor() throws -> Int32 {
        return try bsd(Darwin.dup(self.handle))
    }

    deinit {
        Darwin.close(self.handle)
    }
}

extension Socket {
    /// Address bound to socket
    public var localAddress: InternetAddress? {
        get {
            var ss = sockaddr_storage()
            return (try? withSockaddrMutablePointer(to: &ss) {(sa_p, length_p) in
                try bsd(getsockname(self.handle, sa_p, length_p))
                return sa_p.internetAddress
            }).flatMap{$0}
        }
    }

    ///address to which the socket is connected
    public var remoteAddress: InternetAddress? {
        get {
            var ss = sockaddr_storage()
            return (try? withSockaddrMutablePointer(to: &ss) {(sa_p, length_p) in
                try bsd(getpeername(self.handle, sa_p, length_p))
                return sa_p.internetAddress
                }).flatMap{$0}
        }
    }

    public func bind(_ address: InternetAddress) throws {
        try address.withSockaddrPointer {sa_p, length in
            try bsd(Darwin.bind(self.handle, sa_p, length))
        }
    }

    public func connectTo(_ address: InternetAddress) throws {
        try address.withSockaddrPointer {sa_p, length in
            try bsd(Darwin.connect(self.handle, sa_p, length))
        }
    }

    @discardableResult
    public func sendTo(_ address: InternetAddress, data: Data, flags: Int32 = 0) throws -> Int {
        return try data.withUnsafeBytes {(p: UnsafePointer<Int8>) in
            return try address.withSockaddrPointer {sa_p, length in
                try bsd(Darwin.sendto(self.handle, p, data.count, flags, sa_p, length))
            }
        }
    }

    @discardableResult
    public func send(_ data: Data, flags: Int32 = 0) throws -> Int {
        return try data.withUnsafeBytes {(p: UnsafePointer<Int8>) in
            try bsd(Darwin.send(self.handle, p, data.count, flags))
        }
    }
}

extension Socket {
    /// Get/set socket non blocking mode.
    /// True if socket is in asynchronous (non blocking) mode.
    public var nonBlockingOperations: Bool {
        get {
            let flags = try! bsd(fcntl(self.handle, F_GETFL))
            return (flags & O_NONBLOCK) != 0
        }

        set {
            var flags = try! bsd(fcntl(self.handle, F_GETFL))
            flags = newValue ? flags | O_NONBLOCK : flags & ~O_NONBLOCK
            try! bsd(fcntl(self.handle, F_SETFL, flags))
        }
    }
}

extension Socket {

    /// Get the value of an integer socket option.
    /// - Parameters:
    ///     - option: option code.
    ///     - level: SOL_SOCKET for socket level options or protocol number.
    /// - Returns: option value.
    /// - Throws: SocketError.
    /// - Notes: For socket level options, see `man 2 setsockopt`.
    ///          for IPPROTO_IP level see `man 4 ip`;
    ///          for IPPROTO_IPV6 see `man 4 ip6`.
    public func get(option: Int32, level: Int32) throws -> Int32 {
        var v = Int32(0)
        var l = socklen_t(MemoryLayout.size(ofValue: v))
        try bsd(getsockopt(self.handle, level, option, &v, &l))
        return v
    }

    /// Set the value of an integer socket option.
    /// - Parameters:
    ///     - option: option code.
    ///     - level: SOL_SOCKET for socket level options or protocol number.
    ///     - value: new value for option.
    /// - Throws: SocketError.
    /// - Notes: For socket level options, see `man 2 setsockopt`.
    ///          for IPPROTO_IP level see `man 4 ip`;
    ///          for IPPROTO_IPV6 see `man 4 ip6`.
    public func set(option: Int32, level: Int32, value: Int32) throws {
        var v = value
        let length = socklen_t(MemoryLayout.size(ofValue: value))
        try bsd(setsockopt(self.handle, level, option, &v, length))
    }

    /// Set the boolean socket option to `true`.
    /// - Parameters:
    ///     - option: option code.
    ///     - level: SOL_SOCKET for socket level options or protocol number.
    /// - Throws: SocketError.
    /// - Notes: For socket level options, see `man 2 setsockopt`.
    ///          for IPPROTO_IP level see `man 4 ip`;
    ///          for IPPROTO_IPV6 see `man 4 ip6`.
    public func enable(option: Int32, level: Int32) throws {
        try self.set(option: option, level: level, value: 1)
    }

    /// Set the boolean socket option to `false`.
    /// - Parameters:
    ///     - option: option code.
    ///     - level: SOL_SOCKET for socket level options or protocol number.
    /// - Throws: SocketError.
    /// - Notes: For socket level options, see `man 2 setsockopt`.
    ///          for IPPROTO_IP level see `man 4 ip`;
    ///          for IPPROTO_IPV6 see `man 4 ip6`.
    public func disable(option: Int32, level: Int32) throws {
        try self.set(option: option, level: level, value: 0)
    }


    /// Get the boolean socket option value.
    /// - Parameters:
    ///     - option: option code.
    ///     - level: SOL_SOCKET for socket level options or protocol number.
    /// - Returns: option value.
    /// - Throws: SocketError.
    /// - Notes: For socket level options, see `man 2 setsockopt`.
    ///          for IPPROTO_IP level see `man 4 ip`;
    ///          for IPPROTO_IPV6 see `man 4 ip6`.
    public func enabled(option: Int32, level: Int32) throws -> Bool {
        return try self.get(option: option, level: level) != 0
    }
}

extension Socket {
    /// Join to multicast group.
    /// - Parameters:
    ///     - group: address of group to join.
    ///     - index: index of the interface through which multicast messages will be received;
    ///         if 0, default interface will be used.
    public func joinToMulticast(_ group: IPAddress, interfaceIndex index: Int32 = 0) throws {
        assert(group.isMulticast)
        let level = type(of: group).family == .ip4 ? IPPROTO_IP : IPPROTO_IPV6
        var req = group_req(gr_interface: UInt32(index), gr_group: sockaddr_storage(group.with(port: 0)))
        try bsd(setsockopt(self.handle,
                           level, MCAST_JOIN_GROUP,
                           &req, socklen_t(MemoryLayout<group_req>.size)))
    }
}

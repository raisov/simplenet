//  sockaddr.swift
//  Simplenet SocketAddress module
//  Copyright (c) 2018 Vladimir Raisov. All rights reserved.
//  Licensed under MIT License

import Darwin.POSIX

/// Address families, the same as protocol families.
public enum SocketAddressFamily: RawRepresentable {
    /// Unix pipe
    case unix
    /// IPv4
    case inet
    /// IPv6
    case inet6
    /// Link layer interface
    case link

    public init?(rawValue: Int32) {
        switch rawValue {
        case AF_UNIX: self = .unix
        case AF_INET: self = .inet
        case AF_INET6: self = .inet6
        case AF_LINK: self = .link
        default:
            return nil
        }
    }

    public var rawValue: Int32 {
        switch self {
        case .unix: return AF_UNIX
        case .inet: return AF_INET
        case .inet6: return AF_INET6
        case .link: return AF_LINK
        }
    }
}

/// Conforms to all kind of sockaddr structs.
public protocol SocketAddress {
    /// Address family associated to some type of sockaddr;
    /// for example .inet for sockaddr_in.
    static var family: SocketAddressFamily {get}
    /// Address family from sockaddr header.
    var family: SocketAddressFamily? {get}
    /// Length of sockaddr structure fram header.
    var length: Int {get}
    /// True if sockaddr has a correct header.
    var isWellFormed: Bool {get}
}

extension SocketAddress {
    /// Default implementation for a `isWellFormed` property.
    public var isWellFormed: Bool {
        return self.family == Self.family && self.length <= MemoryLayout<Self>.size
    }
}

extension SocketAddress {
    /// Executes functions with a sockaddr pointer as input parameter;
    /// such as `bind`, `connect` or `sendto`.
    /// - parameter body: A closure that takes a sockaddr pointer and sockaddr length as input parameters.
    /// - Returns: the return value of the `body`.
    @discardableResult
    public func withSockaddrPointer<Result>(_ body: (UnsafePointer<sockaddr>, socklen_t) throws -> Result) rethrows -> Result {
        assert(self.isWellFormed)
        var sa = self
        let length = socklen_t(self.length)
        return try withUnsafePointer(to: &sa) {
            try $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                try body($0, length)
            }
        }
    }
}

/// Executes functions that require a pointer to memory where sockaddr will be placed;
/// such as `getsockaddr` or `recvfrom`.
/// - Rarameters:
///     - sa: variable of type `T` large enough to accommodate the returned sockaddr;
///           `sockaddr_storage` recomended.
///     - body: Closure that takes a pointer to the memory buffer to place
///             the returned sockaddr and a pointer to socklen_t variable
///             to place returned sockaddr length.
/// - Returns: the return value of the `body`.
public func withSockaddrMutablePointer<T, Result>(to sa: inout T, _ body: (UnsafeMutablePointer<sockaddr>, UnsafeMutablePointer<socklen_t>) throws -> Result) rethrows -> Result {
    var length = socklen_t(MemoryLayout<T>.size)
    return try withUnsafeMutablePointer(to: &sa) {sa_p in
        return try sa_p.withMemoryRebound(to: sockaddr.self, capacity: 1) {
            let result = try body($0, &length)
            assert(numericCast($0.pointee.sa_len) == length)
            return result
        }
    }
}

// IP address family.
public enum IPFamily: RawRepresentable {
    case ip4, ip6
    public init?(rawValue: Int32) {
        switch rawValue {
        case AF_INET: self = .ip4
        case AF_INET6: self = .ip6
        default:
            return nil
        }
    }

    public var rawValue: Int32 {
        switch self {
        case .ip4: return AF_INET
        case .ip6: return AF_INET6
        }
    }

    /// The wilcard IP address of a particular family
    public var wildcard: IPAddress {
        switch self {
        case .ip4: return in_addr(s_addr: INADDR_ANY)
        case .ip6: return in6addr_any
        }
    }
}

// Casts `IPFamily` to `SocketAddressFamily`.
extension SocketAddressFamily {
    public init(_ family: IPFamily) {
        self.init(rawValue: family.rawValue)!
    }
}

// Used to unify IPv4 and IPv6 addresses processing.
public protocol IPAddress {
    static var family: IPFamily  {get}
    var isWildcard: Bool {get}
    var isLoopback: Bool {get}
    var isMulticast: Bool {get}
    /// Makes internet address with this IP and given port.
    func with(port: UInt16) -> InternetAddress
}


// MARK: in_addr extensions
extension in_addr : IPAddress {
    public static var family: IPFamily  {return .ip4}
    public var isWildcard: Bool {return self.s_addr == INADDR_ANY.bigEndian}
    public var isLoopback: Bool {return self.s_addr == INADDR_LOOPBACK.bigEndian}
    public var isMulticast: Bool {return (self.s_addr & 0xf0) == 0xe0}

    public func with(port: UInt16 = 0) -> InternetAddress {
        return sockaddr_in(self, port: port)
    }
}

extension in_addr : Equatable {
    public static func == (lhs: in_addr, rhs: in_addr) -> Bool {
        return lhs.s_addr == rhs.s_addr
    }
}

// MARK: in6_addr extensions
extension in6_addr : IPAddress {
    public static var family: IPFamily  {return .ip6}
    public var isWildcard: Bool {return self == in6addr_any}
    public var isLoopback: Bool {return self == in6addr_loopback}
    public var isMulticast: Bool {return self.__u6_addr.__u6_addr8.0 == 0xff}

    public func with(port: UInt16 = 0) -> InternetAddress {
        return sockaddr_in6(self, port: port)
    }
}

extension in6_addr : Equatable {
    public static func == (lhs: in6_addr, rhs: in6_addr) -> Bool {
        return lhs.__u6_addr.__u6_addr32 == rhs.__u6_addr.__u6_addr32
    }
}

/// Special kind of SocketAddress for IP address families.
public protocol InternetAddress: SocketAddress, CustomStringConvertible, CustomDebugStringConvertible {
    var port: UInt16 {get}
    var isWildcard: Bool {get}
    var isLoopback: Bool {get}
    var isMulticast: Bool {get}
    var ip: IPAddress {get}
}

extension InternetAddress {
    public static var length: Int {return MemoryLayout<Self>.size}
    public var isWellFormed: Bool {
        return self.family == Self.family && self.length == Self.length
    }
}

extension InternetAddress {
    public var isWildcard: Bool {
        return self.ip.isWildcard
    }

    public var isLoopback: Bool {
        return self.ip.isLoopback
    }

    public var isMulticast: Bool {
        return self.ip.isMulticast
    }
}

// MARK: sockaddr_in extensions
extension sockaddr_in {
    public init(_ address: in_addr = in_addr(s_addr: INADDR_ANY), port: UInt16) {
        self.init(sin_len: __uint8_t(MemoryLayout<sockaddr_in>.size),
                  sin_family: sa_family_t(AF_INET),
                  sin_port: port.byteSwapped,
                  sin_addr: address,
                  sin_zero: (0, 0, 0, 0, 0, 0, 0, 0)
        )
    }
}

extension sockaddr_in: InternetAddress {
    public static var family: SocketAddressFamily  {return SocketAddressFamily(in_addr.family)}
    public var family: SocketAddressFamily? {return SocketAddressFamily(rawValue: numericCast(self.sin_family))}
    public var length: Int {return Int(self.sin_len)}
    public var port: UInt16 {return self.sin_port.byteSwapped}
    public var ip: IPAddress {return self.sin_addr}
}

// MARK: sockaddr_in6 extensions
extension sockaddr_in6 {
    public init(_ address: in6_addr = in6addr_any, port: UInt16, flowinfo: UInt32 = 0, scope: UInt32 = 0) {
        self.init(sin6_len: __uint8_t(MemoryLayout<sockaddr_in6>.size),
                  sin6_family: sa_family_t(AF_INET6),
                  sin6_port: port.byteSwapped,
                  sin6_flowinfo: flowinfo,
                  sin6_addr: address,
                  sin6_scope_id: scope
        )
    }
}

extension sockaddr_in6: InternetAddress {
    public static var family: SocketAddressFamily {return SocketAddressFamily(in6_addr.family)}
    public var family: SocketAddressFamily? {return SocketAddressFamily(rawValue: numericCast(self.sin6_family))}
    public var length: Int {return Int(self.sin6_len)}
    public var port: UInt16 {return self.sin6_port.byteSwapped}
    public var ip: IPAddress {return self.sin6_addr}
}

// MARK: sockaddr_storage extensions
extension sockaddr_storage {
    public init(_ address: InternetAddress) {
        self.init()
        withUnsafeMutablePointer(to: &self) {ss_p in
            if let sin = address as? sockaddr_in {
                ss_p.withMemoryRebound(to: sockaddr_in.self, capacity: 1) {
                    $0.pointee = sin
                }
            } else if let sin6 = address as? sockaddr_in6 {
                ss_p.withMemoryRebound(to: sockaddr_in6.self, capacity: 1) {
                    $0.pointee = sin6
                }
            }
        }
    }
}

// MARK: sockaddr_dl extensions
extension sockaddr_dl: SocketAddress {
    public static var family: SocketAddressFamily {return .link}
    public var length: Int {return numericCast(self.sdl_len)}
    public var family: SocketAddressFamily? {return SocketAddressFamily(rawValue: numericCast(self.sdl_family))}
    public var isWellFormed: Bool {
        return self.family == sockaddr_dl.family &&
        self.sdl_len >= self.headerSize + Int(self.sdl_alen + self.sdl_nlen + self.sdl_slen)
    }
}

extension sockaddr_dl {
    public var index: UInt32 {return numericCast(self.sdl_index)}
    public var type: Int32 {return numericCast(self.sdl_type)}
    var headerSize: Int {return MemoryLayout<sockaddr_dl>.size - MemoryLayout.size(ofValue: self.sdl_data)}
}

extension UnsafePointer where Pointee == sockaddr_dl {
    public var length: Int {return self.pointee.length}
    public var index: UInt32 {return self.pointee.index}
    public var type: Int32 {return self.pointee.type}
    
    public var name: String {
        guard self.pointee.isWellFormed else {return ""}
        return self.withMemoryRebound(to: CChar.self, capacity: self.length) {
            // some extra code to eliminate using NSString
            var name = [CChar](repeating: 0, count: Int(self.pointee.sdl_nlen) + 1)
            for i in 0..<Int(self.pointee.sdl_nlen) {
                name[i] = $0.advanced(by: self.pointee.headerSize + i).pointee
            }
            return String(cString: &name)
        }
    }

    public var address: [UInt8] {
        guard Int(self.pointee.sdl_len) >=
            self.pointee.headerSize +
            Int(self.pointee.sdl_alen + self.pointee.sdl_nlen + self.pointee.sdl_slen)
            else {return []}
        return self.withMemoryRebound(to: UInt8.self, capacity: self.length) {
            Array(UnsafeBufferPointer(start: $0.advanced(by: self.pointee.headerSize + Int(self.pointee.sdl_nlen)),
                                      count: Int(self.pointee.sdl_alen)))
        }
    }
}

extension UnsafeMutablePointer where Pointee == sockaddr_dl {
    public var name: String {return UnsafePointer(self).name}
    public var address: [UInt8] {return UnsafePointer(self).address}
}

// MARK: sockaddr extensions
extension UnsafePointer where Pointee == sockaddr {
    private func value<A: InternetAddress>() -> A? {
        return self.withMemoryRebound(to: A.self, capacity: 1) {
            guard $0.pointee.isWellFormed else {return nil}
            return $0.pointee
        }
    }

    public var internetAddress: InternetAddress? {
        if let sin: sockaddr_in = self.value() {
            return sin
        }
        if let sin6: sockaddr_in6 = self.value() {
            return sin6
        }
        return nil
    }
}

extension UnsafeMutablePointer where Pointee == sockaddr {
    public var internetAddress: InternetAddress? {
        return UnsafePointer(self).internetAddress
    }
}


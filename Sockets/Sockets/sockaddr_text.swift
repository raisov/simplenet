//  sockaddr_text.swift
//  Simplenet SocketAddress module
//  Copyright (c) 2018 Vladimir Raisov. All rights reserved.
//  Licensed under MIT License

import Darwin.POSIX

extension in_addr : CustomStringConvertible {
    /// A textual representation of IP4 address.
    public var description: String {
        var ina = self
        var buf = [CChar](repeating: 0, count: Int(INET_ADDRSTRLEN))
        return String(cString: inet_ntop(AF_INET, &ina, &buf[0], socklen_t(INET_ADDRSTRLEN)))
    }
}

extension sockaddr_in : CustomStringConvertible {
    /// A textual representation of `sockaddr_in`.
    public var description: String {
        return "\(self.sin_addr)" + (self.sin_port == 0 ? "" : ":\(self.port)")
    }
}

extension in6_addr : CustomStringConvertible {
    /// A textual representation of IP6 address.
    public var description: String {
        var in6a = self
        var buf = [CChar](repeating: 0, count: Int(INET6_ADDRSTRLEN))
        return String(cString: inet_ntop(AF_INET6, &in6a, &buf[0], socklen_t(INET6_ADDRSTRLEN)))
    }
}

extension sockaddr_in6 : CustomStringConvertible {
    /// A textual representation of `sockaddr_in6`.
    public var description: String {
        return "[\(self.sin6_addr)" + (self.sin6_port == 0 ? "]" : "]:\(self.port)")
    }
}

extension in_addr {
    /// Creates `in_addr` struct initialized by given textual representation of IP address.
    /// ```
    /// let ina = in_addr("192.168.0.1"`)
    /// ```
    /// For an empty string input, result will contains wildcard address `INADDR_ANY`.
    /// If input doesn't contains correctly formatted IP address, initialization will failed (result will be `nil`).
    /// - Parameter presentation: String contains IPv4 address as a text.
    public init?(_ presentation: String) {
        self.init()
        if !presentation.isEmpty {
            guard inet_pton(AF_INET, presentation, &self) == 1 else {
                return nil
            }
        }
    }
}

extension in6_addr {
    /// Creates `in6_addr` struct initialized by given textual representation of IP address.
    /// ```
    /// let in6a = in6_addr("2001:0db8:85a3:0000:0000:8a2e:0370:7334"`)
    /// ```
    /// For an empty string input, result will contains wildcard address `in6addr_any`.
    /// If input doesn't contains correctly formatted IPv6 address, initialization will failed (result will be `nil`).
    /// - Parameter presentation: String contains IPv6 address as a text.
    public init?(_ presentation: String) {
        self.init()
        if !presentation.isEmpty {
            guard inet_pton(AF_INET6, presentation, &self) == 1 else {
                return nil
            }
        }
    }
}

/// The error thrown from getInternetAddresses function
public enum InternetAddressesError: Error, CustomStringConvertible {
    /// Temporary failure in name resolution.
    case again
    /// Non-recoverable failure in name resolution.
    case fail
    /// Memory allocation failure.
    case memory
    /// No address associated with hostname.
    case noname
    /// Hostname not known.
    case nodata
    /// Possibly a programming error.
    /// Associated value is an error code returned from `getaddrinfo`.
    /// See `man 3 gai_strerror` for description.
    case unexpected(Int32)

    /// Create InternetAddressesError from error code.
    /// - parameter code: nonzero return value from getaddrinfo.
    fileprivate init(_ code: Int32) {
        switch code {
        case EAI_AGAIN: self = .again
        case EAI_FAIL: self = .fail
        case EAI_MEMORY: self = .memory
        case EAI_NONAME: self = .noname
        case EAI_NODATA: self = .nodata
        default: self = .unexpected(code)
        }
    }

    /// Raw `getaddrinfo` rror code;
    /// see `man 3 gai_strerror` for description.
    public var code: Int32 {
        switch self {
        case .again: return EAI_AGAIN
        case .fail: return EAI_FAIL
        case .memory: return EAI_MEMORY
        case .noname: return EAI_NONAME
        case .nodata: return EAI_NODATA
        case .unexpected(let _code): return _code
        }
    }

    /// A textual description of the error.
    public var description: String {
        return String(validatingUTF8: gai_strerror(self.code)) ?? "unexpected getaddrinfo return \(code)"
    }
}

/// Enumerates addresses for the given host and port.
/// - Parameters:
///     - host: the hostname or IP addrress for host.
///     - port: the port number.
///     - numericHost: if `true`, no DNS lookup executed for `host`, only IP addresses accepted.
/// - Returns: the `InternetAddress` array for the host:port pair.
/// - Throws: `InternetAddressesError` or `SocketError`
public func getInternetAddresses(for host: String? = nil, port: UInt16 = 0, numericHost: Bool = false) throws -> [InternetAddress] {
    var addresses = [InternetAddress]()
    var hints = addrinfo()
    hints.ai_flags = AI_DEFAULT | AI_NUMERICSERV | (numericHost ? AI_NUMERICHOST : 0)
    hints.ai_family = 0
    hints.ai_socktype = SOCK_DGRAM
    hints.ai_protocol = IPPROTO_UDP
    var addrinfoListHead: UnsafeMutablePointer<addrinfo>?
    let res = withUnsafeMutablePointer(to: &addrinfoListHead) {(ai_p) -> Int32 in
        String(port).withCString {port_p in
            if let host = host {
                return host.withCString {host_p in
                    getaddrinfo(host_p, port_p, &hints, ai_p)
                }
            } else {
                hints.ai_flags |= AI_PASSIVE
                return getaddrinfo(nil, port_p, &hints, ai_p)
            }
        }
    }
    var ai_p = addrinfoListHead
    defer {
        freeaddrinfo(addrinfoListHead)
    }
    guard res == 0 else {
        if res == EAI_SYSTEM {
            throw SocketError()
        } else {
            throw InternetAddressesError(res)
        }
    }
    while let p = ai_p {
        if let address = p.pointee.ai_addr.internetAddress {
            addresses.append(address)
        }
        ai_p = p.pointee.ai_next
    }
    return addresses
}


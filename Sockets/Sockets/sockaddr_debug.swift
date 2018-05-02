//  sockaddr_debug.swift
//  Simplenet SocketAddress module
//  Copyright (c) 2018 Vladimir Raisov. All rights reserved.
//  Licensed under MIT License

import Darwin.POSIX

extension sockaddr_in : CustomDebugStringConvertible {
    /// A textual representation of `sockaddr_in`, suitable for debugging.
    public var debugDescription: String {
        return (
            """
            sockaddr_in {len: \(self.sin_len)\
            \(self.sin_len == MemoryLayout<sockaddr_in>.size ? "" : " (incorrect!)"), \
            family: \(self.sin_family) \
            (\(self.sin_family == AF_INET ? "AF_INET" : " (incorrect!)")), \
            addr: \(self.sin_addr), \
            port: \(self.sin_port.byteSwapped)\
            }
            """
        )
    }
}

extension sockaddr_in6 : CustomDebugStringConvertible {
    /// A textual representation of `sockaddr_in6`, suitable for debugging.
    public var debugDescription: String {
        return (
            """
            sockaddr_in6 {len: \(self.sin6_len)\
            \(self.sin6_len == MemoryLayout<sockaddr_in6>.size ? "" : " (incorrect!)"), \
            family: \(self.sin6_family) \
            (\(self.sin6_family == AF_INET6 ? "AF_INET6" : "incorrect!")), \
            addr: \(self.sin6_addr), \
            port: \(self.sin6_port.byteSwapped), \
            scope_id: \(self.sin6_scope_id), \
            flowinfo: \(self.sin6_flowinfo)\
            }
            """
        )
    }
}

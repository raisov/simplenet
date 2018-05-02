//  bsd.swift
//  Simplenet Socket module
//  Copyright (c) 2018 Vladimir Raisov. All rights reserved.
//  Licensed under MIT License

import Darwin.POSIX

/// The error thrown from bsd function
public enum SocketError: Error, CustomStringConvertible {
    /// Interrupted system call.
    case interrupt

    /// Bad socket descriptor.
    case badDescriptor

    /// Trying to bind to the privileged port in user mode,
    /// or using broadcast destination address when SO_BROADCAST not specified.
    case noAccess

    /// The socket is no longer connected.
    case brokenConnection

    /// No data to read
    case again

    /// Too many active socket descriptors.
    case tooManyDescriptors

    /// Message too long.
    case tooLong

    /// Address already in use.
    case addressInUse

    /// Can't assign requested address.
    case addressNotAvailable

    /// Network interface is down.
    case interfaceIsDown

    /// Network is unreachable.
    case networkUnreachable

    /// Connection reset by peer.
    case connectionReset

    /// Unable to allocate an internal buffer.
    case noBuffer

    /// Operation timed out.
    case timeout

    /// No route to host.
    case noRoute

    /// Possibly a programming error.
    /// Associated value is a POSIX error code.
    case unexpected(Int32)

    /// Create SocketError from `errno`
    /// - parameter code: POSIX error code
    init(_ code: Int32 = errno) {
        switch code {
        case EINTR: self = .interrupt
        case EBADF: self = .badDescriptor
        case EACCES: self = .noAccess
        case EPIPE: self = .brokenConnection
        case EAGAIN: self = .again
        case EMFILE: self = .tooManyDescriptors
        case EMSGSIZE: self = .tooLong
        case EADDRINUSE: self = .addressInUse
        case EADDRNOTAVAIL: self = .addressNotAvailable
        case ENETDOWN: self = .interfaceIsDown
        case ENETUNREACH: self = .networkUnreachable
        case ECONNRESET: self = .connectionReset
        case ENOBUFS: self = .noBuffer
        case ETIMEDOUT: self = .timeout
        case EHOSTUNREACH: self = .noRoute
        default: self = .unexpected(code)
        }
    }

    /// POSIX error code
    public var code: Int32 {
        switch self {
        case .interrupt: return EINTR
        case .badDescriptor: return EBADF
        case .noAccess: return EACCES
        case .brokenConnection: return EPIPE
        case .again: return EAGAIN
        case .tooManyDescriptors: return EMFILE
        case .tooLong: return EMSGSIZE
        case .addressInUse: return EADDRINUSE
        case .addressNotAvailable: return EADDRNOTAVAIL
        case .interfaceIsDown: return ENETDOWN
        case .networkUnreachable: return ENETUNREACH
        case .connectionReset: return ECONNRESET
        case .noBuffer: return ENOBUFS
        case .timeout: return ETIMEDOUT
        case .noRoute: return EHOSTUNREACH
        case .unexpected(let _code): return _code
        }
    }

    /// A textual description of the error
    public var description: String {
        return String(validatingUTF8: strerror(self.code)) ?? "unexpected POSIX error code \(code)"
    }
}

/// Performs POSIX function call with checking result and throwing an SocketError if necessary
/// - Parameters:
///   - call: The function to call.
/// - Throws: SocketError
@discardableResult
public func bsd<ReturnType: SignedInteger> (_ call: @autoclosure () -> ReturnType) throws -> ReturnType {
    let result = call()
    guard result != -1 else {
        throw SocketError()
    }
    return result
}


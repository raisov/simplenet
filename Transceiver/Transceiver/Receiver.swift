//  Receiver.swift
//  Simplenet Datagram module
//  Copyright (c) 2018 Vladimir Raisov. All rights reserved.
//  Licensed under MIT License

import Dispatch
import Sockets
import Interfaces

public class Receiver {

    private let sources: [DispatchSourceRead]

    /// Handler for incoming datagrams and related errors.
    public var delegate: DatagramHandler? {
        willSet {
            guard self.delegate != nil else {return}
            self.sources.forEach { source in
                source.suspend()
            }
        }
        didSet {
            guard let handler = self.delegate else {return}
            self.sources.forEach {source in
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
    }

    /// Creates receiver for unicast and broadcast datagrams.
    /// - Parameters:
    ///     - port: port on wich the receiver will listen.
    ///     - interface: interface used for receiving.
    ///
    /// If `interface` specified, only unicast datagrams addressed to this interface address (IPv4 or IPv6)
    /// will be received; otherwise all datagrams addressed to selected port will be received on all
    /// available interfaces.
    public convenience init(port: UInt16,  interface: Interface? = nil) throws {
        var addresses = [InternetAddress]()
        if let interface = interface {
            addresses.append(contentsOf: interface.addresses.map{$0.with(port: port)})
        } else {
            addresses.append(contentsOf: Interfaces().flatMap{$0.ip4}.map{$0.with(port: port)})
            addresses.append(contentsOf: try getInternetAddresses(port: port))
        }
        try self.init(port: port, addresses)
    }

    /// Creates receiver for multicast datagrams.
    /// - Parameters:
    ///     - port: port on wich the receiver will listen.
    ///     - address: IPv4 or IPv6 multicast group address to join
    ///     - interface: interface used for receiving;
    ///       when omitted, operating system select default interface.
    public convenience init(port: UInt16, multicast address: String, interface: Interface? = nil) throws {
        let addresses = try getInternetAddresses(for: address, port: port, numericHost: true)
        assert(addresses.count == 1)
        assert(addresses.first!.isMulticast)
        try self.init(port: port, addresses)
        assert(self.sources.count == 1)
        if let source = self.sources.first,
            let group = addresses.first?.ip
        {
            var interfaces = [Interface]()
            if let interface = interface {
                interfaces.append(interface)
            } else {
                interfaces.append(contentsOf: Interfaces())
            }

            let socket = try Socket(Int32(source.handle))
            let family = type(of: group).family
            try interfaces.filter{
                guard $0.options.contains(.multicast) else {return false}
                guard !$0.options.contains(.pointopoint) else {return false}
                return !$0.addresses.filter{type(of: $0).family == family}.isEmpty
            }.forEach {interface in
                try socket.joinToMulticast(group, interfaceIndex: interface.index)
            }
        }
    }

    /// You don't need to know about it, although it does all the work...
    private init(port: UInt16, _ addresses: [InternetAddress]) throws {
        self.sources = try addresses.map {address in
            let family = type(of: address.ip).family
            let socket = try Socket(family: SocketAddressFamily(family), type: .datagram)
            switch family {
            case .ip4:
                try socket.enable(option: IP_RECVDSTADDR, level: IPPROTO_IP) // 16
                try socket.enable(option: IP_RECVPKTINFO, level: IPPROTO_IP) // 24
            case .ip6:
                try socket.enable(option: IPV6_2292PKTINFO, level: IPPROTO_IPV6)
                try socket.enable(option: IPV6_V6ONLY, level: IPPROTO_IPV6)
            }
            try socket.enable(option: SO_REUSEADDR, level: SOL_SOCKET)
            try socket.enable(option: SO_REUSEPORT, level: SOL_SOCKET)
            socket.nonBlockingOperations = true
            try socket.bind(address)
            let handle = try socket.duplicateDescriptor()
            let source = DispatchSource.makeReadSource(fileDescriptor: handle)
            source.setCancelHandler{[source] in
                Darwin.close(Int32(source.handle))
            }
            return source
        }
    }

    deinit {
        if self.delegate != nil {
            self.sources.forEach {source in
                source.cancel()
            }
        }
    }
}


//  SocketsTests.swift
//  Simplenet Socket module
//  Copyright (c) 2018 Vladimir Raisov. All rights reserved.
//  Licensed under MIT License

import XCTest
@testable import Sockets
@testable import Interfaces

class SocketTests: XCTestCase {

    override func setUp() {
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }

    func testBind() {
        Interfaces().flatMap{$0.addresses}.forEach {
            do {
                let sock = try Socket(family: SocketAddressFamily(type(of: $0).family), type: .datagram, protocol: .udp)
                let address = $0.with(port: 0x1122)
                try sock.bind(address)
                XCTAssertNotNil(sock.localAddress)
                if let ip = sock.localAddress?.ip {
                    if let ip4 = ip as? in_addr {
                        XCTAssertEqual(ip4, $0 as! in_addr)
                    }
                    if var ip6 = ip as? in6_addr {
                        let iip6 = ip as! in6_addr
                        ip6.__u6_addr.__u6_addr16.1 = iip6.__u6_addr.__u6_addr16.1
                        XCTAssertEqual(ip6, ip as! in6_addr)
                    }
                }
            } catch {
                XCTFail("\(error)")
            }
        }
    }

    func testBroadcastConnect() {
        Interfaces().filter{$0.broadcast != nil}.forEach {
            let brd = sockaddr_in($0.broadcast!, port: 0x1122)
            do {
                let sock = try Socket(family: .inet, type: .datagram, protocol: .udp)
                try sock.enable(option: SO_BROADCAST, level: SOL_SOCKET)
                XCTAssertTrue(try sock.enabled(option: SO_BROADCAST, level: SOL_SOCKET))
                try sock.set(option: IP_BOUND_IF, level: IPPROTO_IP, value: $0.index)
                XCTAssertEqual(try sock.get(option: IP_BOUND_IF, level: IPPROTO_IP), $0.index)
                try sock.connectTo(brd)
                XCTAssertNotNil(sock.remoteAddress)
                if let ina = sock.remoteAddress as? sockaddr_in {
                    XCTAssertEqual(ina.sin_addr, brd.sin_addr)
                    XCTAssertEqual(ina.sin_port, brd.sin_port)
                }
                XCTAssertNotNil(sock.localAddress)
                if let ina = sock.localAddress as? sockaddr_in {
                    XCTAssertNotNil($0.ip4.first{$0 == ina.sin_addr})
                }
            } catch {
                XCTFail("\(error)")
            }
        }
    }

    func testConnect4() {
        Interfaces().flatMap{$0.ip4}.forEach {
            do {
                let sock = try Socket(family: .inet, type: .datagram, protocol: .udp)
                let sin = sockaddr_in($0, port:0x1122)
                try sock.connectTo(sin)
                XCTAssertNotNil(sock.remoteAddress)
                if let ina = sock.remoteAddress as? sockaddr_in {
                    XCTAssertEqual(ina.sin_addr, sin.sin_addr)
                    XCTAssertEqual(ina.sin_port, sin.sin_port)
                }
                XCTAssertNotNil(sock.localAddress)
                if let ina = sock.localAddress as? sockaddr_in {
                    XCTAssertEqual(ina.sin_addr, sin.sin_addr)
                }
            } catch {
                XCTFail("\(error)")
            }
        }
    }

    func testConnect6() {
        Interfaces().flatMap{$0.ip6}.forEach {
            do {
                let sock = try Socket(family: .inet6, type: .datagram, protocol: .udp)
                let sin6 = sockaddr_in6($0, port:0x1122)
                try sock.connectTo(sin6)
                XCTAssertNotNil(sock.remoteAddress)
                if var ina = sock.remoteAddress as? sockaddr_in6 {
                    ina.sin6_addr.__u6_addr.__u6_addr16.1 = sin6.sin6_addr.__u6_addr.__u6_addr16.1
                    XCTAssertEqual(ina.sin6_addr, sin6.sin6_addr)
                    XCTAssertEqual(ina.sin6_port, sin6.sin6_port)
                }
                XCTAssertNotNil(sock.localAddress)
                if var ina = sock.localAddress as? sockaddr_in6 {
                    ina.sin6_addr.__u6_addr.__u6_addr16.1 = sin6.sin6_addr.__u6_addr.__u6_addr16.1
                    XCTAssertEqual(ina.sin6_addr, sin6.sin6_addr)
                }
            } catch {
                XCTFail("\(error)")
            }
        }
    }

    func testBooleanOptions() {
        do {
            let sock = try Socket(family: .inet, type: .datagram, protocol: .udp)
            let tested = [
                (SO_BROADCAST, SOL_SOCKET),
                (SO_REUSEADDR, SOL_SOCKET),
                (SO_REUSEPORT, SOL_SOCKET),
                (IP_RECVPKTINFO, IPPROTO_IP),
                (IP_RECVDSTADDR, IPPROTO_IP),
                (IP_RECVIF, IPPROTO_IP),
                (IP_RECVTTL, IPPROTO_IP)]
            for option in tested {
                let currentStatus = try sock.enabled(option: option.0, level: option.1)
                if currentStatus {
                    try sock.disable(option: option.0, level: option.1)
                    XCTAssertFalse(try sock.enabled(option: option.0, level: option.1))
                    try sock.enable(option: option.0, level: option.1)
                    XCTAssertTrue(try sock.enabled(option: option.0, level: option.1))
                } else {
                    try sock.enable(option: option.0, level: option.1)
                    XCTAssertTrue(try sock.enabled(option: option.0, level: option.1))
                    try sock.disable(option: option.0, level: option.1)
                    XCTAssertFalse(try sock.enabled(option: option.0, level: option.1))
                }
            }
        } catch {
            XCTFail("\(error)")
        }
    }

    func testBooleanOptions6() {
        do {
            let sock = try Socket(family: .inet6, type: .datagram, protocol: .udp)
            let tested = [
                (IPV6_V6ONLY, IPPROTO_IPV6),
                (IPV6_BINDV6ONLY, IPPROTO_IPV6),
                (IPV6_2292PKTINFO, IPPROTO_IPV6)]
            for option in tested {
                let currentStatus = try sock.enabled(option: option.0, level: option.1)
                if currentStatus {
                    try sock.disable(option: option.0, level: option.1)
                    XCTAssertFalse(try sock.enabled(option: option.0, level: option.1))
                    try sock.enable(option: option.0, level: option.1)
                    XCTAssertTrue(try sock.enabled(option: option.0, level: option.1))
                } else {
                    try sock.enable(option: option.0, level: option.1)
                    XCTAssertTrue(try sock.enabled(option: option.0, level: option.1))
                    try sock.disable(option: option.0, level: option.1)
                    XCTAssertFalse(try sock.enabled(option: option.0, level: option.1))
                }
            }
        } catch {
            XCTFail("\(error)")
        }
    }
}


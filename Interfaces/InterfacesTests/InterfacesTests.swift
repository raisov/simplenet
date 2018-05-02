//  InterfacesTests.swift
//  Simplenet Interfaces module
//  Copyright (c) 2018 Vladimir Raisov. All rights reserved.
//  Licensed under MIT License

import XCTest
@testable import Interfaces

class InterfacesTests: XCTestCase {

    override func setUp() {
        super.setUp()
    }

    override func tearDown() {
        super.tearDown()
    }

    func testNameToIndex() {
        Interfaces().forEach {
            XCTAssertEqual(if_nametoindex($0.name), UInt32($0.index))
        }
    }

    func testIndexToName() {
        var buf = [CChar](repeating: 0, count: Int(IF_NAMESIZE))
        Interfaces().forEach {
            XCTAssertEqual(String(cString: if_indextoname(UInt32($0.index), &buf)), $0.name)
        }
    }

    func testEthernetMACAddress() {
        Interfaces().filter{$0.isEthernetCompatible}.forEach {
            XCTAssertNotNil($0.link)
            if let count = $0.link?.count {
                XCTAssertEqual(count, 6)
            }
        }
    }

    func testLoopbackPresent() {
        let ifs = Interfaces()
        XCTAssertEqual(ifs.filter{$0.options.contains(.loopback)}.count, 1)
        if let loopback = (ifs.first{$0.options.contains(.loopback)}) {
            XCTAssertEqual(loopback.type, .loopback)
            XCTAssertFalse(loopback.ip4.isEmpty && loopback.ip6.isEmpty)
            XCTAssertNil(loopback.broadcast)
        }
    }

    func testInetComplete() {
        Interfaces().filter{$0.addresses.first{type(of: $0).family == .ip4} != nil}.forEach {
            XCTAssertNotNil($0.mask4)
            if $0.options.contains(.broadcast) {
                XCTAssertNotNil($0.broadcast)
            }
            if $0.options.contains(.pointopoint) {
                XCTAssertNotNil($0.destination)
            }
        }
    }

    func testInet6Complete() {
        Interfaces().forEach {interface in
            XCTAssertEqual(
                interface.addresses.filter{type(of: $0).family == .ip6}.count,
                interface.masks6.filter{type(of: $0).family == .ip6}.count
            )
        }
    }

    func testPerformanceEnumeration() {
        self.measure {
            for ifi in Interfaces() {
                _ = ifi.index
                _ = ifi.name
                _ = ifi.link
                _ = ifi.isEthernetCompatible
                _ = ifi.type
                _ = ifi.options
                _ = ifi.mtu
                _ = ifi.metric
                _ = ifi.baudrate
                _ = ifi.addresses
                _ = ifi.ip4
                _ = ifi.ip6
                _ = ifi.mask4
                _ = ifi.masks6
                _ = ifi.broadcast
                _ = ifi.destination
            }
        }
    }

}


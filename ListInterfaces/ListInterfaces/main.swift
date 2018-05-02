//
//  main.swift
//  ListInterfaces
//
//  Created by bp on 2018-04-26.
//  Copyright © 2018 Vladimir Raisov. All rights reserved.
//
//  Demo of Interfaces API

import Sockets
import Interfaces

let osnames = OSNames()
Interfaces().forEach {i in
    print("Interface index: \(i.index)", terminator: "")
    let name = i.name
    print(", name: \(name)", terminator: "")
    (osnames.first{$0.name == name}?.configName).map{print(" (\($0))", terminator: "")}

    print("\n\ttype: \(i.type)", terminator: "")

    if i.type != .ethernet && i.isEthernetCompatible {
        print(" (ethernet compatible)")
    } else {
        print("")
    }

    if let link = i.link {
        print("\tlink level address: ", terminator: "")
        print(link.map{String(format: "%02x", $0)}.joined(separator: ":"))
    }

    let options = i.options
    var opts = [String]()
    if options.contains(.up) {opts.append("up")}
    if options.contains(.broadcast) {opts.append("broadcast")}
    if options.contains(.loopback) {opts.append("loopback")}
    if options.contains(.pointopoint) {opts.append("pointopoint")}
    if options.contains(.smart) {opts.append("smart")}
    if options.contains(.running) {opts.append("running")}
    if options.contains(.noarp) {opts.append("noarp")}
    if options.contains(.promisc) {opts.append("promisc")}
    if options.contains(.allmulti) {opts.append("allmulti")}
    if options.contains(.simplex) {opts.append("simplex")}
    if options.contains(.altphys) {opts.append("altphys")}
    if options.contains(.multicast) {opts.append("multicast")}
    let optstr = opts.joined(separator: ", ")
    print("\toptions: [\(optstr)]")

    print("\tmtu: \(i.mtu)")
    print("\tmetric: \(i.metric)")
    print("\tbaudrate: \(i.baudrate)")
    
    if i.ip4.count != 0 {
        print("\tip4: ", terminator: "")
        print(i.ip4.map{String(describing: $0)}.joined(separator: ", "))
    }
    i.mask4.map{print("\tmask: \($0)")}
    i.broadcast.map{print("\tbroadcast: \($0)")}
    i.destination.map{print("\tdestination: \($0)")}

    if i.ip6.count != 0 {
        print("\tip6: ", terminator: "")
        print(zip(i.ip6, i.prefixes6).map{"\($0.0)/\($0.1)"}.joined(separator: "\n\t     "))
    }
}


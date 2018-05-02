//  main.swift
//  EchoClient sample programm
//  Simplenet
//  Copyright (c) 2018 Vladimir Raisov. All rights reserved.
//  Licensed under MIT License

import Dispatch
import Sockets
import Interfaces
import Transceiver

let stopsem = DispatchSemaphore(value: 0)
func stop(_: Int32) {
    print("\r", terminator: "")
    stopsem.signal()
}

struct ReplyAcceptor: DatagramHandler {

    func dataDidRead(_ datagram: Datagram) {
        let data = datagram.data
        print("    Reply received", terminator: "")
        datagram.sender.map{print(" from \($0)", terminator: "")}
        print(" with \(data.count) bytes of data:")
        String(data: datagram.data, encoding: .utf8).map{print("    \($0)")}
    }

    func errorDidOccur(_ error: Error) {
        print(error)
        stopsem.signal()
    }
}

let args = CommandLine.arguments
let arg1 = args.dropFirst().first
let arg2 = args.dropFirst().dropFirst().first
let arg3 = args.dropFirst().dropFirst().dropFirst().first
let rest = args.dropFirst().dropFirst().dropFirst().dropFirst().first

func interface(_ name: String) -> Interface? {
    guard let interface = (Interfaces().first{$0.name == name}) else {
        print("Invalid value \"\(name)\" for <interface-name> parameter")
        print("Use `ifconfig` to view interfaces names")
        exit(2)
    }
    return interface
}

do {
    var transmitter: Transmitter
    switch (arg1, arg1.flatMap(UInt16.init), arg2.flatMap(UInt16.init), arg2, arg3, rest) {
    case (.some(let host), .none, .some(let port), _, let iname, .none):
        transmitter = try Transmitter(host: host, port: port, interface: iname.flatMap(interface))
    case (_, .some(let port), .none, let iname, .none, _):
        transmitter = try Transmitter(port: port, interface: iname.flatMap(interface))
    default:
        let cmd = String(args.first!.reversed().prefix{$0 != "/"}.reversed())
        print("usage: \(cmd) [<host-name>] <port> [<interface-name>]")
        exit(1)
    }
    transmitter.delegate = ReplyAcceptor()
    print("Transmitter has been created.")
        print("Enter data to send: ", terminator: "")
        guard let data = readLine()?.data(using: .utf8) else {exit(0)}
        try transmitter.send(data: data)
    print("    \(data.count) bytes sent.")
    guard !data.isEmpty else {exit(0)}
    print("Waiting for reply. Press Ctrl-C to cancel.")
    signal(SIGINT, stop)  // Ctrl-C
    signal(SIGQUIT, stop)  // Ctrl-\
    signal(SIGTSTP, stop)  // Ctrl-Z
    _ = stopsem.wait(timeout: DispatchTime.now() + .seconds(2))
    print("Waiting is over.")
}
catch {
    print(error)
    print("Transmitter can't be created.")
}

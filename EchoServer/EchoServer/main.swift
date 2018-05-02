//  main.swift
//  EchoServer sample programm
//  Simplenet
//  Copyright (c) 2018 Vladimir Raisov. All rights reserved.
//  Licensed under MIT License

import Dispatch
import Sockets
import Interfaces
import Transceiver

let stopsem = DispatchSemaphore(value: 0)
func stop(_: Int32) {
    print("\rReceiver terminated.")
    stopsem.signal()
}

struct Echo: DatagramHandler {

    func dataDidRead(_ datagram: Datagram) {
        let data = datagram.data
        print("\(data.count) bytes received", terminator: "")
        datagram.sender.map{print(" from \($0)", terminator: "")}
        (datagram.interface?.name).map{print(" over interface \($0)", terminator: "")}
        print(":")
        String(data: datagram.data, encoding: String.Encoding.utf8).map{print($0)}
        do {
            try datagram.reply(with: datagram.data)
        } catch {
            self.errorDidOccur(error)
        }
    }

    func errorDidOccur(_ error: Error) {
        print(error)
    }
}

let args = CommandLine.arguments
let arg1 = args.dropFirst().first
let arg2 = args.dropFirst().dropFirst().first
let arg3 = args.dropFirst().dropFirst().dropFirst().first
let rest = args.dropFirst().dropFirst().dropFirst().dropFirst().first

func findInterface(_ name: String) -> Interface {
    guard let interface = (Interfaces().first{$0.name == name}) else {
        print("Invalid value \"\(name)\" for <interface-name> parameter")
        print("Use `ifconfig` to view interface names")
        exit(2)
    }
    return interface
}

do {
    var receiver: Receiver
    switch (arg1, arg1.flatMap(UInt16.init), arg2.flatMap(UInt16.init), arg2, arg3, rest) {
    case (.some(let group), .none, .some(let port), _, let iname, .none):
        let interface = iname.flatMap(findInterface)
        receiver = try Receiver(port: port, multicast: group, interface: interface)
    case (_, .some(let port), .none, let iname, .none, _):
        let interface = iname.flatMap(findInterface)
        receiver = try Receiver(port: port, interface: interface)
    default:
        let cmd = String(args.first!.reversed().prefix{$0 != "/"}.reversed())
        print("usage: \(cmd) [<multicast-address>] <port> [<interfaces-bsdname>]")
        exit(1)
    }
    print("Receiver has been created.")
    receiver.delegate = Echo()
    print("Press Ctrl-C to exit")

    signal(SIGINT, stop)  // Ctrl-C
    signal(SIGQUIT, stop)  // Ctrl-\
    signal(SIGTSTP, stop)  // Ctrl-Z
    stopsem.wait()
} catch {
    print(error)
    print("Receiver can't be created.")
    exit(1)
}


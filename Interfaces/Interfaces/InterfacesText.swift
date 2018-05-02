//  InterfacesText.swift
//  Simplenet Interfaces module
//  Copyright (c) 2018 Vladimir Raisov. All rights reserved.
//  Licensed under MIT License

import Darwin.POSIX
import Sockets

extension Interface {
    /// A textual representation of interface, allowing its identification in the system.
    public var description: String {
        var res = "\(self.name) \(self.index)"
        if let link = self.link {
            res += " " + link.map{String(format: "%02x", $0)}.joined(separator: ":")
        }
        return res
    }
}


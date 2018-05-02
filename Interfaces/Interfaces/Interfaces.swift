//  Interfaces.swift
//  Simplenet Interfaces module
//  Copyright (c) 2018 Vladimir Raisov. All rights reserved.
//  Licensed under MIT License

import Darwin.POSIX
import struct Foundation.Data
import Sockets

/// A type describing network interface
public struct Interface: Hashable, CustomStringConvertible  {

    /// To conform `Hashable` protocol.
    /// Sometimes `Set<Interface>` may be useful.
    public var hashValue: Int {return Int(self.index)}

    public static func ==(lhs: Interface, rhs: Interface) -> Bool {
        return lhs.index == lhs.index
    }

    /// Contains routing messages with information about network interface
    fileprivate let interfaceMessages: Data

    /// Creates `Interface` as an element of `Interfaces` collection.
    /// - parameter interfaceMessages: part of the `sysctl` buffer with
    ///   information about the interface being created.
    fileprivate init(_ interfaceMessages: Data) {
        interfaceMessages.withUnsafeBytes {(ifm_p: UnsafePointer<if_msghdr>) in
            assert(ifm_p.pointee.ifm_version == RTM_VERSION)
            assert(ifm_p.pointee.ifm_type == RTM_IFINFO)
            assert(ifm_p.pointee.ifm_addrs & RTA_IFP != 0)
            assert(ifm_p.pointee.ifm_index != 0)
            ifm_p.advanced(by: 1).withMemoryRebound(to: sockaddr_dl.self, capacity: 1) {
                assert($0.pointee.isWellFormed)
                assert($0.index == ifm_p.pointee.ifm_index)
            }
        }
        self.interfaceMessages = interfaceMessages
    }

    ///
    public var index: Int32 {
        return interfaceMessages.withUnsafeBytes {(ifm_p: UnsafePointer<if_msghdr>) -> Int32 in
            return numericCast(ifm_p.pointee.ifm_index)
        }
    }

    /// BSD name of interface
    public var name: String {
        return interfaceMessages.withUnsafeBytes {(ifm_p: UnsafePointer<if_msghdr>) -> String in
            ifm_p.advanced(by: 1).withMemoryRebound(to: sockaddr_dl.self, capacity: 1) {
                $0.name
            }
        }
    }

    /// Hardware (link level) address of interface;
    /// for ethernet - so-called MAC address.
    public var link: [UInt8]? {
        return interfaceMessages.withUnsafeBytes {(ifm_p: UnsafePointer<if_msghdr>) -> [UInt8]? in
            ifm_p.advanced(by: 1).withMemoryRebound(to: sockaddr_dl.self, capacity: 1) {
                guard $0.address.count != 0 else {return nil}
                return $0.address
            }
        }
    }

    /// True, if it is possible to work with interface as with ethernet;
    /// for example, Wi-Fi interface is ethernet compatible.
    public var isEthernetCompatible: Bool {
        return interfaceMessages.withUnsafeBytes {(ifm_p: UnsafePointer<if_msghdr>) -> Bool in
            ifm_p.advanced(by: 1).withMemoryRebound(to: sockaddr_dl.self, capacity: 1) {
                $0.type == IFT_ETHER
            }
        }
    }

    /// Enumerates basic interface types.
    public enum InterfaceType: Equatable {
        /// Loopback interface.
        case loopback
        /// Ethernet interface.
        case ethernet
        /// generic tunnel interface; see man 4 gif.
        case gif
        /// 6to4 tunnel interface; see man 4 stf.
        case stf
        /// Layer 2 Virtual LAN using 802.1Q.
        case vlan
        /// IEEE802.3ad Link Aggregate.
        case linkAggregate
        /// IEEE1394 High Performance SerialBus.
        case fireware
        /// Transparent bridge interface.
        case bridge
        /// Other, value is a raw interface type code;
        /// for possible values see net/if_types.h
        case other(Int32)

        fileprivate init(_ code: Int32) {
            switch code {
            case IFT_LOOP: self = .loopback
            case IFT_ETHER: self = .ethernet
            case IFT_GIF: self = .gif
            case IFT_STF: self = .stf
            case IFT_L2VLAN: self = .vlan
            case IFT_IEEE8023ADLAG: self = .linkAggregate
            case IFT_IEEE1394: self = .fireware
            case IFT_BRIDGE: self = .bridge
            default: self = .other(code)
            }
        }

        /// Raw interface type code, espcially useful in `.other` case.
        public var code: Int32 {
            switch self {
            case .loopback: return IFT_LOOP
            case .ethernet: return IFT_ETHER
            case .gif: return IFT_GIF
            case .stf: return IFT_STF
            case .vlan: return IFT_L2VLAN
            case .linkAggregate: return IFT_IEEE8023ADLAG
            case .fireware: return IFT_IEEE1394
            case .bridge: return IFT_BRIDGE
            /// For other possible values, see net/if_types.h for possible values.
            case .other(let _code): return _code
            }
        }

        public static func ==(lhs: InterfaceType, rhs: InterfaceType) -> Bool {
            return lhs.code == rhs.code
        }
    }

    /// That's it, the type of interface.
    public var type: InterfaceType {
        return interfaceMessages.withUnsafeBytes {(ifm_p: UnsafePointer<if_msghdr>) -> InterfaceType in
            InterfaceType(Int32(ifm_p.pointee.ifm_data.ifi_type))
        }
    }

    /// Enumerates possible interface options.
    public struct InterfaceOptions: OptionSet {
        public let rawValue: Int32
        public init(rawValue: Int32) {self.rawValue = rawValue}
        /// Interface is up.
        public static let up = InterfaceOptions(rawValue: IFF_UP)
        /// Interface has a broadcast address.
        public static let broadcast = InterfaceOptions(rawValue: IFF_BROADCAST)
        /// Loopback interface.
        public static let loopback = InterfaceOptions(rawValue: IFF_LOOPBACK)
        /// Point-to-point link.
        public static let pointopoint = InterfaceOptions(rawValue: IFF_POINTOPOINT)
        /// I don't know what does it mean, but ifconfig call it "SMART".
        public static let smart = InterfaceOptions(rawValue: IFF_NOTRAILERS)
        /// Driver resources allocated.
        public static let running = InterfaceOptions(rawValue: IFF_RUNNING)
        /// No address resolution protocol in network.
        public static let noarp = InterfaceOptions(rawValue: IFF_NOARP)
        /// Interface receives all packets in connected networ.
        public static let promisc = InterfaceOptions(rawValue: IFF_PROMISC)
        /// Receives all multicast packets, as a `promisc` for multicast.
        public static let allmulti = InterfaceOptions(rawValue: IFF_ALLMULTI)
        /// Can't hear own transmissions.
        public static let simplex = InterfaceOptions(rawValue: IFF_SIMPLEX)
        /// Uses alternate physical connection.
        public static let altphys = InterfaceOptions(rawValue: IFF_ALTPHYS)
        /// Supports multicast.
        public static let multicast = InterfaceOptions(rawValue: IFF_MULTICAST)
    }

    /// This interface options.
    public var options: InterfaceOptions {
        return interfaceMessages.withUnsafeBytes {(ifm_p: UnsafePointer<if_msghdr>) -> InterfaceOptions in
            InterfaceOptions(rawValue: ifm_p.pointee.ifm_flags)
        }
    }

    /// Maximum Transmission Unit size for interface.
    public var mtu: Int {
        return interfaceMessages.withUnsafeBytes {(ifm_p: UnsafePointer<if_msghdr>) -> Int in
            Int(ifm_p.pointee.ifm_data.ifi_mtu)
        }
    }

    /// Network routing metric.
    public var metric: Int {
        return interfaceMessages.withUnsafeBytes {(ifm_p: UnsafePointer<if_msghdr>) -> Int in
            Int(ifm_p.pointee.ifm_data.ifi_metric)
        }
    }

    /// Possible link speed; may be 0 if undefined.
    public var baudrate: Int {
        return interfaceMessages.withUnsafeBytes {(ifm_p: UnsafePointer<if_msghdr>) -> Int in
            Int(ifm_p.pointee.ifm_data.ifi_baudrate)
        }
    }

    /// This is a curried function intended to produce a function
    /// for retrieving data of given `kind` from the memory buffer
    /// containing `RTM_NEWADDR` type routing messages.
    /// - Parameters:
    ///     - kind: specifies the kind of data to extract. Possible values:
    ///        - RTAX_IFA - IP or IPv6 address of the interface
    ///        - RTAX_NETMASK - network mask for the interface
    ///        - RTAX_BRD - broadcast address of the interface (or destination address for P2P interface)
    ///     - count: size of the memory buffer
    /// - returns: specified function suitable for using as an argument for `withUnsafeBytes`
    /// - Warning: Don't try to undestand this function. It's dangerous for your peace of mind!
    func addressExtractor(of kind: Int32, _ count: Int) ->
        (_ start: UnsafePointer<Int8>) -> [IPAddress] {

            func sa_rlen<T>(_ x: T) -> Int where T: BinaryInteger {
                return Int(x == 0 ? 4 : (x + 3) & ~3)
            }

            assert(0 <= kind && kind < RTAX_MAX)
            let bitmask = Int32(1 << kind)
            return {(_ start: UnsafePointer<Int8>) -> [IPAddress] in
                let (index, length) = start.withMemoryRebound(to: if_msghdr.self, capacity: 1) {($0.pointee.ifm_index, $0.pointee.ifm_msglen)}
                var addresses = [IPAddress]()
                var location = Int(length)
                while location != count {
                    let rtm_p = start.advanced(by: location)
                    let (version, type, length) = rtm_p.withMemoryRebound(to: rt_msghdr.self, capacity: 1) {
                        ($0.pointee.rtm_version, $0.pointee.rtm_type, $0.pointee.rtm_msglen)
                    }
                    guard version == RTM_VERSION else {
                        location += Int(length)
                        continue
                    }
                    if type == RTM_IFINFO {break}
                    guard type == RTM_NEWADDR else {
                        location += Int(length)
                        continue
                    }
                    let ip = rtm_p.withMemoryRebound(to: ifa_msghdr.self, capacity: 1) {(ifam_p) -> IPAddress? in
                        guard ifam_p.pointee.ifam_index == index else {return nil}
                        var addrs = ifam_p.pointee.ifam_addrs
                        guard addrs & bitmask == bitmask else {return nil} // there is no address here
                        var p = UnsafeRawPointer(ifam_p.advanced(by: 1))
                        for _ in 0..<kind {
                            if addrs & 1 != 0 {
                                p += sa_rlen(p.bindMemory(to: sockaddr.self, capacity: 1).pointee.sa_len)
                            }
                            addrs >>= 1
                        }
                        let sa_p = p.bindMemory(to: sockaddr.self, capacity: 1)

                        // Many, many years ago,
                        // one programmer from Berkeley
                        // decided to save a few bytes.
                        // So now I had do the following ...
                        if sa_p.pointee.sa_family == AF_INET && bitmask == RTA_NETMASK  {
                            //                       When IPv6 was invented,
                            //                       bytes have already become cheaper
                            var sin = sockaddr_in()
                            return withUnsafeMutablePointer(to: &sin) {
                                let rp = UnsafeMutableRawPointer($0)
                                // FIXME: when will be available, replace .copyBytes with .copyMemory
                                rp.copyBytes(from: p, count: Int(sa_p.pointee.sa_len))
                                rp.assumingMemoryBound(to: sockaddr_in.self).pointee.sin_len = numericCast(MemoryLayout<sockaddr_in>.size)
                                return rp.assumingMemoryBound(to: sockaddr_in.self).pointee.ip
                            }
                        } else {
                            if let address = sa_p.internetAddress {
                                if address.isWellFormed {
                                    return address.ip
                                }
                            }
                        }
                        // I dislike this `continue`, `break` and `return` from the middle of the loop, too.
                        // But what should I do with all these `withMemoryRebound`?
                        return nil
                    }
                    if let ip = ip {addresses.append(ip)}
                    location += Int(length)
                }
                return addresses
            }

    }

    /// Array of all IPv4 and IPv6 addresses of the interface.
    public var addresses: [IPAddress] {
        return interfaceMessages.withUnsafeBytes(addressExtractor(of: RTAX_IFA, interfaceMessages.count))
    }

    /// Array of all IPv4 addresses (including aliases) of the interface.
    public var ip4: [in_addr] {
        return interfaceMessages.withUnsafeBytes(
            addressExtractor(of: RTAX_IFA, interfaceMessages.count)
            ).filter{type(of: $0).family == .ip4}.flatMap{$0 as? in_addr}
    }

    /// IPv4 network mask.
    public var mask4: in_addr? {
        return interfaceMessages.withUnsafeBytes(
            addressExtractor(of: RTAX_NETMASK, interfaceMessages.count)
            ).filter{type(of: $0).family == .ip4}.first as? in_addr
    }

    /// Array of all IPv6 addresses of the interface.
    public var ip6: [in6_addr] {
        return interfaceMessages.withUnsafeBytes(
            addressExtractor(of: RTAX_IFA, interfaceMessages.count)
            ).filter{type(of: $0).family == .ip6}.flatMap{$0 as? in6_addr}
    }

    /// Array of all IPv6 network masks of the interface.
    /// - Note: The number and order of the masks correspond to the number and order
    /// of the ip6 addresses, so that they can be connected together using `zip` function.
    /// ```
    /// if let interface = (Interfaces().first{$0.ip6.count != 0}) {
    ///    let addressesWithMasks = zip(interface.ip6, interface.masks6)
    /// }
    /// ```
    public var masks6: [in6_addr] {
        return interfaceMessages.withUnsafeBytes(
            addressExtractor(of: RTAX_NETMASK, interfaceMessages.count)
            ).filter{type(of: $0).family == .ip6}.flatMap{$0 as? in6_addr}
    }

    /// `masks6` represented as prefix lengths.
    public var prefixes6: [Int] {
        return self.masks6.map {
            var in6a = $0
            return withUnsafeBytes(of: &in6a) {bytes in
                var i = 0
                var n = 0
                while i != bytes.count && bytes[i] == 0xff {
                    n += 8
                    i += 1
                }
                if i != bytes.count {
                    var b = bytes[i]
                    while b != 0 {
                        b <<= 1
                        n += 1
                    }
                }
                return n
            }
        }
    }

    /// Interface broadcast address, if applicable.
    public var broadcast: in_addr? {
        guard self.options.contains(.broadcast) else {return nil}
        guard !self.options.contains(.pointopoint) else {return nil}
        return interfaceMessages.withUnsafeBytes(
            addressExtractor(of: RTAX_BRD, interfaceMessages.count)
        ).first{type(of: $0).family == .ip4} as? in_addr
    }

    /// For point-to-point interfaces, destination address.
    public var destination: IPAddress? {
        guard self.options.contains(.pointopoint) else {return nil}
        return interfaceMessages.withUnsafeBytes(
            addressExtractor(of: RTAX_BRD, interfaceMessages.count)
        ).first
    }
}

public struct Interfaces: Collection {
    public typealias Element = Interface

    /// Contains `sysctl` results
    let routingMessages: Data

    public init() {
        var needed: size_t = 0
        var mib: [Int32] = [CTL_NET, PF_ROUTE, 0, 0, NET_RT_IFLIST, 0]
        guard sysctl(&mib[0], 6, nil, &needed, nil, 0) == 0 else {
            fatalError(String(validatingUTF8: strerror(errno)) ?? "")
        }
        let buf_p = UnsafeMutableRawPointer.allocate(bytes: needed, alignedTo: MemoryLayout<rt_msghdr>.alignment)
        // FIXME: when 9.3 will be available, replace with .allocate(bytesCount: needed, alignment: MemoryLayout<rt_msghdr>.alignment
        guard sysctl(&mib[0], 6, buf_p, &needed, nil, 0) == 0 else {
            fatalError(String(validatingUTF8: strerror(errno)) ?? "")
        }
        // Wrap sysctl's results with `Data` for memory management
        self.routingMessages = Data(bytesNoCopy: buf_p, count: needed, deallocator: .custom {
            $0.deallocate(bytes: $1, alignedTo: MemoryLayout<rt_msghdr>.alignment)
            // FIXME: when 9.3 will be available, replace with .deallocate()
            })
    }

/// The following are necessary to ensure conformance `Collection` protocol.

    public struct Index: Comparable {
        fileprivate let value: Int
        public static func == (lhs: Index, rhs: Index) -> Bool {return lhs.value == rhs.value}
        public static func < (lhs: Index, rhs: Index) -> Bool {return lhs.value < rhs.value}
        fileprivate init(_ value: Int) {self.value = value}
    }

    private func nextIndex(from indexValue: Int) -> Index {
        return routingMessages.withUnsafeBytes {(start: UnsafePointer<Int8>) -> Index in
            var location = indexValue
            while location != endIndex.value {
                let (version, type, length) = start.advanced(by: location).withMemoryRebound(to: rt_msghdr.self, capacity: 1) {
                    return ($0.pointee.rtm_version, $0.pointee.rtm_type, $0.pointee.rtm_msglen)
                }
                assert(location + Int(length) <= endIndex.value)
                guard numericCast(version) == RTM_VERSION && numericCast(type) == RTM_IFINFO  else {
                    location += Int(length)
                    continue
                }
                let (addrs, index) = start.advanced(by: location).withMemoryRebound(to: if_msghdr.self, capacity: 1) {
                    return ($0.pointee.ifm_addrs, $0.pointee.ifm_index)
                }
                guard addrs & RTA_IFP != 0 && index != 0 else {
                    location += Int(length)
                    continue
                }
                break
            }
            return Index(location)
        }
    }

    public var endIndex: Index {return Index(routingMessages.endIndex)}
    public var startIndex: Index {return nextIndex(from: routingMessages.startIndex)}

    public func index(after given: Index) -> Index {
        return routingMessages.suffix(from: given.value).withUnsafeBytes {(ifm_p: UnsafePointer<if_msghdr>) -> Index in
            assert(ifm_p.pointee.ifm_version == RTM_VERSION)
            assert(ifm_p.pointee.ifm_type == RTM_IFINFO)
            assert(ifm_p.pointee.ifm_addrs & RTA_IFP != 0)
            assert(ifm_p.pointee.ifm_index != 0)
            ifm_p.advanced(by: 1).withMemoryRebound(to: sockaddr_dl.self, capacity: 1) {
                assert($0.pointee.isWellFormed)
                assert($0.index == ifm_p.pointee.ifm_index)
            }
            return nextIndex(from: given.value + Int(ifm_p.pointee.ifm_msglen))
        }
    }

    public subscript(position: Index) -> Element {
        return Element(routingMessages.subdata(in: position.value..<index(after: position).value))
    }
}


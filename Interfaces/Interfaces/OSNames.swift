//  Services.swift
//  Simplenet Interfaces module
//  Copyright (c) 2018 Vladimir Raisov. All rights reserved.
//  Licensed under MIT License

#if os(macOS)
    import CoreFoundation
    import class Foundation.NSString
    import SystemConfiguration

    public struct OSNames: BidirectionalCollection {

        fileprivate typealias ElementContentType = (custom: String, config: String, bsd: String)
        private var names = [ElementContentType]()

        public init() {
            let scpname = "simplenet" as CFString
            guard let scp = SCPreferencesCreate(nil, scpname, nil) else {return}
            guard let services = SCNetworkServiceCopyAll(scp) else {return}
            for id in services as Array {
                let service = id as! SCNetworkService
                guard let customName = SCNetworkServiceGetName(service) as String? else {continue}
                guard let interface = SCNetworkServiceGetInterface(service) else {continue}
                guard let bsdName = SCNetworkInterfaceGetBSDName(interface) as String? else {continue}
                guard let configName = SCNetworkInterfaceGetLocalizedDisplayName(interface) as String? else {continue}
                names.append((custom: customName, config: configName, bsd: bsdName))
            }
        }

        public struct Element {
            private let value: ElementContentType
            fileprivate init(_ value: ElementContentType) {
                self.value = value
            }
            public var customName: String {return self.value.custom}
            public var configName: String {return self.value.config}
            public var name: String {return self.value.bsd}
        }

        public var endIndex: Int {return names.endIndex}
        public var startIndex: Int {return names.startIndex}
        public func index(after given: Int) -> Int {return names.index(after: given)}
        public func index(before given: Int) -> Int {return names.index(before: given)}
        public subscript(position: Int) -> Element {return Element(names[position])}
    }
#endif


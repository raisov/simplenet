
# Simplenet
Simplenet is a Swift language tool intended for programming of high-performance socket based datagram networking with flexible handling of network interfaces. It supports unicast, multicast and broadcast operations.

## Overview
Simplenet consists of three modules: `Transceiver`, `Interfaces` and `Sockets`.
- `Transceiver` module supports asynchronous I/O using UDP protocol. In addition it provides obtaining ancillary data from received datagrams as well as automatic addressing of replies.
- `Interfaces` implements Swift collection with elements corresponding to the network interfaces of the host. Each element contains interface index and name, information on its type and state as well as link level (MAC) and IP/IPv6 addresses.
- `Sockets` module provides the ability to perform basic operations with network sockets in Swift style with `try-catch` error handling. It also contains Swift protocols and extensions for `in[6]_addr` and `sockaddr` family structures allowing to use them in Swift style while avoiding `Unsafe` functions and types. 
`Sockets` module is intended primarily for internal use. However, it can be useful when utilizing sockets networking APIs in Swift.
## Application description
 It is implied that the main area of Simplenet use is communication with devices that are only able to support simple net protocols such as UDP. For example it can be [KNX](www.knx.org) IP router that multicasts KNX telegrams to network or [Tritium CAN Ethernet Bridge] (https://www.tritium.com.au/shop/can-ethernet-bridge/).
In general, Simplenet can be useful in any application, where you need asynchronous exchange of short messages.
### Receiving and transmitting data
`Transceiver` module contains `Datagram` structure representing data received from socket. Although this structure can be created on its own the preferred way is to use `Receiver` and `Transmitter` classes.
These classes perform asynchronous network operations using GCD (libdispatch). Here are some fragments of echo server and client programs using these classes. Error handling is omitted for simplicity.
```swift// Echo server
struct Echo: DatagramHandler {    // Data handler for incoming datagrams    func dataDidRead(datagram: Datagram) {
        datagram.reply(with: datagram.data)
    }
}
let receiver = Receiver(port: 7777)
receiver.delegate = Echo()
```
```swift
//Echo clientstruct ReplyAcceptor: DatagramHandler {
    // data handler for replies
    func dataDidRead(datagram: Datagram) {
        let response = String(data: datagram.data, encoding: .utf8)
        response.map{print($0)}
    }
}let transmitter = Transmitter(host: “localhost”, port: 7777)
transmitter.delegate = ReplyAcceptor()transmitter.send(“Hello, World!”)
```

If `port` is the only parameter specified when creating `Receiver` the object will receive unicast and broadcast datagrams addressed to this port.
In order to receive multicast datagrams one must also specify `multicast` parameter providing the value of the group address. Both IPv4 and IPv6 addresses are allowed.
```swift
let recv = Receiver(port: 7777, multicast: “239.1.1.1”)
let recv6 = Receiver(port: 7777, multicast: “ff02::114”)
```

In order to send datagrams with the option to get a response one needs to use `send(_: Data)` method of the `Transmitter` class. This class is created with parameters `host` and `port` specifying the recipient address. Either host name, unicast or multicast IP address can be provided. If `host` parameter is omitted, broadcast transmission will be performed.
Both `Receiver` and `Transmitter` classes have `delegate` property conforming to `DatagramHandler` protocol, specifying the actual object used to receive incoming datagrams and replies.
```swift
public protocol DatagramHandler {
    func dataDidRead(_ datagram: Datagram)
    func errorDidOccur(_ error: Error)
}
```

One can guess that `dataDidRead` method is used to process datagram received and `errorDidOccur` for error handling. This is actually true.
### Using Interfaces
When creating `Receiver` and `Transmitter` the `interface` parameter can be specified. For `Receiver` this parameter will determine network listener interface. If the parameter is omitted all appropriate interfaces are listened on.
If `Transmitter` is created for unicast transmission the `interface` is not usually required. In this case it can only be useful if the host has two or more interfaces connected to the same network, for example  Wi-Fi and wired Ethernet, and only one of them should be used. Setting `interface` may be necessary for multicast and broadcast transmissions. If `interface` is not specified in these cases, transmission will be performed through the default interface determined by the operating system, which may not always be the desired option.
Setting `host` parameter is not needed when the `Transmitter` is created for broadcast. In this case the broadcast address of the interface, for example 192.168.0.255, will serve as destination. If neither `host` nor `interface` is provided, the transmission will go through the default interface to 255.255.255.255.
`Interfaces` class is used to obtain the list of system interfaces. It conforms to `Collection` protocol with elements of `Interface` type that gives access to all basic characteristics of the network interface, such as:
- interface BSD name, for example lo0, en0, p2p0;
- interface index, used in some socket functions;
- interface type, such as ethernet, firewire, VLAN…
- interface options, such as multicast or broadcast availability;
- MAC, IPv4 and IPv6 addresses, assigned to the interface and their corresponding network masks;
- MTU, network metric and baudrate.
This allows choosing interface suitable for specific tasks.  
Here are the code examples using `Interfaces`.
```swift
// Interface with BSD name “en1”
let interface = Interfaces().first{$0.name == "en1"}
```

```swift
// Loopback interface
let interface = Interfaces().first{$0.type == .loopback}
```

```swift
// Array of all IPv4 addresses
// of all multicast enabled interfaces
let addresses = Interfaces().filter{
    $0.options.contains(.multicast)
}.flatMap{
    $0.ip4
}
```

In the example above the result is an array of IPAddress elements  (IPAddress type defined in the `Sockets` module).
Despite the fact that macOS underlying Darwin system uses BSD names to identify interfaces these names are not utilized in GUI (for some interfaces they can be seen in `` - `About this Mac` - `System Report` - `Network`). Therefore the `Interfaces` module defines `OSNames` type to establish correspondence between BSD names and the names used in macOS, such as Ethernet, Wi-Fi etc.
```swift
let osname = OSNames().first{$0.name == "en0"}?.configName
// osname == “Ethernet"
```

It should be noted that not all available interfaces are listed in `System Preferences` and accordingly in `OSNames`. It is true for example about the interfaces of Parallel Desktop virtual machines. However the `Interfaces()` enumerates all existing interfaces including the ones you will never need.
### Using Datagram
In addition to `data` property and `reply` method shown in the examples above, the `Datagram` structure has the following properties:
- `sender: InternetAddress?` containing IP and port the datagram was sent from;
- `destination: IPAddress?, may be unicast, multicast or broadcast destination address;
- `interface: Interface?` specifies the interface over which datagram was received. 
`InternetAddress` and `IPAddress` are the protocols defined in Sockets module. Their purpose is to unify working with IPv4 and IPv6 addresses. 
The values of `Datagram` properties determine how the `reply` method will be executed. This method always tries to send reply through the interface that the datagram was received from. If the incoming datagram was sent to unicast address then the `destination` becomes sender address in the response. The interface address is used instead when replying to broadcast or multicast datagram. Naturally, the `sender` becomes the destination address.

Thus the `Datagram` contains all necessary information to send the reply. This structure can be considered as service request that the server can respond to asynchronously when the requested data is obtained or when some external event occurs.
## Getting started guide
After you clone or download Simplenet, simplenet.xcworkspace will be found in the created directory. This workspace contains projects to build libTransceiver, libInterfaces and libSockets static libraries. You can add your own project to this workspace, link it with the libraries, and use the provided APIs. Naturally you can simply add source code to your own project or use the modules in any other desired way. In addition the workspace contains the examples of the command line EchoServer and EchoClient, as well as listInterfaces program demonstrating what information can be received with `Interfaces` module.
The comments of each module contain its API documentation.



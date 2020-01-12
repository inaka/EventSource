![EventSource](header.png)

## EventSource
SSE Client written on Swift using NSURLSession.

[![Build Status](https://api.travis-ci.org/inaka/EventSource.svg)](https://travis-ci.org/inaka/EventSource) [![codecov.io](https://codecov.io/github/inaka/EventSource/badge.svg?branch=master)](https://codecov.io/github/inaka/EventSource?branch=master) [![codecov.io](https://img.shields.io/badge/pod-v3.0.1-brightgreen.svg)](https://github.com/inaka/EventSource/blob/master/IKEventSource.podspec)

### Abstract

This is an EventSource implementation written on Swift following the [W3C EventSource](http://www.w3.org/TR/eventsource/) document. If something is missing or not completely right open an issue and I'll work on it! 

If you like the library please leave us a ★. That helps us to stay engaged on the mantainence!

### Changes from version 2.2.1 to 3.0

I took some time to review all the forks, pull requests and issues opened on github. The main changes and complains I found were related to the connection and the `Last-Event-Id` handling.

The changes on this version are:

- `EventSource` doesn't connect automatically anymore. It waits until  `connect(lastEventId: String? = nil)` method is called. This method accepts a `lastEventId` which will be sent to the server upon connection.
- `EventSource` lets you call `disconnect()` whenever you want.
- `EventSource` doesn't store the `Last-Event-Id` anymore and you will have to take care of storing the `id` and sending using it or not in the `connect` method.
- `EventSource` doesn't reconnect at all. If a network layer error occurs (disconnection, timeout, etc) or if the server closes the connection you will have to take care to reconnect with the server.
- Modularization. This library has been around since `Swift 1.0` and started just as a way to learn the language. With this new version the whole code has been improved, commented and fully tested to make it easier to track problems and extend in the future.

### How to use it?

There is a simple working sample in the repository. Check the ViewController.swift to see how to use it.

Also in `sse-server` folder you will find an extremely simple `node.js` server to test the library. To run the server you just need to:

- `npm install`
- `node sse.js`

### Install

#### Cocoapods

1) Include EventSource in your `Podfile`: `pod 'IKEventSource'`

2) Import the framework:

```
import IKEventSource
```

#### Carthage

1) Include EventSource in your `Cartfile`: `github "inaka/EventSource"`

2) Import the framework:

```
import IKEventSource
```

For further reference see [Carthage's documentation](https://github.com/Carthage/Carthage/blob/master/README.md).

#### Swift Package Manager

1) Include EventSource in your `Package.swift`: `github "inaka/EventSource"`
```swift
import PackageDescription

let package = Package(
dependencies: [
    .package(url: "https://github.com/inaka/EventSource.git", .branch("master"))
])
```

2) Import the framework:

```
import IKEventSource
```

#### Swift API:

```swift
/// RetryTime: This can be changed remotly if the server sends an event `retry:`
var retryTime: Int { get }

/// URL where EventSource will listen for events.
var url: URL { get }

/// The last event id received from server. This id is neccesary to keep track of the last event-id received to avoid
/// receiving duplicate events after a reconnection.
var lastEventId: String? { get }

/// Current state of EventSource
var readyState: EventSourceState { get }

/// Method used to connect to server. It can receive an optional lastEventId indicating the Last-Event-ID
///
/// - Parameter lastEventId: optional value that is going to be added on the request header to server.
func connect(lastEventId: String?)

/// Method used to disconnect from server.
func disconnect()

/// Returns the list of event names that we are currently listening for.
///
/// - Returns: List of event names.
func events() -> [String]

/// Callback called when EventSource has successfully connected to the server.
///
/// - Parameter onOpenCallback: callback
func onOpen(_ onOpenCallback: @escaping (() -> Void))

/// Callback called once EventSource has disconnected from server. This can happen for multiple reasons.
/// The server could have requested the disconnection or maybe a network layer error, wrong URL or any other
/// error. The callback receives as parameters the status code of the disconnection, if we should reconnect or not
/// following event source rules and finally the network layer error if any. All this information is more than
/// enought for you to take a decition if you should reconnect or not.
/// - Parameter onOpenCallback: callback
func onComplete(_ onComplete: @escaping ((Int?, Bool?, NSError?) -> Void))

/// This callback is called everytime an event with name "message" or no name is received.
func onMessage(_ onMessageCallback: @escaping ((_ id: String?, _ event: String?, _ data: String?) -> Void))

/// Add an event handler for an specific event name.
///
/// - Parameters:
///   - event: name of the event to receive
///   - handler: this handler will be called everytime an event is received with this event-name
func addEventListener(_ event: String,
                      handler: @escaping ((_ id: String?, _ event: String?, _ data: String?) -> Void))

/// Remove an event handler for the event-name
///
/// - Parameter event: name of the listener to be remove from event source.
func removeEventListener(_ event: String)


```


#### Examples:
---
**Event**:

```
id: event-id
event: event-name
data: event-data
```

**Calls** 

```
eventSource.addEventListener("event-name") { (id, event, data) in
  // Here you get an event 'event-name'
}
```
---

**Event**:

```
id: event-id
data: event-data
```

```
data: event-data
```

**Calls** 

```
eventSource.onMessage { (id, event, data) in
  // Here you get an event without event name!
}
```
---

**Event**:

```
id: event-id
data: event-data-1
data: event-data-2
data: event-data-3
```

**Calls** 

```
eventSource.onMessage { (id, event, data) in
  // Here you get an event without event name!
  // data: event-data-1\nevent-data-2\nevent-data-3
}
```
---

**Event**:

```
:heartbeat
```

**Calls** 

```
nothing it's a comment
```
---

### Live example

This is the example shipped with the app. If you run the server and run the app you will be able to see this example live. The moving box is just to show that everything works on background and the main thread performance shows no degradation. (The gif is pretty bad to see that, but if you click on the image you will be taken to the gfycat version of the gif which runs way smoother) 

![Sample](sample.gif)

### Contributors
Thanks to all the contributors for pointing out missing stuff or problems and fixing them or opening issues!!

- [hleinone](https://github.com/hleinone)
- [chrux](https://github.com/chrux)
- [danielsht86](https://github.com/danielsht86)
- [Zeeker](https://github.com/Zeeker)
- [col](https://github.com/col)
- [heyzooi](https://github.com/heyzooi)
- [alexpalman](https://github.com/alexpalman)
- [robbiet480](https://github.com/robbiet480)
- [tbaranes](https://github.com/tbaranes)
- [jwfriese](https://github.com/jwfriese)

### Contact Us
If you find any **bugs** or have a **problem** while using this library, please [open an issue](https://github.com/inaka/EventSource/issues/new) in this repo (or a pull request :)).

Please provide an example of the problem you are facing. If an event is not correctly parsed please provide a sample event.

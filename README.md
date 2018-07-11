![EventSource](header.png)

## EventSource
SSE Client written on Swift using NSURLSession.

[![Build Status](https://api.travis-ci.org/inaka/EventSource.svg)](https://travis-ci.org/inaka/EventSource) [![codecov.io](https://codecov.io/github/inaka/EventSource/badge.svg?branch=master)](https://codecov.io/github/inaka/EventSource?branch=master) [![codecov.io](https://img.shields.io/badge/pod-v1.1.4-brightgreen.svg)](https://github.com/inaka/EventSource/blob/master/IKEventSource.podspec)

### Abstract

This is an EventSource implementation written on Swift trying to keep the API as similar as possible to the JavaScript one. Written following the [W3C EventSource](http://www.w3.org/TR/eventsource/). If something is missing or not completely right open an issue and I'll work on it!

### How to use it?

It works just like the JavaScript version, the main difference is when creating a new EventSource object you can add headers to the request, for example if your server uses basic auth you can add the headers there.

`Last-Event-Id` is completely handled by the library, so it's sent to the server if the connection drops and library needs to reconnect. Also the `Last-Event-Id` is stored in `NSUserDefaults` so we can keep the last received event for the next time the app is used to avoid receiving duplicate events.

The library automatically reconnects if connection drops. The reconnection time is 3 seconds. This time may be changed by the server sending a `retry: time-in-milliseconds` event.

Also in `sse-server` folder you will find an extremely simple `node.js` server to test the library. To run the server you just need to:

- `npm install`
- `node sse.js`

### Install

EventSource delivers itself as a framework. There are a couple ways to include in your app.

#### Cocoapods

1) Include EventSource in your `Podfile`:
`pod 'IKEventSource'`

2) Run `pod install`

```
pod 'IKEventSource'

```

3) Import the framework:

```
import EventSource
```

#### Carthage

1) Include EventSource in your `Cartfile`:
`github "inaka/EventSource"`

2) Run `carthage update --platform 'iOS'`

3) In your app target, navigate to the `Link Binary with Libraries` section, and add `EventSource.framework`, which you should be able to find in your `Carthage/Build/iOS` directory

4) To your test target, add a `Run Script` to call the Carthage `copy-frameworks` script:

`/usr/local/bin/carthage copy-frameworks`

Additionally, add as an input file the Event Source framework. The path probably looks something like this:

`$(SRCROOT)/Carthage/Build/iOS/EventSource.framework`

5) Import the framework:

```
import EventSource
```

For further reference see [Carthage's documentation](https://github.com/Carthage/Carthage/blob/master/README.md).

#### Javascript API:

```JavaScript
var eventSource = new EventSource(server);

eventSource.onopen = function() {
    // When opened
}

eventSource.onerror = function() {
    // When errors
}

eventSource.onmessage = function(e) {  
    // Here you get an event without event name!
}

eventSource.addEventListener("ping", function(e) {
  // Here you get an event 'event-name'
}, false);

eventSource.close();
```

#### Swift API:

```swift
var eventSource: EventSource = EventSource(url: server, headers: ["Authorization" : basicAuthAuthorization])
   
eventSource.onOpen {
  // When opened
}
        
eventSource.onError { (error) in
  // When errors
}

eventSource.onMessage { (id, event, data) in
  // Here you get an event without event name!
}
   
eventSource.addEventListener("event-name") { (id, event, data) in
  // Here you get an event 'event-name'
}

eventSource.close()
```

We added the following methods that are not available on JavaScript EventSource API but we think they might be useful:

```swift
public func removeEventListener(event: String) -> Void
public func events() -> Array<String>
```

Also the following properties are available: 

- **readyState**: Status of EventSource
  - **EventSourceState.Closed**
  - **EventSourceState.Connecting**
  - **EventSourceState.Open**
- **URL**: EventSource server URL.

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

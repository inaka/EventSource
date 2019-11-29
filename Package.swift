// swift-tools-version:5.1
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "EventSource",
    platforms: [
        .iOS(.v8), .tvOS(.v9), .macOS(.v10_10)
    ],
    products: [
        .library(name: "EventSource", targets: ["EventSource"]),
    ],
    dependencies: [],
    targets: [
        .target(name: "EventSource", dependencies: []),
        .testTarget(name: "EventSourceTests", dependencies: ["EventSource"]),
    ]
)

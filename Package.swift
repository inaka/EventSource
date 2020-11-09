// swift-tools-version:5.1
// The swift-tools-version declares the minimum version of Swift required to build this package.
import PackageDescription

let package = Package(
    name: "EventSource",
	platforms: [
		.iOS("9.0"),
		.macOS("10.10"),
	],
    products: [
        // Products define the executables and libraries produced by a package, and make them visible to other packages.
        .library(
            name: "EventSource",
            targets: ["EventSource"]),
    ],
    dependencies: [],
    targets: [
        // Targets are the basic building blocks of a package. A target can define a module or a test suite.
        // Targets can depend on other targets in this package, and on products in packages which this package depends on.
        .target(
            name: "EventSource",
			dependencies: [],
			path: "EventSource"),
        .testTarget(
			name: "EventSourceTests",
			dependencies: ["EventSource"],
			path: "EventSourceTests"),
    ]
)

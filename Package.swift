// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "swiftpy-views",
    platforms: [.iOS(.v26), .macOS(.v26), .visionOS(.v26)],
    products: [
        .library(
            name: "SwiftPyViews",
            targets: ["SwiftPyViews"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/felfoldy/SwiftPy", from: "0.14.0"),
    ],
    targets: [
        .target(
            name: "SwiftPyViews",
            dependencies: ["SwiftPy"]
        ),
    ]
)

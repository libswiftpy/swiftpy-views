// swift-tools-version: 6.3
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
        .package(url: "https://github.com/felfoldy/SwiftPy", from: "0.29.0"),
        .package(url: "https://github.com/appstefan/HighlightSwift.git", from: "1.1.0"),
        // Remote fork until the SVG sizing fixes land upstream. See the tech-debt skill.
        .package(url: "https://github.com/felfoldy/MarkdownView", branch: "fix/scalable-svg", traits: []),
    ],
    targets: [
        .target(
            name: "SwiftPyViews",
            dependencies: [
                "SwiftPy",
                "HighlightSwift",
                .product(name: "MarkdownView", package: "MarkdownView"),
            ],
        ),
    ]
)

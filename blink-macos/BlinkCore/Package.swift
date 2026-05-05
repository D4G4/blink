// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "BlinkCore",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "BlinkCore", targets: ["BlinkCore"]),
    ],
    targets: [
        .target(name: "BlinkCore"),
        .testTarget(name: "BlinkCoreTests", dependencies: ["BlinkCore"]),
    ]
)

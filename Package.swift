// swift-tools-version:4.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "SNMPManager",
    products: [
        .library(
            name: "SNMPManager",
            targets: ["SNMPManager"]),
    ],
    dependencies: [
        .package(url: "https://github.com/vapor/vapor.git", from: "3.0.0"),
    ],
    targets: [
        .target(
            name: "SNMPManager",
            dependencies: ["Vapor"]),
        .testTarget(
            name: "SNMPManagerTests",
            dependencies: ["SNMPManager"]),
    ]
)

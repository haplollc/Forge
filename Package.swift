// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "Forge",
    platforms: [
        .iOS(.v16),
        .macOS(.v13)
    ],
    products: [
        .library(
            name: "Forge",
            targets: ["Forge"]
        ),
    ],
    targets: [
        .target(
            name: "Forge",
            dependencies: [],
            path: "Sources/Forge"
        ),
        .testTarget(
            name: "ForgeTests",
            dependencies: ["Forge"],
            path: "Tests/ForgeTests"
        ),
    ]
)

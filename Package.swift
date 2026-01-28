// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "SemanticToolRouter",
    platforms: [
        .macOS(.v14),
        .iOS(.v17),
        .tvOS(.v17),
        .watchOS(.v10),
        .visionOS(.v1)
    ],
    products: [
        .library(
            name: "SemanticToolRouter",
            targets: ["SemanticToolRouter"]
        ),
    ],
    targets: [
        .target(
            name: "SemanticToolRouter",
            dependencies: [],
            path: "Sources/SemanticToolRouter"
        ),
        .testTarget(
            name: "SemanticToolRouterTests",
            dependencies: ["SemanticToolRouter"],
            path: "Tests/SemanticToolRouterTests"
        ),
    ]
)

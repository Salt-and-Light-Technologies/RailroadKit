// swift-tools-version: 6.3
import PackageDescription

let package = Package(
    name: "RailroadKit",
    platforms: [
        .macOS(.v14),
        .iOS(.v17),
    ],
    products: [
        .library(
            name: "RailroadKit",
            targets: ["RailroadKit"]
        ),
    ],
    targets: [
        .target(
            name: "RailroadKit",
            path: "Sources/RailroadKit"
        ),
        .testTarget(
            name: "RailroadKitTests",
            dependencies: ["RailroadKit"],
            path: "Tests/RailroadKitTests"
        ),
        // Future: .target(name: "RailroadKitSwiftData", dependencies: ["RailroadKit"])
    ],
    swiftLanguageModes: [.v6]
)

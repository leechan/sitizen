// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Sitizen",
    platforms: [
        .macOS(.v14)
    ],
    targets: [
        .executableTarget(
            name: "Sitizen",
            path: "Sources/Sitizen"
        )
    ]
)

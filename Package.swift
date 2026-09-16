// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "ClaudeMana",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(name: "ClaudeMana", path: "Sources")
    ]
)

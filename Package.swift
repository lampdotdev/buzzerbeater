// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "BuzzerBeater",
    platforms: [.macOS(.v14)],
    targets: [.executableTarget(name: "BuzzerBeater", path: "Sources")]
)

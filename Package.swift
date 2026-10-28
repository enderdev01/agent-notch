// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "AgentNotch",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "AgentNotch",
            path: "Sources/AgentNotch",
            exclude: ["Resources"]
        ),
        .testTarget(name: "AgentNotchTests", dependencies: ["AgentNotch"])
    ],
    swiftLanguageModes: [.v5]
)

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
        )
    ],
    swiftLanguageModes: [.v5]
)

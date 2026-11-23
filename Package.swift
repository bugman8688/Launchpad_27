// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Launchpad27",
    platforms: [
        .macOS("27.0")
    ],
    targets: [
        .executableTarget(
            name: "Launchpad27",
            path: "Sources/Launchpad27"
        )
    ]
)

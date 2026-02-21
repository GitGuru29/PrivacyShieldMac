// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "PrivacyShield",
    platforms: [
        .macOS(.v10_15)
    ],
    targets: [
        .executableTarget(
            name: "PrivacyShield",
            path: "Sources"
        )
    ]
)

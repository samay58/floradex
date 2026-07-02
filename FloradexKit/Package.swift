// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "FloradexKit",
    platforms: [
        .iOS("18.0"),
        .macOS("14.0"),
    ],
    products: [
        .library(name: "FloradexKit", targets: ["FloradexKit"]),
        .library(name: "FloradexKitFixtures", targets: ["FloradexKitFixtures"]),
    ],
    targets: [
        .target(name: "FloradexKit"),
        .target(name: "FloradexKitFixtures", dependencies: ["FloradexKit"]),
        .testTarget(
            name: "FloradexKitTests",
            dependencies: ["FloradexKit", "FloradexKitFixtures"]
        ),
    ]
)

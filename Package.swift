// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "ThreadMapper",
    defaultLocalization: "en",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "ThreadMapper", targets: ["ThreadMapper"]),
    ],
    targets: [
        .target(
            name: "ThreadMapper",
            path: "Sources",
            exclude: ["ThreadMapper/Assets.xcassets",
                      "ThreadMapper/Info.plist",
                      "ThreadMapper/ThreadMapper.entitlements"],
            sources: ["ThreadMapper", "Shared"],
            swiftSettings: [.enableExperimentalFeature("StrictConcurrency")]
        ),
        .testTarget(
            name: "ThreadMapperTests",
            dependencies: ["ThreadMapper"],
            swiftSettings: [.enableExperimentalFeature("StrictConcurrency")]
        ),
    ]
)

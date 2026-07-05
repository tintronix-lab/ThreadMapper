// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "ThreadMapper",
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
            sources: ["ThreadMapper", "Shared"]
        ),
        .testTarget(name: "ThreadMapperTests", dependencies: ["ThreadMapper"]),
    ]
)

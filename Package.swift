// swift-tools-version: 5.9
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
            dependencies: [],
            exclude: [
                "Info.plist",
                "ThreadMapper.entitlements",
            ]
        ),
        .testTarget(name: "ThreadMapperTests", dependencies: ["ThreadMapper"]),
    ]
)

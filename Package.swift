// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "ThreadMapper",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "ThreadMapper", targets: ["ThreadMapper"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-collections", from: "1.1.0"),
    ],
    targets: [
        .target(
            name: "ThreadMapper",
            dependencies: [
                .product(name: "Collections", package: "swift-collections"),
            ]
        ),
        .testTarget(name: "ThreadMapperTests", dependencies: ["ThreadMapper"]),
    ]
)

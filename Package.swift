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
            dependencies: [
                .product(name: "Charts", package: "swift-charts"),
                .product(name: "Collections", package: "swift-collections"),
            ]
        ),
        .testTarget(name: "ThreadMapperTests", dependencies: ["ThreadMapper"]),
    ]
)

// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "CryptoStream-TCA",
    platforms: [
        .iOS(.v16),
        .macOS(.v13)
    ],
    products: [
        .library(
            name: "CryptoStream-TCA",
            targets: ["CryptoStream-TCA"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/pointfreeco/swift-composable-architecture", from: "1.0.0")
    ],
    targets: [
        .target(
            name: "CryptoStream-TCA",
            dependencies: [
                .product(name: "ComposableArchitecture", package: "swift-composable-architecture")
            ]
        ),
        .testTarget(
            name: "CryptoStream-TCATests",
            dependencies: ["CryptoStream-TCA"]
        ),
    ]
)

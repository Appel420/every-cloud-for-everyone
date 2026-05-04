// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "EveryCloudForEveryone",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .library(
            name: "EveryCloudForEveryone",
            targets: ["EveryCloudForEveryone"]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-crypto.git", from: "3.0.0")
    ],
    targets: [
        .target(
            name: "EveryCloudForEveryone",
            dependencies: [
                .product(name: "Crypto", package: "swift-crypto")
            ],
            path: "Sources/EveryCloudForEveryone"
        ),
        .testTarget(
            name: "EveryCloudForEveryoneTests",
            dependencies: ["EveryCloudForEveryone"],
            path: "Tests/EveryCloudForEveryoneTests"
        )
    ]
)

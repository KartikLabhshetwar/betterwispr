// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "BetterWispr",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "BetterWispr", targets: ["BetterWispr"]),
        .executable(name: "BetterWisprCLI", targets: ["BetterWisprCLI"]),
        .library(name: "BetterWisprCore", targets: ["BetterWisprCore"])
    ],
    dependencies: [
        .package(url: "https://github.com/argmaxinc/argmax-oss-swift.git", exact: "1.1.0"),
        .package(url: "https://github.com/FluidInference/FluidAudio.git", exact: "0.17.5")
    ],
    targets: [
        .target(name: "BetterWisprCore", dependencies: [
            .product(name: "WhisperKit", package: "argmax-oss-swift"),
            .product(name: "FluidAudio", package: "FluidAudio")
        ]),
        .executableTarget(name: "BetterWispr", dependencies: ["BetterWisprCore"]),
        .executableTarget(name: "BetterWisprCLI", dependencies: ["BetterWisprCore"]),
        .testTarget(name: "BetterWisprCoreTests", dependencies: ["BetterWisprCore"])
    ],
    swiftLanguageModes: [.v6]
)

// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "LoseWeightCore",
    platforms: [.iOS(.v18), .macOS(.v15)],
    products: [
        .library(name: "LoseWeightCore", targets: ["LoseWeightCore"])
    ],
    targets: [
        .target(name: "LoseWeightCore"),
        .testTarget(name: "LoseWeightCoreTests", dependencies: ["LoseWeightCore"])
    ],
    swiftLanguageModes: [.v5]
)

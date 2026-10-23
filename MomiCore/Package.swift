// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "MomiCore",
    platforms: [.iOS(.v18), .macOS(.v15)],
    products: [.library(name: "MomiCore", targets: ["MomiCore"]), .executable(name: "MomiCoreChecks", targets: ["MomiCoreChecks"])],
    targets: [
        .target(name: "MomiCore"),
        .executableTarget(name: "MomiCoreChecks", dependencies: ["MomiCore"]),
        .testTarget(name: "MomiCoreTests", dependencies: ["MomiCore"])
    ]
)

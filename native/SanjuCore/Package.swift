// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "SanjuCore",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [.library(name: "SanjuCore", targets: ["SanjuCore"])],
    targets: [.target(name: "SanjuCore"), .testTarget(name: "SanjuCoreTests", dependencies: ["SanjuCore"])]
)

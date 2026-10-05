// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "CampusCore",
    platforms: [.iOS(.v16), .macOS(.v13)],
    products: [.library(name: "CampusCore", targets: ["CampusCore"])],
    targets: [
        .target(name: "CampusCore"),
        .testTarget(name: "CampusCoreTests", dependencies: ["CampusCore"])
    ]
)

// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "LaterRead",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "LaterRead", targets: ["LaterRead"])
    ],
    dependencies: [
        .package(url: "https://github.com/soffes/HotKey", from: "0.2.0")
    ],
    targets: [
        .executableTarget(
            name: "LaterRead",
            dependencies: ["HotKey"],
            path: "LaterRead"
        )
    ]
)

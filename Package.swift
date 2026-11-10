// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Padlock",
    platforms: [.macOS(.v13)],
    products: [.executable(name: "Padlock", targets: ["Padlock"])],
    targets: [
        .executableTarget(name: "Padlock", path: "Sources/Padlock"),
        .testTarget(name: "PadlockTests", dependencies: ["Padlock"], path: "Tests/PadlockTests")
    ]
)

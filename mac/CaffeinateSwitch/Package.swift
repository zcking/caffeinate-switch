// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "CaffeinateSwitch",
    platforms: [
        .macOS(.v13),
    ],
    products: [
        .library(name: "SwitchCore", targets: ["SwitchCore"]),
        .executable(name: "CaffeinateSwitchApp", targets: ["CaffeinateSwitchApp"]),
    ],
    targets: [
        .target(name: "SwitchCore"),
        .executableTarget(name: "CaffeinateSwitchApp", dependencies: ["SwitchCore"]),
        .testTarget(name: "SwitchCoreTests", dependencies: ["SwitchCore"]),
        .testTarget(name: "CaffeinateSwitchAppTests", dependencies: ["CaffeinateSwitchApp"]),
    ]
)

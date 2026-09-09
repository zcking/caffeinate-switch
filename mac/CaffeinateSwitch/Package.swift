// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "CaffeinateSwitch",
    products: [
        .library(name: "SwitchCore", targets: ["SwitchCore"]),
    ],
    targets: [
        .target(name: "SwitchCore"),
        .testTarget(name: "SwitchCoreTests", dependencies: ["SwitchCore"]),
    ]
)

// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Hyper9",
    targets: [
        .target(
            name: "Turbo9Sim",
            path: "Hyper9/Turbo9Sim/Sources/Turbo9Sim"
        ),
        .executableTarget(
            name: "hyper9-cmd",
            dependencies: ["Turbo9Sim"],
            path: "hyper9-cmd"
        ),
    ]
)

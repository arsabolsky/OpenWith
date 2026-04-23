// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "OpenWith",
    platforms: [
        .macOS(.v12)
    ],
    products: [
        .executable(name: "OpenWith", targets: ["OpenWith"])
    ],
    dependencies: [],
    targets: [
        .executableTarget(
            name: "OpenWith",
            dependencies: [],
            path: "OpenWith/Sources",
            resources: [
                .process("../Resources/Info.plist")
            ]
        )
    ]
)

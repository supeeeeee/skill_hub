// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "SkillHubApp",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "SkillHubApp", targets: ["SkillHubApp"])
    ],
    dependencies: [
        .package(path: "../SkillHubCore")
    ],
    targets: [
        .executableTarget(
            name: "SkillHubApp",
            dependencies: [
                .product(name: "SkillHubCore", package: "SkillHubCore")
            ],
            path: "Sources/SkillHubApp"
        )
    ]
)

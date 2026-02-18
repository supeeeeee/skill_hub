// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "SkillHubCore",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .library(name: "SkillHubCore", targets: ["SkillHubCore"])
    ],
    targets: [
        .target(
            name: "SkillHubCore",
            resources: [
                .process("Resources")
            ]
        )
    ]
)

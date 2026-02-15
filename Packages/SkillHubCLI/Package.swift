// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "SkillHubCLI",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "skillhub", targets: ["SkillHubCLI"])
    ],
    dependencies: [
        .package(path: "../SkillHubCore")
    ],
    targets: [
        .executableTarget(
            name: "SkillHubCLI",
            dependencies: [
                .product(name: "SkillHubCore", package: "SkillHubCore")
            ]
        )
    ]
)

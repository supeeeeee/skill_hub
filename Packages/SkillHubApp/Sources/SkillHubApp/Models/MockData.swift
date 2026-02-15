import Foundation
import SkillHubCore

@MainActor
struct MockData {
    static let products: [Product] = [
        Product(id: "vscode", name: "VS Code", iconName: "chevron.left.forwardslash.chevron.right", description: "Visual Studio Code editor", status: .active, supportedModes: [.symlink, .copy]),
        Product(id: "cursor", name: "Cursor", iconName: "cursorarrow.rays", description: "AI-first code editor", status: .notInstalled, supportedModes: [.symlink, .copy]),
        Product(id: "claude", name: "Claude Desktop", iconName: "bubble.left.and.bubble.right.fill", description: "Anthropic's Claude Desktop App", status: .active, supportedModes: [.configPatch]),
        Product(id: "windsurf", name: "Windsurf", iconName: "wind", description: "Codeium's Windsurf IDE", status: .active, supportedModes: [.symlink])
    ]
    
    static let skills: [InstalledSkillRecord] = [
        InstalledSkillRecord(
            manifest: SkillManifest(
                id: "git-lfs",
                name: "Git LFS",
                version: "1.0.0",
                summary: "Git Large File Storage support",
                tags: ["git", "version-control"],
                adapters: [
                    AdapterConfig(productID: "vscode", installMode: .symlink),
                    AdapterConfig(productID: "cursor", installMode: .symlink)
                ]
            ),
            manifestPath: "/path/to/git-lfs/skill.json",
            installedProducts: ["vscode"],
            enabledProducts: ["vscode"],
            lastInstallModeByProduct: ["vscode": .symlink]
        ),
        InstalledSkillRecord(
            manifest: SkillManifest(
                id: "docker-helper",
                name: "Docker Helper",
                version: "2.1.0",
                summary: "Utilities for Docker management",
                tags: ["docker", "devops"],
                adapters: [
                    AdapterConfig(productID: "vscode", installMode: .copy),
                    AdapterConfig(productID: "windsurf", installMode: .symlink)
                ]
            ),
            manifestPath: "/path/to/docker-helper/skill.json",
            installedProducts: ["vscode", "windsurf"],
            enabledProducts: ["vscode", "windsurf"],
            lastInstallModeByProduct: ["vscode": .copy, "windsurf": .symlink]
        ),
         InstalledSkillRecord(
            manifest: SkillManifest(
                id: "swift-format",
                name: "Swift Format",
                version: "0.5.0",
                summary: "Formatting tools for Swift code",
                tags: ["swift", "formatter"],
                adapters: [
                    AdapterConfig(productID: "vscode", installMode: .symlink),
                    AdapterConfig(productID: "cursor", installMode: .symlink)
                ]
            ),
            manifestPath: "/path/to/swift-format/skill.json",
            installedProducts: [],
            enabledProducts: [],
            lastInstallModeByProduct: [:]
        )
    ]
    
    static let activityLogs: [ActivityLog] = [
        ActivityLog(timestamp: Date().addingTimeInterval(-300), message: "Installed Git LFS to VS Code", type: .success),
        ActivityLog(timestamp: Date().addingTimeInterval(-3600), message: "Failed to locate Cursor config", type: .error),
        ActivityLog(timestamp: Date().addingTimeInterval(-7200), message: "SkillHub started", type: .info)
    ]
}

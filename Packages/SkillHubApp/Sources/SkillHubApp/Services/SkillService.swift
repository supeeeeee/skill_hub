import Foundation
import SkillHubCore

final class SkillService {
    let skillStore: SkillStore
    let adapterRegistry: AdapterRegistry

    init(
        skillStore: SkillStore = JSONSkillStore(),
        adapterRegistry: AdapterRegistry = SkillService.makeDefaultAdapterRegistry()
    ) {
        self.skillStore = skillStore
        self.adapterRegistry = adapterRegistry
    }

    func loadSkills() throws -> [InstalledSkillRecord] {
        try skillStore.loadState().skills
    }

    func loadProducts() -> [Product] {
        let cfg = SkillHubConfig.load()

        return adapterRegistry.all().map { adapter in
            let detection = adapter.detect()
            let status: ProductStatus = detection.isDetected ? .active : .notInstalled

            return Product(
                id: adapter.id,
                name: adapter.name,
                iconName: iconName(for: adapter.id),
                description: detection.reason,
                status: status,
                health: .unknown,
                supportedModes: adapter.supportedInstallModes,
                customSkillsPath: cfg.productSkillsDirectoryOverrides[adapter.id]
            )
        }
    }

    func importSkill(at url: URL) throws -> SkillManifest {
        let data = try Data(contentsOf: url)
        let manifest = try JSONDecoder().decode(SkillManifest.self, from: data)
        try skillStore.addSkill(manifest: manifest, manifestPath: url.path)
        return manifest
    }

    func registerSkill(from source: String) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = [findSkillHubCLI(), "add", source]
        process.standardOutput = FileHandle.standardOutput
        process.standardError = FileHandle.standardError

        try process.run()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            throw SkillHubError.invalidManifest("Failed to register skill (exit code: \(process.terminationStatus))")
        }
    }

    func installSkill(
        manifest: SkillManifest,
        productID: String,
        mode: InstallMode,
        currentSkills: [InstalledSkillRecord]
    ) throws {
        guard let skillRecord = currentSkills.first(where: { $0.manifest.id == manifest.id }) else {
            throw SkillHubError.invalidManifest("Skill record not found for \(manifest.name)")
        }

        let sourcePath = URL(fileURLWithPath: skillRecord.manifestPath).deletingLastPathComponent()
        let destPath = SkillHubPaths.defaultSkillsDirectory().appendingPathComponent(manifest.id)

        if sourcePath.standardizedFileURL != destPath.standardizedFileURL {
            try FileSystemUtils.ensureDirectoryExists(at: SkillHubPaths.defaultSkillsDirectory())
            try FileSystemUtils.copyItem(from: sourcePath, to: destPath)
        }

        let stagedManifestPath = destPath.appendingPathComponent("skill.json").path
        try skillStore.addSkill(manifest: manifest, manifestPath: stagedManifestPath)

        let adapter = try adapterRegistry.adapter(for: productID)
        let finalMode = try adapter.install(skill: manifest, mode: mode)
        try skillStore.markDeployed(skillID: manifest.id, productID: productID, deployMode: finalMode)

        try adapter.enable(skillID: manifest.id, mode: finalMode)
        try skillStore.setEnabled(skillID: manifest.id, productID: productID, enabled: true)
    }

    func uninstallSkill(manifest: SkillManifest, productID: String) throws {
        let adapter = try adapterRegistry.adapter(for: productID)
        try adapter.disable(skillID: manifest.id)
        try skillStore.markUninstalled(skillID: manifest.id, productID: productID)
    }

    func setSkillEnabled(
        manifest: SkillManifest,
        productID: String,
        enabled: Bool,
        currentSkills: [InstalledSkillRecord]
    ) throws {
        let adapter = try adapterRegistry.adapter(for: productID)

        guard let skillRecord = currentSkills.first(where: { $0.manifest.id == manifest.id }),
              let mode = skillRecord.lastDeployModeByProduct[productID] else {
            throw SkillHubError.invalidManifest("Skill \(manifest.name) is not deployed for \(productID)")
        }

        if enabled {
            try adapter.enable(skillID: manifest.id, mode: mode)
        } else {
            try adapter.disable(skillID: manifest.id)
        }

        try skillStore.setEnabled(skillID: manifest.id, productID: productID, enabled: enabled)
    }

    func acquireSkill(manifest: SkillManifest, fromProduct productID: String, skillsPath: String) throws {
        let rootURL = URL(fileURLWithPath: skillsPath)
        let fm = FileManager.default

        var sourceFolder: URL?
        if let contents = try? fm.contentsOfDirectory(at: rootURL, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]) {
            for folderURL in contents {
                let candidates = [
                    folderURL.appendingPathComponent("skill.json"),
                    folderURL.appendingPathComponent("manifest.json")
                ]

                for fileURL in candidates {
                    if let data = try? Data(contentsOf: fileURL),
                       let found = try? JSONDecoder().decode(SkillManifest.self, from: data),
                       found.id == manifest.id {
                        sourceFolder = folderURL
                        break
                    }
                }

                if sourceFolder != nil {
                    break
                }
            }
        }

        guard let source = sourceFolder else {
            throw SkillHubError.invalidManifest("Could not find source folder for skill \(manifest.id) in \(skillsPath)")
        }

        let hubSkillsDir = SkillHubPaths.defaultSkillsDirectory()
        let destination = hubSkillsDir.appendingPathComponent(manifest.id)

        try FileSystemUtils.ensureDirectoryExists(at: hubSkillsDir)
        try FileSystemUtils.copyItem(from: source, to: destination)
        _ = try FileSystemUtils.backupIfExists(at: source, productID: productID, skillID: manifest.id)
        try FileSystemUtils.createSymlink(from: destination, to: source)

        let destManifestPath: String
        if fm.fileExists(atPath: destination.appendingPathComponent("skill.json").path) {
            destManifestPath = destination.appendingPathComponent("skill.json").path
        } else {
            destManifestPath = destination.appendingPathComponent("manifest.json").path
        }

        try skillStore.addSkill(manifest: manifest, manifestPath: destManifestPath)
        try skillStore.markDeployed(skillID: manifest.id, productID: productID, deployMode: .symlink)
        try skillStore.setEnabled(skillID: manifest.id, productID: productID, enabled: true)
    }

    func checkForUpdates(productID: String, skills: [InstalledSkillRecord]) throws -> String? {
        let skillsToCheck = skills.filter { $0.deployedProducts.contains(productID) }
        guard let skill = skillsToCheck.first else {
            return nil
        }

        try skillStore.setHasUpdate(skillID: skill.manifest.id, hasUpdate: true)
        return skill.manifest.name
    }

    private func iconName(for id: String) -> String {
        switch id {
        case "vscode": return "chevron.left.forwardslash.chevron.right"
        case "cursor": return "cursorarrow.rays"
        case "claude-code": return "bubble.left.and.bubble.right.fill"
        case "windsurf": return "wind"
        case "openclaw": return "shippingbox"
        case "codex": return "brain"
        case "opencode": return "terminal"
        default: return "questionmark.circle"
        }
    }

    private func findSkillHubCLI() -> String {
        let paths = [
            "/usr/local/bin/skillhub",
            "/opt/homebrew/bin/skillhub",
            "~/.local/bin/skillhub",
            "./.build/debug/skillhub"
        ]

        for path in paths {
            let expanded = (path as NSString).expandingTildeInPath
            if FileManager.default.fileExists(atPath: expanded) {
                return expanded
            }
        }

        return "skillhub"
    }

    private static func makeDefaultAdapterRegistry() -> AdapterRegistry {
        let adapters: [ProductAdapter] = [
            OpenClawAdapter(),
            CodexAdapter(),
            OpenCodeAdapter(),
            ClaudeCodeAdapter(),
            CursorAdapter()
        ]
        return AdapterRegistry(adapters: adapters)
    }
}

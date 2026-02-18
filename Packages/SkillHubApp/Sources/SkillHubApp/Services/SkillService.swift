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
        let state = (try? skillStore.loadState()) ?? SkillHubState()

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
                customSkillsPath: cfg.productSkillsDirectoryOverrides[adapter.id],
                customConfigPath: state.productConfigFilePathOverrides[adapter.id]
            )
        }
    }

    func setProductConfigPath(productID: String, rawPath: String) throws {
        let trimmed = rawPath.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty && !trimmed.hasPrefix("/") {
            throw SkillHubError.invalidManifest("Config path must be an absolute path")
        }

        try skillStore.setProductConfigPath(productID: productID, configPath: trimmed.isEmpty ? nil : trimmed)
    }

    func importSkill(at url: URL) throws -> SkillManifest {
        let data = try Data(contentsOf: url)
        let manifest = try JSONDecoder().decode(SkillManifest.self, from: data)
        try skillStore.upsertSkill(manifest: manifest, manifestPath: url.path)
        return manifest
    }

    func registerSkill(from source: String) throws {
        try runSkillHub(arguments: ["add", source], action: "register skill")
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
        try skillStore.upsertSkill(manifest: manifest, manifestPath: stagedManifestPath)

        let adapter = try adapterRegistry.adapter(for: productID)
        let finalMode = try adapter.install(skill: manifest, mode: mode)
        try skillStore.markInstalled(skillID: manifest.id, productID: productID, installMode: finalMode)

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
              let mode = skillRecord.lastInstallModeByProduct[productID] else {
            throw SkillHubError.invalidManifest("Skill \(manifest.name) is not installed for \(productID)")
        }

        if enabled {
            try adapter.enable(skillID: manifest.id, mode: mode)
        } else {
            try adapter.disable(skillID: manifest.id)
        }

        try skillStore.setEnabled(skillID: manifest.id, productID: productID, enabled: enabled)
    }

    func acquireSkill(manifest: SkillManifest, fromProduct productID: String, skillsPath: String) throws {
        let rootURL = URL(fileURLWithPath: expandedPath(skillsPath)).standardizedFileURL
        let fm = Foundation.FileManager()

        var isRootDirectory: ObjCBool = false
        guard fm.fileExists(atPath: rootURL.path, isDirectory: &isRootDirectory), isRootDirectory.boolValue else {
            throw SkillHubError.invalidManifest("Skills directory does not exist or is not a directory: \(rootURL.path)")
        }

        guard fm.isReadableFile(atPath: rootURL.path) else {
            throw SkillHubError.invalidManifest("Skills directory is not readable: \(rootURL.path)")
        }

        var sourceFolder: URL?
        var manifestFile: URL?

        if let contents = try? fm.contentsOfDirectory(
            at: rootURL,
            includingPropertiesForKeys: [],
            options: Foundation.FileManager.DirectoryEnumerationOptions.skipsHiddenFiles
        ) {
            for folderURL in contents {
                var isDirectory: ObjCBool = false
                guard fm.fileExists(atPath: folderURL.path, isDirectory: &isDirectory), isDirectory.boolValue else {
                    continue
                }

                let candidates = [
                    folderURL.appendingPathComponent("skill.json"),
                    folderURL.appendingPathComponent("manifest.json")
                ]

                for fileURL in candidates {
                    if let data = try? Data(contentsOf: fileURL),
                       let found = try? JSONDecoder().decode(SkillManifest.self, from: data),
                       found.id == manifest.id {
                        sourceFolder = folderURL
                        manifestFile = fileURL
                        break
                    }
                }

                if sourceFolder != nil {
                    break
                }
            }
        }

        guard let source = sourceFolder, let manifestPath = manifestFile else {
            throw SkillHubError.invalidManifest("Could not find source folder for skill \(manifest.id) in \(skillsPath)")
        }

        try ensureSkillHubDirectoryAccess()

        // Use CLI to stage the skill (robust copy and store update)
        let normalizedManifestPath = normalizePathForCLI(manifestPath)
        try runSkillHub(arguments: ["stage", normalizedManifestPath], action: "stage skill")

        let hubSkillsDir = SkillHubPaths.defaultSkillsDirectory()
        let destination = hubSkillsDir.appendingPathComponent(manifest.id)
        guard fm.fileExists(atPath: destination.path) else {
            throw SkillHubError.invalidManifest("Staged skill directory missing after stage command: \(destination.path)")
        }

        // Perform the takeover (backup original, replace with symlink)
        _ = try FileSystemUtils.backupIfExists(at: source, productID: productID, skillID: manifest.id)
        try FileSystemUtils.createSymlink(from: destination, to: source)

        // Update installation status
        try skillStore.markInstalled(skillID: manifest.id, productID: productID, installMode: .symlink)
        try skillStore.setEnabled(skillID: manifest.id, productID: productID, enabled: true)
    }

    func checkForUpdates(productID: String, skills: [InstalledSkillRecord]) throws -> String? {
        let skillsToCheck = skills.filter { $0.installedProducts.contains(productID) }
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

    private func runSkillHub(arguments: [String], action: String) throws {
        let cliPath = try findSkillHubCLI()
        let process = Process()
        let outputPipe = Pipe()
        let errorPipe = Pipe()

        process.executableURL = URL(fileURLWithPath: cliPath)
        process.arguments = arguments
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        do {
            try process.run()
        } catch {
            throw SkillHubError.invalidManifest(
                "Failed to \(action): unable to launch skillhub at \(cliPath). \(error.localizedDescription)"
            )
        }

        process.waitUntilExit()

        let stdoutOutput = readPipeOutput(outputPipe)
        let stderrOutput = readPipeOutput(errorPipe)

        guard process.terminationStatus == 0 else {
            var details: [String] = []
            if !stderrOutput.isEmpty {
                details.append("stderr: \(stderrOutput)")
            }
            if !stdoutOutput.isEmpty {
                details.append("stdout: \(stdoutOutput)")
            }
            let detailSuffix = details.isEmpty ? "" : ". " + details.joined(separator: " | ")

            throw SkillHubError.invalidManifest(
                "Failed to \(action) (exit code: \(process.terminationStatus), cli: \(cliPath), args: \(arguments))\(detailSuffix)"
            )
        }
    }

    private func readPipeOutput(_ pipe: Pipe) -> String {
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        return String(data: data, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }

    private func ensureSkillHubDirectoryAccess() throws {
        let fm = Foundation.FileManager()
        let requiredDirectories = [
            SkillHubPaths.defaultStateDirectory(),
            SkillHubPaths.defaultSkillsDirectory(),
            SkillHubPaths.defaultBackupsDirectory()
        ]

        for directory in requiredDirectories {
            do {
                try FileSystemUtils.ensureDirectoryExists(at: directory)
            } catch {
                throw SkillHubError.invalidManifest(
                    "Cannot create SkillHub directory at \(directory.path): \(error.localizedDescription)"
                )
            }

            var isDirectory: ObjCBool = false
            guard fm.fileExists(atPath: directory.path, isDirectory: &isDirectory), isDirectory.boolValue else {
                throw SkillHubError.invalidManifest("SkillHub path is not a directory: \(directory.path)")
            }

            guard fm.isReadableFile(atPath: directory.path), fm.isWritableFile(atPath: directory.path) else {
                throw SkillHubError.invalidManifest(
                    "Insufficient permissions for SkillHub directory: \(directory.path). Please grant read/write access."
                )
            }
        }
    }

    private func normalizePathForCLI(_ url: URL) -> String {
        url.standardizedFileURL.resolvingSymlinksInPath().path
    }

    private func expandedPath(_ path: String) -> String {
        (path as NSString).expandingTildeInPath
    }

    private func findSkillHubCLI() throws -> String {
        let fm = Foundation.FileManager()
        let cwd = URL(fileURLWithPath: ".").standardizedFileURL.path
        var paths = [
            "/usr/local/bin/skillhub",
            "/opt/homebrew/bin/skillhub",
            "~/.local/bin/skillhub",
            "skillhub"
        ]

        if let executableURL = Bundle.main.executableURL {
            let executableDir = executableURL.deletingLastPathComponent().path
            paths.append("\(executableDir)/skillhub")
            paths.append("\(executableDir)/../skillhub")
        }

        paths.append(contentsOf: [
            "\(cwd)/.build/debug/skillhub",
            "\(cwd)/.build/arm64-apple-macosx/debug/skillhub",
            "\(cwd)/Packages/SkillHubCLI/.build/debug/skillhub",
            "\(cwd)/Packages/SkillHubCLI/.build/arm64-apple-macosx/debug/skillhub"
        ])

        for path in paths {
            let expanded = (path as NSString).expandingTildeInPath
            if expanded == "skillhub" {
                if let resolved = resolveFromPATH(binary: expanded) {
                    return resolved
                }
                continue
            }

            if fm.isExecutableFile(atPath: expanded) {
                return expanded
            }
        }

        throw SkillHubError.invalidManifest(
            "Could not locate executable 'skillhub'. Build SkillHubCLI first or add it to PATH."
        )
    }

    private func resolveFromPATH(binary: String) -> String? {
        let fm = Foundation.FileManager()
        let pathVariable = ProcessInfo.processInfo.environment["PATH"] ?? ""
        let components = pathVariable.split(separator: ":").map(String.init)

        for component in components where !component.isEmpty {
            let candidate = URL(fileURLWithPath: component).appendingPathComponent(binary).path
            if fm.isExecutableFile(atPath: candidate) {
                return candidate
            }
        }

        return nil
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

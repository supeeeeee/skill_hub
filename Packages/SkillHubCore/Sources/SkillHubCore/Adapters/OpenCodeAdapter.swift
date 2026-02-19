import Foundation

public struct OpenCodeAdapter: ProductAdapter {
    public let id = "opencode"
    public let name = "OpenCode"
    public let supportedInstallModes: [InstallMode] = [.copy]

    public init() {}

    // MARK: - Paths

    /// SkillHub's skill store (where skills are staged)
    private var skillStoreRoot: URL {
        SkillHubPaths.defaultSkillsDirectory()
    }

    /// OpenCode configuration root: ~/.config/opencode/
    private var openCodeConfigRoot: URL {
        let home = FileManager.default.homeDirectoryForCurrentUser
        return home.appendingPathComponent(".config/opencode", isDirectory: true)
    }

    /// OpenCode skills drop-in directory: ~/.config/opencode/skills/
    /// This is where SkillHub will place managed skills for OpenCode to discover.
    private var openCodeSkillsDirectory: URL {
        if let override = SkillHubConfig.overrideSkillsDirectory(for: id) { return override }
        return openCodeConfigRoot.appendingPathComponent("skills", isDirectory: true)
    }

    public func skillsDirectory() -> URL {
        openCodeSkillsDirectory
    }

    /// OpenCode main config: ~/.config/opencode/config.json
    private var openCodeConfigJSON: URL {
        if let override = ProductPathOverrides.configFilePathOverride(for: id) { return override }
        return openCodeConfigRoot.appendingPathComponent("config.json", isDirectory: false)
    }

    public func configFilePath() -> URL? {
        openCodeConfigJSON
    }

    /// OpenCode plugins config: ~/.config/opencode/opencode.json
    /// Used for configPatch mode to register skills as plugins.
    private var openCodePluginsJSON: URL {
        openCodeConfigRoot.appendingPathComponent("opencode.json", isDirectory: false)
    }

    // MARK: - ProductAdapter

    public func detect() -> ProductDetectionResult {
        if let path = ProductDetectionUtils.firstExistingPath(in: [
            openCodeConfigRoot.path,
            openCodeConfigJSON.path,
            openCodeSkillsDirectory.path
        ]) {
            return ProductDetectionResult(
                isDetected: true,
                reason: "Detected filesystem footprint at \(path)"
            )
        }

        if let executable = ProductDetectionUtils.firstExecutablePath(named: ["opencode"]) {
            return ProductDetectionResult(
                isDetected: true,
                reason: "Detected executable at \(executable)"
            )
        }

        return ProductDetectionResult(
            isDetected: false,
            reason: "No config footprint at \(openCodeConfigRoot.path) and no 'opencode' executable found"
        )
    }

    /// Install prepares the environment for the skill.
    /// - For configPatch: registers skill in config.json
    /// - For symlink/copy: ensures directories exist (actual linking happens in enable)
    public func install(skill: SkillManifest, mode: InstallMode) throws -> InstallMode {
        let resolvedMode = try resolveInstallMode(mode)

        let stagedSkillPath = skillStoreRoot.appendingPathComponent(skill.id, isDirectory: true)
        guard FileManager.default.fileExists(atPath: stagedSkillPath.path) else {
            throw SkillHubError.invalidManifest("Skill not staged in \(stagedSkillPath.path)")
        }

        // Ensure required directories exist
        try FileSystemUtils.ensureDirectoryExists(at: openCodeConfigRoot)
        try FileSystemUtils.ensureDirectoryExists(at: openCodeSkillsDirectory)

        // For configPatch mode, patch the config to register the skill
        if resolvedMode == .configPatch {
            let skillPath = openCodeSkillsDirectory.appendingPathComponent(skill.id, isDirectory: true).path
            try patchOpenCodeConfig(skillID: skill.id, skillPath: skillPath)
        }

        return resolvedMode
    }

    /// Enable actually places the skill files in OpenCode's skills directory.
    /// - symlink: creates symbolic link
    /// - copy: copies files
    /// - configPatch: symlink + config registration
    public func enable(skillID: String, mode: InstallMode) throws {
        let source = skillStoreRoot.appendingPathComponent(skillID, isDirectory: true)
        guard FileManager.default.fileExists(atPath: source.path) else {
            throw SkillHubError.invalidManifest("Skill not staged in \(source.path)")
        }

        // Ensure directories exist
        try FileSystemUtils.ensureDirectoryExists(at: openCodeConfigRoot)
        try FileSystemUtils.ensureDirectoryExists(at: openCodeSkillsDirectory)

        let destination = openCodeSkillsDirectory.appendingPathComponent(skillID, isDirectory: true)
        let resolvedMode = try resolveInstallMode(mode)

        // Backup existing if present
        _ = try FileSystemUtils.backupIfExists(at: destination, productID: id, skillID: skillID)

        switch resolvedMode {
        case .symlink:
            try FileSystemUtils.createSymlink(from: source, to: destination)

        case .copy:
            try FileSystemUtils.copyItem(from: source, to: destination)

        case .configPatch:
            // For configPatch: create symlink first, then patch config
            try FileSystemUtils.createSymlink(from: source, to: destination)
            try patchOpenCodeConfig(skillID: skillID, skillPath: destination.path)

        case .auto:
            throw SkillHubError.unsupportedInstallMode("auto mode requires resolution before enable")
        default:
            throw SkillHubError.unsupportedInstallMode("unknown install mode: \(resolvedMode.rawValue)")
        }
    }

    /// Disable removes the skill from OpenCode's skills directory and unregisters from config.
    public func disable(skillID: String) throws {
        let destination = openCodeSkillsDirectory.appendingPathComponent(skillID, isDirectory: true)

        // Remove skill files/directory
        if FileManager.default.fileExists(atPath: destination.path) {
            try FileManager.default.removeItem(at: destination)
        }

        // Unpatch config if present
        try unpatchOpenCodeConfig(skillID: skillID)
    }

    /// Status reports the current state of the skill for this product.
    public func status(skillID: String) -> ProductSkillStatus {
        let staged = skillStoreRoot.appendingPathComponent(skillID, isDirectory: true)
        let enabled = openCodeSkillsDirectory.appendingPathComponent(skillID, isDirectory: true)

        let isInstalled = FileManager.default.fileExists(atPath: staged.path)
        let existsAtDestination = FileManager.default.fileExists(atPath: enabled.path)

        // Check if it's a symlink
        var isSymlink = false
        if existsAtDestination {
            isSymlink = ((try? FileManager.default.destinationOfSymbolicLink(atPath: enabled.path)) != nil)
        }

        // Check if registered in config
        let isEnabledViaConfig = isSkillRegisteredInConfig(skillID: skillID)

        // Skill is enabled if files exist OR registered in config
        let isEnabled = existsAtDestination || isEnabledViaConfig

        let detail: String
        if isSymlink {
            detail = "Enabled via symlink at \(enabled.path)"
        } else if existsAtDestination {
            detail = "Enabled via copied files at \(enabled.path)"
        } else if isEnabledViaConfig {
            detail = "Registered in OpenCode config (skillhub.skills)"
        } else if isInstalled {
            return ProductSkillStatus(isInstalled: true, isEnabled: false, detail: "Installed but not enabled")
        } else {
            detail = "Not installed"
        }

        return ProductSkillStatus(isInstalled: isInstalled, isEnabled: isEnabled, detail: detail)
    }

    // MARK: - configPatch (non-invasive)

    /// Patch `~/.config/opencode/config.json` by adding to `skillhub.skills`.
    /// This is intentionally namespaced to avoid depending on OpenCode's upstream config schema.
    private func patchOpenCodeConfig(skillID: String, skillPath: String) throws {
        try ConfigPatchValidation.validateSkillPath(skillPath, productID: id)
        var root = try ConfigPatchValidation.loadRootObjectIfExists(at: openCodeConfigJSON, productID: id)
        var (skillhub, skills) = try ConfigPatchValidation.extractSkillhubSection(from: root, productID: id)

        // Add skill path if not already present
        if !skills.contains(skillPath) {
            skills.append(skillPath)
        }

        skillhub["skills"] = skills
        root["skillhub"] = skillhub

        // Write updated config
        let data = try JSONSerialization.data(withJSONObject: root, options: [.prettyPrinted, .sortedKeys])
        try data.write(to: openCodeConfigJSON)
    }

    /// Remove skill from config.json
    private func unpatchOpenCodeConfig(skillID: String) throws {
        guard FileManager.default.fileExists(atPath: openCodeConfigJSON.path),
              var root = try? ConfigPatchValidation.loadRootObjectIfExists(at: openCodeConfigJSON, productID: id)
        else {
            return
        }

        var skillhub = root["skillhub"] as? [String: Any] ?? [:]
        var skills = skillhub["skills"] as? [String] ?? []

        // Remove entries containing the skillID
        skills.removeAll { $0.contains("/\(skillID)") || $0.hasSuffix("/\(skillID)") }

        skillhub["skills"] = skills
        root["skillhub"] = skillhub

        let newData = try JSONSerialization.data(withJSONObject: root, options: [.prettyPrinted, .sortedKeys])
        try newData.write(to: openCodeConfigJSON)
    }

    /// Check if skill is registered in config
    private func isSkillRegisteredInConfig(skillID: String) -> Bool {
        guard FileManager.default.fileExists(atPath: openCodeConfigJSON.path),
              let data = try? Data(contentsOf: openCodeConfigJSON),
              let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let skillhub = root["skillhub"] as? [String: Any],
              let skills = skillhub["skills"] as? [String]
        else {
            return false
        }

        return skills.contains { $0.contains(skillID) }
    }
}

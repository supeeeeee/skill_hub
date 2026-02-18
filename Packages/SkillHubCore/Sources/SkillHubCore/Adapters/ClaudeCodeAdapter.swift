import Foundation

public struct ClaudeCodeAdapter: ProductAdapter {
    public let id = "claude-code"
    public let name = "Claude Code"
    /// Claude Code is expected to read skills from a local directory under `~/.claude/skills`.
    /// To avoid potential symlink restrictions in downstream tooling, we default to `copy`.
    public let supportedInstallModes: [InstallMode] = [.auto, .copy, .configPatch]

    public init() {}

    // MARK: - Paths

    /// SkillHub's skill store (where skills are staged)
    private var skillStoreRoot: URL {
        SkillHubPaths.defaultSkillsDirectory()
    }

    /// Claude Code configuration root: ~/.claude/
    private var claudeCodeConfigRoot: URL {
        let home = FileManager.default.homeDirectoryForCurrentUser
        return home.appendingPathComponent(".claude", isDirectory: true)
    }

    /// Claude Code skills directory: ~/.claude/skills/
    private var claudeCodeSkillsDirectory: URL {
        if let override = SkillHubConfig.overrideSkillsDirectory(for: id) { return override }
        return claudeCodeConfigRoot.appendingPathComponent("skills", isDirectory: true)
    }

    /// Claude Code settings: ~/.claude/settings.json
    private var claudeCodeSettingsJSON: URL {
        claudeCodeConfigRoot.appendingPathComponent("settings.json", isDirectory: false)
    }

    /// Claude Code configuration: ~/.claude.json (alternative config location)
    private var claudeCodeConfigJSON: URL {
        claudeCodeConfigRoot.appendingPathComponent(".claude.json", isDirectory: false)
    }

    // MARK: - ProductAdapter

    public func detect() -> ProductDetectionResult {
        let fm = FileManager.default
        // Check if Claude Code config directory exists
        if fm.fileExists(atPath: claudeCodeConfigRoot.path) {
            return ProductDetectionResult(
                isDetected: true,
                reason: "Detected at \(claudeCodeConfigRoot.path)"
            )
        }
        return ProductDetectionResult(
            isDetected: false,
            reason: "Missing \(claudeCodeConfigRoot.path)"
        )
    }

    /// Install prepares the environment for the skill.
    public func install(skill: SkillManifest, mode: InstallMode) throws -> InstallMode {
        let resolvedMode = try resolveInstallMode(mode)

        let stagedSkillPath = skillStoreRoot.appendingPathComponent(skill.id, isDirectory: true)
        guard FileManager.default.fileExists(atPath: stagedSkillPath.path) else {
            throw SkillHubError.invalidManifest("Skill not staged in \(stagedSkillPath.path)")
        }

        // Ensure config root and skills directory exist
        try FileSystemUtils.ensureDirectoryExists(at: claudeCodeConfigRoot)
        try FileSystemUtils.ensureDirectoryExists(at: claudeCodeSkillsDirectory)

        // install() is intentionally non-invasive: only validate and prepare directories.
        // Any filesystem placement and config patching is applied during enable().
        return resolvedMode
    }

    /// Enable actually places the skill files in Claude Code's skills directory.
    public func enable(skillID: String, mode: InstallMode) throws {
        let source = skillStoreRoot.appendingPathComponent(skillID, isDirectory: true)
        guard FileManager.default.fileExists(atPath: source.path) else {
            throw SkillHubError.invalidManifest("Skill not staged in \(source.path)")
        }

        // Ensure directories exist
        try FileSystemUtils.ensureDirectoryExists(at: claudeCodeConfigRoot)
        try FileSystemUtils.ensureDirectoryExists(at: claudeCodeSkillsDirectory)

        let destination = claudeCodeSkillsDirectory.appendingPathComponent(skillID, isDirectory: true)
        let resolvedMode = try resolveInstallMode(mode)

        // Backup existing if present
        _ = try FileSystemUtils.backupIfExists(at: destination, productID: id, skillID: skillID)

        switch resolvedMode {
        case .copy:
            try FileSystemUtils.copyItem(from: source, to: destination)

        case .configPatch:
            // Place the skill payload and then register it in settings.
            // Use a physical copy for maximum compatibility.
            try FileSystemUtils.copyItem(from: source, to: destination)
            try patchClaudeCodeSettings(skillID: skillID, skillPath: destination.path)

        case .symlink:
            throw SkillHubError.unsupportedInstallMode("symlink for \(id)")

        case .auto:
            throw SkillHubError.unsupportedInstallMode("auto mode requires resolution before enable")
        default:
            fatalError("Unknown install mode: \(resolvedMode)")
        }
    }

    /// Disable removes the skill from Claude Code's skills directory and unregisters from settings.
    public func disable(skillID: String) throws {
        let destination = claudeCodeSkillsDirectory.appendingPathComponent(skillID, isDirectory: true)

        // Remove skill files/directory
        if FileManager.default.fileExists(atPath: destination.path) {
            try FileManager.default.removeItem(at: destination)
        }

        // Unpatch settings if present
        try unpatchClaudeCodeSettings(skillID: skillID)
    }

    /// Status reports the current state of the skill for this product.
    public func status(skillID: String) -> ProductSkillStatus {
        let staged = skillStoreRoot.appendingPathComponent(skillID, isDirectory: true)
        let enabled = claudeCodeSkillsDirectory.appendingPathComponent(skillID, isDirectory: true)

        let isInstalled = FileManager.default.fileExists(atPath: staged.path)
        let existsAtDestination = FileManager.default.fileExists(atPath: enabled.path)

        // Check if it's a symlink
        var isSymlink = false
        if existsAtDestination {
            isSymlink = ((try? FileManager.default.destinationOfSymbolicLink(atPath: enabled.path)) != nil)
        }

        // Check if registered in settings
        let isEnabledViaConfig = isSkillRegisteredInSettings(skillID: skillID)

        // Skill is enabled if files exist OR registered in config
        let isEnabled = existsAtDestination || isEnabledViaConfig

        let detail: String
        if isSymlink {
            detail = "Enabled via symlink at \(enabled.path)"
        } else if existsAtDestination {
            detail = "Enabled via copied files at \(enabled.path)"
        } else if isEnabledViaConfig {
            detail = "Registered in Claude Code settings (skillhub.skills)"
        } else if isInstalled {
            return ProductSkillStatus(isInstalled: true, isEnabled: false, detail: "Installed but not enabled")
        } else {
            detail = "Not installed"
        }

        return ProductSkillStatus(isInstalled: isInstalled, isEnabled: isEnabled, detail: detail)
    }

    // MARK: - configPatch

    /// Patch Claude Code's settings.json by adding to `skillhub.skills`.
    private func patchClaudeCodeSettings(skillID: String, skillPath: String) throws {
        var root: [String: Any] = [:]

        // Load existing settings if present
        if FileManager.default.fileExists(atPath: claudeCodeSettingsJSON.path),
           let data = try? Data(contentsOf: claudeCodeSettingsJSON),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        {
            root = json
        }

        // Add skillhub namespace with skills array
        var skillhub = root["skillhub"] as? [String: Any] ?? [:]
        var skills = skillhub["skills"] as? [String] ?? []

        // Add skill path if not already present
        if !skills.contains(skillPath) {
            skills.append(skillPath)
        }

        skillhub["skills"] = skills
        root["skillhub"] = skillhub

        // Write updated settings
        let data = try JSONSerialization.data(withJSONObject: root, options: [.prettyPrinted, .sortedKeys])
        try data.write(to: claudeCodeSettingsJSON)
    }

    /// Remove skill from settings.json
    private func unpatchClaudeCodeSettings(skillID: String) throws {
        guard FileManager.default.fileExists(atPath: claudeCodeSettingsJSON.path),
              let data = try? Data(contentsOf: claudeCodeSettingsJSON),
              var root = (try? JSONSerialization.jsonObject(with: data) as? [String: Any])
        else {
            return
        }

        var skillhub = root["skillhub"] as? [String: Any] ?? [:]
        var skills = skillhub["skills"] as? [String] ?? []

        // Remove entries containing the skillID
        skills.removeAll { $0.contains(skillID) }

        skillhub["skills"] = skills
        root["skillhub"] = skillhub

        let newData = try JSONSerialization.data(withJSONObject: root, options: [.prettyPrinted, .sortedKeys])
        try newData.write(to: claudeCodeSettingsJSON)
    }

    /// Check if skill is registered in settings
    private func isSkillRegisteredInSettings(skillID: String) -> Bool {
        guard FileManager.default.fileExists(atPath: claudeCodeSettingsJSON.path),
              let data = try? Data(contentsOf: claudeCodeSettingsJSON),
              let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let skillhub = root["skillhub"] as? [String: Any],
              let skills = skillhub["skills"] as? [String]
        else {
            return false
        }

        return skills.contains { $0.contains(skillID) }
    }
}

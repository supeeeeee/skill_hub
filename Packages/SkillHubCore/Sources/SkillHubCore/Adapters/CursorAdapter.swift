import Foundation

public struct CursorAdapter: ProductAdapter {
    public let id = "cursor"
    public let name = "Cursor"
    public let supportedInstallModes: [InstallMode] = [.copy]

    public init() {}

    // MARK: - Paths

    /// SkillHub's skill store (where skills are staged)
    private var skillStoreRoot: URL {
        SkillHubPaths.defaultSkillsDirectory()
    }

    /// Cursor Application Support directory: ~/Library/Application Support/Cursor/
    private var cursorAppSupportRoot: URL {
        let home = FileManager.default.homeDirectoryForCurrentUser
        return home.appendingPathComponent("Library/Application Support/Cursor", isDirectory: true)
    }

    /// Cursor lightweight config directory: ~/.cursor/
    private var cursorDotRoot: URL {
        let home = FileManager.default.homeDirectoryForCurrentUser
        return home.appendingPathComponent(".cursor", isDirectory: true)
    }

    /// Cursor settings JSON: ~/Library/Application Support/Cursor/User/settings.json
    private var cursorSettingsJSON: URL {
        if let override = ProductPathOverrides.configFilePathOverride(for: id) { return override }
        return cursorAppSupportRoot.appendingPathComponent("User/settings.json", isDirectory: false)
    }

    /// Skills directory under ~/.cursor/skills/ (legacy / lightweight installs)
    private var cursorDotSkillsDirectory: URL {
        cursorDotRoot.appendingPathComponent("skills", isDirectory: true)
    }

    /// Skills directory under Application Support (preferred when Cursor is installed normally)
    private var cursorAppSupportSkillsDirectory: URL {
        cursorAppSupportRoot.appendingPathComponent("skills", isDirectory: true)
    }

    /// Resolve the on-disk target directory for managed skills.
    /// If Cursor is installed (Application Support directory exists), use that.
    /// Otherwise, fall back to ~/.cursor.
    private func resolvedCursorSkillsDirectory() -> URL {
        if let override = SkillHubConfig.overrideSkillsDirectory(for: id) { return override }
        let fm = FileManager.default
        if fm.fileExists(atPath: cursorAppSupportRoot.path) {
            return cursorAppSupportSkillsDirectory
        }
        return cursorDotSkillsDirectory
    }

    public func skillsDirectory() -> URL {
        resolvedCursorSkillsDirectory()
    }

    public func configFilePath() -> URL? {
        cursorSettingsJSON
    }

    // MARK: - ProductAdapter

    public func detect() -> ProductDetectionResult {
        let fm = FileManager.default
        // Check both possible locations
        if fm.fileExists(atPath: cursorAppSupportRoot.path) || fm.fileExists(atPath: cursorDotRoot.path) {
            return ProductDetectionResult(
                isDetected: true,
                reason: "Detected Cursor at \(cursorAppSupportRoot.path) or \(cursorDotRoot.path)"
            )
        }
        return ProductDetectionResult(
            isDetected: false,
            reason: "Missing \(cursorAppSupportRoot.path) and \(cursorDotRoot.path)"
        )
    }

    /// Install prepares the environment for the skill.
    public func install(skill: SkillManifest, mode: InstallMode) throws -> InstallMode {
        let resolvedMode = try resolveInstallMode(mode)

        let stagedSkillPath = skillStoreRoot.appendingPathComponent(skill.id, isDirectory: true)
        guard FileManager.default.fileExists(atPath: stagedSkillPath.path) else {
            throw SkillHubError.invalidManifest("Skill not staged in \(stagedSkillPath.path)")
        }

        let skillsDirectory = skillsDirectory()
        // Ensure skills directory exists
        try FileSystemUtils.ensureDirectoryExists(at: skillsDirectory)

        // install() is intentionally non-invasive: only validate and prepare directories.
        // Any filesystem placement and config patching is applied during enable().
        if resolvedMode == .configPatch {
            try FileSystemUtils.ensureDirectoryExists(at: cursorSettingsJSON.deletingLastPathComponent())
        }

        return resolvedMode
    }

    /// Enable actually places the skill files in Cursor's skills directory.
    public func enable(skillID: String, mode: InstallMode) throws {
        let source = skillStoreRoot.appendingPathComponent(skillID, isDirectory: true)
        guard FileManager.default.fileExists(atPath: source.path) else {
            throw SkillHubError.invalidManifest("Skill not staged in \(source.path)")
        }

        let skillsDirectory = skillsDirectory()

        // Ensure directories exist
        try FileSystemUtils.ensureDirectoryExists(at: skillsDirectory)

        let destination = skillsDirectory.appendingPathComponent(skillID, isDirectory: true)
        let resolvedMode = try resolveInstallMode(mode)

        // Backup existing if present
        _ = try FileSystemUtils.backupIfExists(at: destination, productID: id, skillID: skillID)

        switch resolvedMode {
        case .symlink:
            try FileSystemUtils.createSymlink(from: source, to: destination)

        case .copy:
            try FileSystemUtils.copyItem(from: source, to: destination)

        case .configPatch:
            // Create symlink and patch settings
            try FileSystemUtils.createSymlink(from: source, to: destination)
            try patchCursorSettings(skillID: skillID, skillPath: destination.path)

        case .auto:
            throw SkillHubError.unsupportedInstallMode("auto mode requires resolution before enable")
        default:
            throw SkillHubError.unsupportedInstallMode("unknown install mode: \(resolvedMode.rawValue)")
        }
    }

    /// Disable removes the skill from Cursor's skills directory and unregisters from settings.
    public func disable(skillID: String) throws {
        let destination = skillsDirectory().appendingPathComponent(skillID, isDirectory: true)

        // Remove skill files/directory
        if FileManager.default.fileExists(atPath: destination.path) {
            try FileManager.default.removeItem(at: destination)
        }

        // Unpatch settings if present
        try unpatchCursorSettings(skillID: skillID)
    }

    /// Status reports the current state of the skill for this product.
    public func status(skillID: String) -> ProductSkillStatus {
        let staged = skillStoreRoot.appendingPathComponent(skillID, isDirectory: true)
        let enabled = skillsDirectory().appendingPathComponent(skillID, isDirectory: true)

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
            detail = "Registered in Cursor settings (skillhub.skills)"
        } else if isInstalled {
            return ProductSkillStatus(isInstalled: true, isEnabled: false, detail: "Installed but not enabled")
        } else {
            detail = "Not installed"
        }

        return ProductSkillStatus(isInstalled: isInstalled, isEnabled: isEnabled, detail: detail)
    }

    // MARK: - configPatch

    /// Patch Cursor's settings.json by adding to `skillhub.skills`.
    private func patchCursorSettings(skillID: String, skillPath: String) throws {
        try ConfigPatchValidation.validateSkillPath(skillPath, productID: id)
        var root = try ConfigPatchValidation.loadRootObjectIfExists(at: cursorSettingsJSON, productID: id)
        var (skillhub, skills) = try ConfigPatchValidation.extractSkillhubSection(from: root, productID: id)

        // Add skill path if not already present
        if !skills.contains(skillPath) {
            skills.append(skillPath)
        }

        skillhub["skills"] = skills
        root["skillhub"] = skillhub

        // Write updated settings
        try FileSystemUtils.ensureDirectoryExists(at: cursorSettingsJSON.deletingLastPathComponent())
        let data = try JSONSerialization.data(withJSONObject: root, options: [.prettyPrinted, .sortedKeys])
        try data.write(to: cursorSettingsJSON)
    }

    /// Remove skill from settings.json
    private func unpatchCursorSettings(skillID: String) throws {
        guard FileManager.default.fileExists(atPath: cursorSettingsJSON.path),
              var root = try? ConfigPatchValidation.loadRootObjectIfExists(at: cursorSettingsJSON, productID: id)
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
        try newData.write(to: cursorSettingsJSON)
    }

    /// Check if skill is registered in settings
    private func isSkillRegisteredInSettings(skillID: String) -> Bool {
        guard FileManager.default.fileExists(atPath: cursorSettingsJSON.path),
              let data = try? Data(contentsOf: cursorSettingsJSON),
              let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let skillhub = root["skillhub"] as? [String: Any],
              let skills = skillhub["skills"] as? [String]
        else {
            return false
        }

        return skills.contains { $0.contains(skillID) }
    }
}

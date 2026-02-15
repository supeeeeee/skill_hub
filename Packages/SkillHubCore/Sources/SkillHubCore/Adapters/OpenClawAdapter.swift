import Foundation

public struct OpenClawAdapter: ProductAdapter {
    public let id = "openclaw"
    public let name = "OpenClaw"
    public let supportedInstallModes: [InstallMode] = [.auto, .symlink, .copy]

    public init() {}

    private var skillStoreRoot: URL {
        SkillHubPaths.defaultSkillsDirectory()
    }

    private var openClawRoot: URL {
        let home = FileManager.default.homeDirectoryForCurrentUser
        return home.appendingPathComponent(".openclaw", isDirectory: true)
    }

    private var openClawSkillsDirectory: URL {
        openClawRoot.appendingPathComponent("skills", isDirectory: true)
    }

    public func detect() -> ProductDetectionResult {
        let fm = FileManager.default
        if fm.fileExists(atPath: openClawRoot.path) {
            return ProductDetectionResult(
                isDetected: true,
                reason: "Detected at \(openClawRoot.path)"
            )
        }

        return ProductDetectionResult(
            isDetected: false,
            reason: "Missing \(openClawRoot.path)"
        )
    }

    public func install(skill: SkillManifest, mode: InstallMode) throws -> InstallMode {
        let resolvedMode = try resolveInstallMode(mode)
        let skillInstallPath = skillStoreRoot.appendingPathComponent(skill.id, isDirectory: true)
        guard FileManager.default.fileExists(atPath: skillInstallPath.path) else {
            throw SkillHubError.invalidManifest("Skill not staged in \(skillInstallPath.path)")
        }

        try FileSystemUtils.ensureDirectoryExists(at: openClawSkillsDirectory)
        return resolvedMode
    }

    public func enable(skillID: String, mode: InstallMode) throws {
        let source = skillStoreRoot.appendingPathComponent(skillID, isDirectory: true)
        let destination = openClawSkillsDirectory.appendingPathComponent(skillID, isDirectory: true)
        guard FileManager.default.fileExists(atPath: source.path) else {
            throw SkillHubError.invalidManifest("Skill not staged in \(source.path)")
        }

        try FileSystemUtils.ensureDirectoryExists(at: openClawSkillsDirectory)

        let resolvedMode = try resolveInstallMode(mode)
        _ = try FileSystemUtils.backupIfExists(at: destination, productID: id, skillID: skillID)

        switch resolvedMode {
        case .symlink:
            try FileSystemUtils.createSymlink(from: source, to: destination)
        case .copy:
            try FileSystemUtils.copyItem(from: source, to: destination)
        case .auto, .configPatch:
            throw SkillHubError.unsupportedInstallMode("\(resolvedMode.rawValue) for \(id) enable")
        }
    }

    public func disable(skillID: String) throws {
        let destination = openClawSkillsDirectory.appendingPathComponent(skillID, isDirectory: true)
        if FileManager.default.fileExists(atPath: destination.path) {
            try FileManager.default.removeItem(at: destination)
        }
    }

    public func status(skillID: String) -> ProductSkillStatus {
        let skillInstallPath = skillStoreRoot.appendingPathComponent(skillID, isDirectory: true)
        let enabledPath = openClawSkillsDirectory.appendingPathComponent(skillID, isDirectory: true)
        let isInstalled = FileManager.default.fileExists(atPath: skillInstallPath.path)
        let isEnabled = FileManager.default.fileExists(atPath: enabledPath.path)

        if isEnabled,
           let symlinkDestination = try? FileManager.default.destinationOfSymbolicLink(atPath: enabledPath.path)
        {
            return ProductSkillStatus(
                isInstalled: isInstalled,
                isEnabled: true,
                detail: "Enabled via symlink to \(symlinkDestination)"
            )
        }

        let detail = isEnabled
            ? "Enabled via copied files at \(enabledPath.path)"
            : "No enabled files at \(enabledPath.path)"
        return ProductSkillStatus(isInstalled: isInstalled, isEnabled: isEnabled, detail: detail)
    }
}

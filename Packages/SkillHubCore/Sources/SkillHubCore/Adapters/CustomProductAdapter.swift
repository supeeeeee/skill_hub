import Foundation

public struct CustomProductAdapter: ProductAdapter {
    public let config: CustomProductConfig

    public var id: String { config.id }
    public var name: String { config.name }
    public let supportedInstallModes: [InstallMode] = [.copy]

    private var skillStoreRoot: URL {
        SkillHubPaths.defaultSkillsDirectory()
    }

    public init(config: CustomProductConfig) {
        self.config = config
    }

    public func skillsDirectory() -> URL {
        URL(fileURLWithPath: config.skillsDirectoryPath, isDirectory: true)
    }

    public func detect() -> ProductDetectionResult {
        if let path = ProductDetectionUtils.firstExistingPath(in: [skillsDirectory().path]) {
            return ProductDetectionResult(isDetected: true, reason: "Detected filesystem footprint at \(path)")
        }

        if let executable = ProductDetectionUtils.firstExecutablePath(named: config.executableNames) {
            return ProductDetectionResult(isDetected: true, reason: "Detected executable at \(executable)")
        }

        if config.executableNames.isEmpty {
            return ProductDetectionResult(
                isDetected: false,
                reason: "Missing \(skillsDirectory().path)"
            )
        }

        return ProductDetectionResult(
            isDetected: false,
            reason: "Missing \(skillsDirectory().path) and no executable found: \(config.executableNames.joined(separator: ", "))"
        )
    }

    public func install(skill: SkillManifest, mode: InstallMode) throws -> InstallMode {
        let resolvedMode = try resolveInstallMode(mode)
        let stagedSkillPath = skillStoreRoot.appendingPathComponent(skill.id, isDirectory: true)
        guard FileManager.default.fileExists(atPath: stagedSkillPath.path) else {
            throw SkillHubError.invalidManifest("Skill not staged in \(stagedSkillPath.path)")
        }

        try FileSystemUtils.ensureDirectoryExists(at: skillsDirectory())
        return resolvedMode
    }

    public func enable(skillID: String, mode: InstallMode) throws {
        let source = skillStoreRoot.appendingPathComponent(skillID, isDirectory: true)
        guard FileManager.default.fileExists(atPath: source.path) else {
            throw SkillHubError.invalidManifest("Skill not staged in \(source.path)")
        }

        try FileSystemUtils.ensureDirectoryExists(at: skillsDirectory())
        let destination = skillsDirectory().appendingPathComponent(skillID, isDirectory: true)

        _ = try FileSystemUtils.backupIfExists(at: destination, productID: id, skillID: skillID)
        _ = try resolveInstallMode(mode)
        try FileSystemUtils.copyItem(from: source, to: destination)
    }

    public func disable(skillID: String) throws {
        let destination = skillsDirectory().appendingPathComponent(skillID, isDirectory: true)
        if FileManager.default.fileExists(atPath: destination.path) {
            try FileManager.default.removeItem(at: destination)
        }
    }

    public func status(skillID: String) -> ProductSkillStatus {
        let staged = skillStoreRoot.appendingPathComponent(skillID, isDirectory: true)
        let enabled = skillsDirectory().appendingPathComponent(skillID, isDirectory: true)

        let isInstalled = FileManager.default.fileExists(atPath: staged.path)
        let isEnabled = FileManager.default.fileExists(atPath: enabled.path)

        let detail = isEnabled
            ? "Enabled via copied files at \(enabled.path)"
            : "No enabled files at \(enabled.path)"

        return ProductSkillStatus(isInstalled: isInstalled, isEnabled: isEnabled, detail: detail)
    }
}

public enum CustomProductAdapterFactory {
    public static func makeAdapters(from configs: [CustomProductConfig], excluding excludedIDs: Set<String> = []) -> [ProductAdapter] {
        configs.compactMap { config in
            if excludedIDs.contains(config.id) {
                return nil
            }
            return CustomProductAdapter(config: config)
        }
    }
}

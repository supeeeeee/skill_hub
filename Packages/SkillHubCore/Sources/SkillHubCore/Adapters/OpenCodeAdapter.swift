import Foundation

public struct OpenCodeAdapter: ProductAdapter {
    public let id = "opencode"
    public let name = "OpenCode"
    public let supportedInstallModes: [InstallMode] = [.auto, .symlink, .copy, .configPatch]

    public init() {}

    private var openCodeConfigPath: URL {
        let home = FileManager.default.homeDirectoryForCurrentUser
        return home.appendingPathComponent(".config/opencode/config.json", isDirectory: false)
    }

    public func detect() -> ProductDetectionResult {
        let exists = FileManager.default.fileExists(atPath: openCodeConfigPath.path)
        let reason = exists
            ? "Detected config at \(openCodeConfigPath.path)"
            : "Missing config file \(openCodeConfigPath.path)"
        return ProductDetectionResult(isDetected: exists, reason: reason)
    }

    public func install(skill _: SkillManifest, mode: InstallMode) throws -> InstallMode {
        let resolvedMode = try resolveInstallMode(mode)
        if resolvedMode == .configPatch {
            throw SkillHubError.notImplemented("TODO: patch OpenCode config with skill registration")
        }
        throw SkillHubError.notImplemented("TODO: OpenCode install flow for \(resolvedMode.rawValue)")
    }

    public func enable(skillID _: String, mode _: InstallMode) throws {
        throw SkillHubError.notImplemented("TODO: OpenCode enable flow")
    }

    public func disable(skillID _: String) throws {
        throw SkillHubError.notImplemented("TODO: OpenCode disable flow")
    }

    public func status(skillID _: String) -> ProductSkillStatus {
        ProductSkillStatus(
            isInstalled: false,
            isEnabled: false,
            detail: "TODO: inspect OpenCode config and skill directories"
        )
    }
}

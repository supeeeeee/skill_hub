import Foundation

public struct ClaudeCodeAdapter: ProductAdapter {
    public let id = "claude-code"
    public let name = "Claude Code"
    public let supportedInstallModes: [InstallMode] = [.auto, .copy, .configPatch]

    public init() {}

    private var claudeCodeConfigPath: URL {
        let home = FileManager.default.homeDirectoryForCurrentUser
        return home.appendingPathComponent(".claude/settings.json", isDirectory: false)
    }

    public func detect() -> ProductDetectionResult {
        let exists = FileManager.default.fileExists(atPath: claudeCodeConfigPath.path)
        let reason = exists
            ? "Detected config at \(claudeCodeConfigPath.path)"
            : "Missing config file \(claudeCodeConfigPath.path)"
        return ProductDetectionResult(isDetected: exists, reason: reason)
    }

    public func install(skill _: SkillManifest, mode: InstallMode) throws -> InstallMode {
        let resolvedMode = try resolveInstallMode(mode)
        if resolvedMode == .configPatch {
            throw SkillHubError.notImplemented("TODO: patch ~/.claude/settings.json for skill references")
        }
        throw SkillHubError.notImplemented("TODO: Claude Code install flow for \(resolvedMode.rawValue)")
    }

    public func enable(skillID _: String, mode _: InstallMode) throws {
        throw SkillHubError.notImplemented("TODO: Claude Code enable flow (likely config patch)")
    }

    public func disable(skillID _: String) throws {
        throw SkillHubError.notImplemented("TODO: Claude Code disable flow (reverse patch)")
    }

    public func status(skillID _: String) -> ProductSkillStatus {
        ProductSkillStatus(
            isInstalled: false,
            isEnabled: false,
            detail: "TODO: read Claude Code configuration for installed skills"
        )
    }
}

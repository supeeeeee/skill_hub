import Foundation

public struct CursorAdapter: ProductAdapter {
    public let id = "cursor"
    public let name = "Cursor"
    public let supportedInstallModes: [InstallMode] = [.auto, .symlink, .copy, .configPatch]

    public init() {}

    private var cursorExtensionsPath: URL {
        let home = FileManager.default.homeDirectoryForCurrentUser
        return home.appendingPathComponent(".cursor/extensions", isDirectory: true)
    }

    public func detect() -> ProductDetectionResult {
        let exists = FileManager.default.fileExists(atPath: cursorExtensionsPath.path)
        let reason = exists
            ? "Detected at \(cursorExtensionsPath.path)"
            : "Missing path \(cursorExtensionsPath.path)"
        return ProductDetectionResult(isDetected: exists, reason: reason)
    }

    public func install(skill _: SkillManifest, mode: InstallMode) throws -> InstallMode {
        let resolvedMode = try resolveInstallMode(mode)
        if resolvedMode == .configPatch {
            throw SkillHubError.notImplemented("TODO: patch Cursor settings JSON with skill references")
        }
        throw SkillHubError.notImplemented("TODO: Cursor install flow for \(resolvedMode.rawValue)")
    }

    public func enable(skillID _: String, mode _: InstallMode) throws {
        throw SkillHubError.notImplemented("TODO: Cursor enable flow")
    }

    public func disable(skillID _: String) throws {
        throw SkillHubError.notImplemented("TODO: Cursor disable flow")
    }

    public func status(skillID _: String) -> ProductSkillStatus {
        ProductSkillStatus(
            isInstalled: false,
            isEnabled: false,
            detail: "TODO: read Cursor metadata and settings for installed skills"
        )
    }
}

import Foundation

public struct ProductDetectionResult {
    public let isDetected: Bool
    public let reason: String

    public init(isDetected: Bool, reason: String) {
        self.isDetected = isDetected
        self.reason = reason
    }
}

public struct ProductSkillStatus {
    public let isInstalled: Bool
    public let isEnabled: Bool
    public let detail: String

    public init(isInstalled: Bool, isEnabled: Bool, detail: String) {
        self.isInstalled = isInstalled
        self.isEnabled = isEnabled
        self.detail = detail
    }
}

public protocol ProductAdapter {
    var id: String { get }
    var name: String { get }
    var supportedInstallModes: [InstallMode] { get }
    func skillsDirectory() -> URL

    func detect() -> ProductDetectionResult
    func install(skill: SkillManifest, mode: InstallMode) throws -> InstallMode
    func enable(skillID: String, mode: InstallMode) throws
    func disable(skillID: String) throws
    func status(skillID: String) -> ProductSkillStatus
}

public extension ProductAdapter {
    func resolveInstallMode(_ mode: InstallMode) throws -> InstallMode {
        if mode != .auto {
            guard supportedInstallModes.contains(mode) else {
                throw SkillHubError.unsupportedInstallMode("\(mode.rawValue) for \(id)")
            }
            return mode
        }

        if supportedInstallModes.contains(.symlink) {
            return .symlink
        }
        if supportedInstallModes.contains(.copy) {
            return .copy
        }
        if supportedInstallModes.contains(.configPatch) {
            return .configPatch
        }
        throw SkillHubError.unsupportedInstallMode("auto for \(id)")
    }
}

public struct AdapterRegistry {
    private let adapters: [String: ProductAdapter]

    public init(adapters: [ProductAdapter]) {
        self.adapters = Dictionary(uniqueKeysWithValues: adapters.map { ($0.id, $0) })
    }

    public func all() -> [ProductAdapter] {
        adapters.values.sorted { $0.id < $1.id }
    }

    public func adapter(for id: String) throws -> ProductAdapter {
        guard let adapter = adapters[id] else {
            throw SkillHubError.adapterNotFound(id)
        }
        return adapter
    }
}

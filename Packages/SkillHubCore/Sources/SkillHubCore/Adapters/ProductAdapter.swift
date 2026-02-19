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
    func configFilePath() -> URL?

    func detect() -> ProductDetectionResult
    func install(skill: SkillManifest, mode: InstallMode) throws -> InstallMode
    func enable(skillID: String, mode: InstallMode) throws
    func disable(skillID: String) throws
    func status(skillID: String) -> ProductSkillStatus
}

public extension ProductAdapter {
    func configFilePath() -> URL? {
        nil
    }

    func resolveInstallMode(_ mode: InstallMode) throws -> InstallMode {
        if supportedInstallModes.contains(.copy) {
            return .copy
        }
        throw SkillHubError.unsupportedInstallMode("copy for \(id)")
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

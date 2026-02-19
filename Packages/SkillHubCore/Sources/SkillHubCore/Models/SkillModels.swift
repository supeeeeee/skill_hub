import Foundation

public enum InstallMode: String, Codable, CaseIterable, Sendable {
    case auto
    case symlink
    case copy
    case configPatch
    case unknown

    public init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = try container.decode(String.self)
        switch rawValue {
        case "auto":
            self = .auto
        case "symlink":
            self = .symlink
        case "copy":
            self = .copy
        case "configPatch", "config-patch":
            self = .configPatch
        default:
            self = .unknown
        }
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(self.rawValue)
    }
}

public struct AdapterConfig: Codable, Equatable, Sendable {
    public let productID: String
    public let installMode: InstallMode
    public let targetPath: String?
    public let configPatch: [String: String]?

    public init(
        productID: String,
        installMode: InstallMode,
        targetPath: String? = nil,
        configPatch: [String: String]? = nil
    ) {
        self.productID = productID
        self.installMode = installMode
        self.targetPath = targetPath
        self.configPatch = configPatch
    }
}

public struct SkillManifest: Codable, Equatable, Sendable {
    public let id: String
    public let name: String
    public let version: String
    public let summary: String
    public let entrypoint: String?
    public let tags: [String]
    public let adapters: [AdapterConfig]

    public init(
        id: String,
        name: String,
        version: String,
        summary: String,
        entrypoint: String? = nil,
        tags: [String] = [],
        adapters: [AdapterConfig] = []
    ) {
        self.id = id
        self.name = name
        self.version = version
        self.summary = summary
        self.entrypoint = entrypoint
        self.tags = tags
        self.adapters = adapters
    }
}

public struct InstalledSkillRecord: Codable, Equatable, Identifiable, Sendable {
    public var id: String { manifest.id }
    public var manifest: SkillManifest
    public var manifestPath: String
    public var manifestSource: String?
    public var installedProducts: [String]
    public var enabledProducts: [String]
    public var lastInstallModeByProduct: [String: InstallMode]
    public var hasUpdate: Bool = false

    public func isBound(to productID: String) -> Bool {
        installedProducts.contains(productID)
    }

    public init(
        manifest: SkillManifest,
        manifestPath: String,
        manifestSource: String? = nil,
        installedProducts: [String] = [],
        enabledProducts: [String] = [],
        lastInstallModeByProduct: [String: InstallMode] = [:],
        hasUpdate: Bool = false
    ) {
        self.manifest = manifest
        self.manifestPath = manifestPath
        self.manifestSource = manifestSource
        self.installedProducts = installedProducts
        self.enabledProducts = enabledProducts
        self.lastInstallModeByProduct = lastInstallModeByProduct
        self.hasUpdate = hasUpdate
    }
}

public struct SkillHubState: Codable, Equatable {
    public var schemaVersion: Int
    public var skills: [InstalledSkillRecord]
    public var productConfigFilePathOverrides: [String: String]
    public var updatedAt: Date

    public init(
        schemaVersion: Int = 1,
        skills: [InstalledSkillRecord] = [],
        productConfigFilePathOverrides: [String: String] = [:],
        updatedAt: Date = Date()
    ) {
        self.schemaVersion = schemaVersion
        self.skills = skills
        self.productConfigFilePathOverrides = productConfigFilePathOverrides
        self.updatedAt = updatedAt
    }

    enum CodingKeys: String, CodingKey {
        case schemaVersion
        case skills
        case productConfigFilePathOverrides
        case updatedAt
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.schemaVersion = try container.decode(Int.self, forKey: .schemaVersion)
        self.skills = try container.decode([InstalledSkillRecord].self, forKey: .skills)
        self.productConfigFilePathOverrides = try container.decodeIfPresent([String: String].self, forKey: .productConfigFilePathOverrides) ?? [:]
        self.updatedAt = try container.decode(Date.self, forKey: .updatedAt)
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(self.schemaVersion, forKey: .schemaVersion)
        try container.encode(self.skills, forKey: .skills)
        try container.encode(self.productConfigFilePathOverrides, forKey: .productConfigFilePathOverrides)
        try container.encode(self.updatedAt, forKey: .updatedAt)
    }
}

public enum HealthStatus: String, Codable, CaseIterable, Sendable {
    case healthy
    case warning
    case unknown
    case error
}

public struct FixSuggestion: Codable, Sendable, Identifiable {
    public var id: String { label }
    public let label: String
    public let action: String
    public let description: String
    public let isAutomated: Bool

    public init(label: String, action: String, description: String, isAutomated: Bool = true) {
        self.label = label
        self.action = action
        self.description = description
        self.isAutomated = isAutomated
    }
}

public struct DiagnosticIssue: Identifiable, Sendable {
    public let id: String
    public let message: String
    public let isFixable: Bool
    public let suggestion: FixSuggestion?

    public init(id: String, message: String, isFixable: Bool, suggestion: FixSuggestion? = nil) {
        self.id = id
        self.message = message
        self.isFixable = isFixable
        self.suggestion = suggestion
    }
}

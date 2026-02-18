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

public enum SkillHubTerminology: String, CaseIterable, Sendable {
    case add
    case deploy
    case sampleSkill
    case discoverySkill

    public var definition: String {
        switch self {
        case .add:
            return "Add registers a skill and prepares a managed local copy under SkillHub storage."
        case .deploy:
            return "Deploy applies a prepared skill to a target product and records the selected mode."
        case .sampleSkill:
            return "Sample skill is built-in demo content intended for onboarding and preview."
        case .discoverySkill:
            return "Discovery skill is a recommended catalog item before explicit import."
        }
    }
}

public struct InstalledSkillRecord: Codable, Equatable, Identifiable, Sendable {
    public var id: String { manifest.id }
    public var manifest: SkillManifest
    public var manifestPath: String
    public var manifestSource: String?
    public var deployedProducts: [String]
    public var enabledProducts: [String]
    public var lastDeployModeByProduct: [String: InstallMode]
    public var isSample: Bool
    public var isDiscovery: Bool
    public var hasUpdate: Bool = false

    @available(*, deprecated, message: "Use deployedProducts")
    public var installedProducts: [String] {
        get { deployedProducts }
        set { deployedProducts = newValue }
    }

    @available(*, deprecated, message: "Use lastDeployModeByProduct")
    public var lastInstallModeByProduct: [String: InstallMode] {
        get { lastDeployModeByProduct }
        set { lastDeployModeByProduct = newValue }
    }

    public init(
        manifest: SkillManifest,
        manifestPath: String,
        manifestSource: String? = nil,
        deployedProducts: [String] = [],
        enabledProducts: [String] = [],
        lastDeployModeByProduct: [String: InstallMode] = [:],
        isSample: Bool = false,
        isDiscovery: Bool = false,
        hasUpdate: Bool = false
    ) {
        self.manifest = manifest
        self.manifestPath = manifestPath
        self.manifestSource = manifestSource
        self.deployedProducts = deployedProducts
        self.enabledProducts = enabledProducts
        self.lastDeployModeByProduct = lastDeployModeByProduct
        self.isSample = isSample
        self.isDiscovery = isDiscovery
        self.hasUpdate = hasUpdate
    }

    @available(*, deprecated, message: "Use init with deployedProducts/lastDeployModeByProduct")
    public init(
        manifest: SkillManifest,
        manifestPath: String,
        manifestSource: String? = nil,
        installedProducts: [String] = [],
        enabledProducts: [String] = [],
        lastInstallModeByProduct: [String: InstallMode] = [:],
        isSample: Bool = false,
        isDiscovery: Bool = false,
        hasUpdate: Bool = false
    ) {
        self.init(
            manifest: manifest,
            manifestPath: manifestPath,
            manifestSource: manifestSource,
            deployedProducts: installedProducts,
            enabledProducts: enabledProducts,
            lastDeployModeByProduct: lastInstallModeByProduct,
            isSample: isSample,
            isDiscovery: isDiscovery,
            hasUpdate: hasUpdate
        )
    }

    private enum CodingKeys: String, CodingKey {
        case manifest
        case manifestPath
        case manifestSource
        case deployedProducts
        case installedProducts
        case enabledProducts
        case lastDeployModeByProduct
        case lastInstallModeByProduct
        case isSample
        case isDiscovery
        case hasUpdate
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        manifest = try container.decode(SkillManifest.self, forKey: .manifest)
        manifestPath = try container.decode(String.self, forKey: .manifestPath)
        manifestSource = try container.decodeIfPresent(String.self, forKey: .manifestSource)
        deployedProducts = try container.decodeIfPresent([String].self, forKey: .deployedProducts)
            ?? container.decodeIfPresent([String].self, forKey: .installedProducts)
            ?? []
        enabledProducts = try container.decodeIfPresent([String].self, forKey: .enabledProducts) ?? []
        lastDeployModeByProduct = try container.decodeIfPresent([String: InstallMode].self, forKey: .lastDeployModeByProduct)
            ?? container.decodeIfPresent([String: InstallMode].self, forKey: .lastInstallModeByProduct)
            ?? [:]
        isSample = try container.decodeIfPresent(Bool.self, forKey: .isSample) ?? false
        isDiscovery = try container.decodeIfPresent(Bool.self, forKey: .isDiscovery) ?? false
        hasUpdate = try container.decodeIfPresent(Bool.self, forKey: .hasUpdate) ?? false
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(manifest, forKey: .manifest)
        try container.encode(manifestPath, forKey: .manifestPath)
        try container.encodeIfPresent(manifestSource, forKey: .manifestSource)
        try container.encode(deployedProducts, forKey: .deployedProducts)
        try container.encode(enabledProducts, forKey: .enabledProducts)
        try container.encode(lastDeployModeByProduct, forKey: .lastDeployModeByProduct)
        try container.encode(isSample, forKey: .isSample)
        try container.encode(isDiscovery, forKey: .isDiscovery)
        try container.encode(hasUpdate, forKey: .hasUpdate)

        try container.encode(deployedProducts, forKey: .installedProducts)
        try container.encode(lastDeployModeByProduct, forKey: .lastInstallModeByProduct)
    }
}

public struct SkillHubState: Codable, Equatable {
    public var schemaVersion: Int
    public var skills: [InstalledSkillRecord]
    public var updatedAt: Date

    public init(
        schemaVersion: Int = 1,
        skills: [InstalledSkillRecord] = [],
        updatedAt: Date = Date()
    ) {
        self.schemaVersion = schemaVersion
        self.skills = skills
        self.updatedAt = updatedAt
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

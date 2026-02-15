import Foundation

public enum InstallMode: String, Codable, CaseIterable, Sendable {
    case auto
    case symlink
    case copy
    case configPatch

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
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Unsupported install mode: \(rawValue)"
            )
        }
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}

public struct AdapterConfig: Codable, Equatable {
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

public struct SkillManifest: Codable, Equatable {
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

public struct InstalledSkillRecord: Codable, Equatable, Identifiable {
    public var id: String { manifest.id }
    public var manifest: SkillManifest
    public var manifestPath: String
    public var manifestSource: String?
    public var installedProducts: [String]
    public var enabledProducts: [String]
    public var lastInstallModeByProduct: [String: InstallMode]

    public init(
        manifest: SkillManifest,
        manifestPath: String,
        manifestSource: String? = nil,
        installedProducts: [String] = [],
        enabledProducts: [String] = [],
        lastInstallModeByProduct: [String: InstallMode] = [:]
    ) {
        self.manifest = manifest
        self.manifestPath = manifestPath
        self.manifestSource = manifestSource
        self.installedProducts = installedProducts
        self.enabledProducts = enabledProducts
        self.lastInstallModeByProduct = lastInstallModeByProduct
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

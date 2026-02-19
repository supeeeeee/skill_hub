import Foundation

public struct CustomProductConfig: Codable, Sendable, Hashable {
    public var id: String
    public var name: String
    public var skillsDirectoryPath: String
    public var executableNames: [String]
    public var iconName: String?

    public init(
        id: String,
        name: String,
        skillsDirectoryPath: String,
        executableNames: [String] = [],
        iconName: String? = nil
    ) {
        self.id = id
        self.name = name
        self.skillsDirectoryPath = skillsDirectoryPath
        self.executableNames = executableNames
        self.iconName = iconName
    }
}

public struct SkillHubConfig: Codable, Sendable {
    public var productSkillsDirectoryOverrides: [String: String]
    public var customProducts: [CustomProductConfig]

    public init(
        productSkillsDirectoryOverrides: [String: String] = [:],
        customProducts: [CustomProductConfig] = []
    ) {
        self.productSkillsDirectoryOverrides = productSkillsDirectoryOverrides
        self.customProducts = customProducts
    }

    enum CodingKeys: String, CodingKey {
        case productSkillsDirectoryOverrides
        case customProducts
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.productSkillsDirectoryOverrides = try container.decodeIfPresent([String: String].self, forKey: .productSkillsDirectoryOverrides) ?? [:]
        self.customProducts = try container.decodeIfPresent([CustomProductConfig].self, forKey: .customProducts) ?? []
    }

    public static func configFileURL() -> URL {
        SkillHubPaths.defaultStateDirectory().appendingPathComponent("config.json", isDirectory: false)
    }

    public static func load() -> SkillHubConfig {
        let url = configFileURL()
        guard FileManager.default.fileExists(atPath: url.path),
              let data = try? Data(contentsOf: url),
              let decoded = try? JSONDecoder().decode(SkillHubConfig.self, from: data)
        else {
            return SkillHubConfig()
        }
        return decoded
    }

    public func save() throws {
        let url = Self.configFileURL()
        try FileSystemUtils.ensureDirectoryExists(at: url.deletingLastPathComponent())
        let data = try JSONEncoder().encode(self)
        try data.write(to: url, options: .atomic)
    }

    public static func overrideSkillsDirectory(for productID: String) -> URL? {
        let cfg = load()
        guard let raw = cfg.productSkillsDirectoryOverrides[productID], !raw.isEmpty else { return nil }
        return URL(fileURLWithPath: raw, isDirectory: true)
    }
}

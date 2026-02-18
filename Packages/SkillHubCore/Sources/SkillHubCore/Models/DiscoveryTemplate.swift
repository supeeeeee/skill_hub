import Foundation

public struct DiscoverySkillTemplate: Codable, Equatable, Sendable, Identifiable {
    public let id: String
    public let name: String
    public let version: String
    public let summary: String
    public let tags: [String]
    public let source: String
    public let isSample: Bool

    public init(
        id: String,
        name: String,
        version: String,
        summary: String,
        tags: [String],
        source: String,
        isSample: Bool
    ) {
        self.id = id
        self.name = name
        self.version = version
        self.summary = summary
        self.tags = tags
        self.source = source
        self.isSample = isSample
    }
}

public enum DiscoveryCatalogLoader {
    public static func loadDefaultCatalog() throws -> [DiscoverySkillTemplate] {
        guard let url = Bundle.module.url(forResource: "discovery", withExtension: "json") else {
            throw SkillHubError.invalidManifest("Missing built-in discovery catalog template")
        }
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode([DiscoverySkillTemplate].self, from: data)
    }
}

import Foundation

public struct DiscoverySkill: Codable, Equatable, Identifiable, Sendable {
    public let name: String
    public let summary: String
    public let sourceURL: String

    public var id: String { sourceURL }

    public init(name: String, summary: String, sourceURL: String) {
        self.name = name
        self.summary = summary
        self.sourceURL = sourceURL
    }
}

public enum DiscoveryCatalog {
    public static func loadBundled() throws -> [DiscoverySkill] {
        guard let url = Bundle.module.url(forResource: "discovery", withExtension: "json") else {
            throw SkillHubError.invalidManifest("Bundled discovery catalog not found")
        }

        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode([DiscoverySkill].self, from: data)
    }
}

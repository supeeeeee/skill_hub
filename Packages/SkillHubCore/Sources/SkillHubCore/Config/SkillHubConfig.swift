import Foundation

public struct SkillHubConfig: Codable, Sendable {
    public var productSkillsDirectoryOverrides: [String: String]

    public init(productSkillsDirectoryOverrides: [String: String] = [:]) {
        self.productSkillsDirectoryOverrides = productSkillsDirectoryOverrides
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

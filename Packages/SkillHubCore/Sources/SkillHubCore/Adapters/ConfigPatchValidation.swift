import Foundation

enum ConfigPatchValidation {
    static func loadRootObjectIfExists(at url: URL, productID: String) throws -> [String: Any] {
        guard FileManager.default.fileExists(atPath: url.path) else {
            return [:]
        }

        let data = try Data(contentsOf: url)
        let json = try JSONSerialization.jsonObject(with: data)
        guard let root = json as? [String: Any] else {
            throw SkillHubError.invalidManifest("\(productID) config must be a JSON object: \(url.path)")
        }
        return root
    }

    static func validateSkillPath(_ path: String, productID: String) throws {
        let trimmed = path.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw SkillHubError.invalidManifest("\(productID) configPatch requires a non-empty skill path")
        }
        guard trimmed.hasPrefix("/") else {
            throw SkillHubError.invalidManifest("\(productID) configPatch requires an absolute skill path: \(path)")
        }
    }

    static func extractSkillhubSection(from root: [String: Any], productID: String) throws -> ([String: Any], [String]) {
        if let value = root["skillhub"], !(value is [String: Any]) {
            throw SkillHubError.invalidManifest("\(productID) configPatch expects 'skillhub' to be an object")
        }

        let skillhub = root["skillhub"] as? [String: Any] ?? [:]
        if let value = skillhub["skills"], !(value is [String]) {
            throw SkillHubError.invalidManifest("\(productID) configPatch expects 'skillhub.skills' to be a string array")
        }

        let skills = skillhub["skills"] as? [String] ?? []
        for skillPath in skills {
            try validateSkillPath(skillPath, productID: productID)
        }

        return (skillhub, skills)
    }
}

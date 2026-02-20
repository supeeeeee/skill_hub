import Foundation
import SkillHubCore

enum AgentSkillLoader {
    static func loadFromDirectory(_ directory: URL) throws -> (manifest: SkillManifest, markdownPath: URL) {
        let markdown = try locateSkillMarkdown(in: directory)
        let manifest = try loadManifest(from: markdown)
        return (manifest, markdown)
    }

    static func loadManifest(from markdownURL: URL) throws -> SkillManifest {
        guard markdownURL.lastPathComponent == "SKILL.md" else {
            throw SkillHubError.invalidManifest("Entrypoint must be SKILL.md")
        }

        let markdown = try String(contentsOf: markdownURL, encoding: .utf8)
        let parsed = try parseFrontmatterAndBody(from: markdown)

        guard let nameRaw = parsed.frontmatter["name"], !nameRaw.isEmpty else {
            throw SkillHubError.invalidManifest("SKILL.md frontmatter requires non-empty 'name'")
        }
        guard let descriptionRaw = parsed.frontmatter["description"], !descriptionRaw.isEmpty else {
            throw SkillHubError.invalidManifest("SKILL.md frontmatter requires non-empty 'description'")
        }

        let name = nameRaw.trimmingCharacters(in: .whitespacesAndNewlines)
        let description = descriptionRaw.trimmingCharacters(in: .whitespacesAndNewlines)

        try validateSkillName(name)
        if description.count > 1024 {
            throw SkillHubError.invalidManifest("SKILL.md frontmatter 'description' must be 1-1024 characters")
        }

        if parsed.body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            throw SkillHubError.invalidManifest("SKILL.md body must not be empty")
        }

        let parentName = markdownURL.deletingLastPathComponent().lastPathComponent
        if parentName != name {
            throw SkillHubError.invalidManifest("SKILL.md 'name' must match parent directory name. name=\(name), directory=\(parentName)")
        }

        return SkillManifest(
            id: name,
            name: name,
            version: "1.0.0",
            summary: description,
            entrypoint: "SKILL.md",
            tags: [],
            adapters: []
        )
    }

    private static func locateSkillMarkdown(in root: URL) throws -> URL {
        let fm = FileManager.default
        var isDirectory: ObjCBool = false
        guard fm.fileExists(atPath: root.path, isDirectory: &isDirectory) else {
            throw SkillHubError.invalidManifest("Source not found: \(root.path)")
        }

        if !isDirectory.boolValue {
            guard root.lastPathComponent == "SKILL.md" else {
                throw SkillHubError.invalidManifest("Source file must be SKILL.md")
            }
            return root
        }

        guard let enumerator = fm.enumerator(
            at: root,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) else {
            throw SkillHubError.invalidManifest("Could not read skill directory: \(root.path)")
        }

        var matches: [URL] = []
        for case let fileURL as URL in enumerator {
            guard fileURL.lastPathComponent == "SKILL.md" else { continue }
            if let resourceValues = try? fileURL.resourceValues(forKeys: [.isRegularFileKey]),
               resourceValues.isRegularFile == true
            {
                matches.append(fileURL)
            }
        }

        if matches.isEmpty {
            throw SkillHubError.invalidManifest("No SKILL.md found in source: \(root.path)")
        }

        if matches.count > 1 {
            let listed = matches.map(\.path).sorted().joined(separator: ", ")
            throw SkillHubError.invalidManifest("Multiple SKILL.md files found. Provide a specific skill directory: \(listed)")
        }

        return matches[0]
    }

    private static func parseFrontmatterAndBody(from markdown: String) throws -> (frontmatter: [String: String], body: String) {
        let lines = markdown.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        guard lines.count >= 3, lines[0].trimmingCharacters(in: .whitespacesAndNewlines) == "---" else {
            throw SkillHubError.invalidManifest("SKILL.md must start with YAML frontmatter delimited by '---'")
        }

        var index = 1
        var fields: [String: String] = [:]
        var foundClosing = false
        while index < lines.count {
            let rawLine = lines[index]
            let trimmed = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed == "---" {
                foundClosing = true
                break
            }

            if !trimmed.isEmpty, !trimmed.hasPrefix("#") {
                let parts = rawLine.split(separator: ":", maxSplits: 1, omittingEmptySubsequences: false)
                if parts.count != 2 {
                    throw SkillHubError.invalidManifest("Invalid frontmatter line: \(rawLine)")
                }

                let key = parts[0].trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                var value = parts[1].trimmingCharacters(in: .whitespacesAndNewlines)
                value = value.trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))

                if key.isEmpty {
                    throw SkillHubError.invalidManifest("Frontmatter key cannot be empty")
                }
                if fields[key] != nil {
                    throw SkillHubError.invalidManifest("Duplicate frontmatter key: \(key)")
                }
                fields[key] = value
            }
            index += 1
        }

        if !foundClosing {
            throw SkillHubError.invalidManifest("SKILL.md frontmatter must end with '---'")
        }

        let bodyLines = Array(lines.suffix(from: index + 1))
        return (fields, bodyLines.joined(separator: "\n"))
    }

    private static func validateSkillName(_ skillName: String) throws {
        if skillName.count < 1 || skillName.count > 64 {
            throw SkillHubError.invalidManifest("SKILL.md frontmatter 'name' must be 1-64 characters")
        }

        let pattern = "^[a-z0-9]+(?:-[a-z0-9]+)*$"
        let range = NSRange(location: 0, length: skillName.utf16.count)
        let regex = try NSRegularExpression(pattern: pattern)
        if regex.firstMatch(in: skillName, options: [], range: range) == nil {
            throw SkillHubError.invalidManifest("SKILL.md frontmatter 'name' must use lowercase letters, numbers, and single hyphens")
        }
    }
}

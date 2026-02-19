import Foundation
import SkillHubCore

extension CLI {
    func products() throws {
        for adapter in adapterRegistry.all() {
            let detection = adapter.detect()
            let supportedModes = adapter.supportedInstallModes.map(\.rawValue).joined(separator: ", ")
            print("\(adapter.id) (\(adapter.name)) - \(detection.isDetected ? "detected" : "not detected") - \(detection.reason) - modes=[\(supportedModes)]")
        }
    }

    func detect(json: Bool = false) throws {
        if json {
            var adapterReadinessList: [ReadinessReport.AdapterReadiness] = []
            for adapter in adapterRegistry.all() {
                let detection = adapter.detect()
                let supportedModes = adapter.supportedInstallModes.map { $0.rawValue }
                adapterReadinessList.append(ReadinessReport.AdapterReadiness(
                    id: adapter.id,
                    name: adapter.name,
                    detected: detection.isDetected,
                    reason: detection.reason,
                    supportedModes: supportedModes
                ))
            }

            let overallReady = adapterReadinessList.contains { $0.detected }
            let report = ReadinessReport(
                timestamp: Date(),
                version: "1.0.0",
                adapters: adapterReadinessList,
                overallReady: overallReady
            )

            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let jsonData = try encoder.encode(report)
            if let jsonString = String(data: jsonData, encoding: .utf8) {
                print(jsonString)
            }
        } else {
            print("Detection report:")
            for adapter in adapterRegistry.all() {
                let detection = adapter.detect()
                let status = detection.isDetected ? "detected" : "not detected"
                print("- \(adapter.id): \(status) - \(detection.reason)")
            }
        }
    }

    func skills() throws {
        let state = try store.loadState()
        if state.skills.isEmpty {
            print("No skills registered.")
            return
        }

        for record in state.skills {
            print("\(record.manifest.id) v\(record.manifest.version) - \(record.manifest.name)")
        }
    }

    func add(arguments: [String]) throws {
        guard let source = arguments.first else {
            throw SkillHubError.invalidManifest("Usage: add <source>")
        }

        let (manifest, sourcePath) = try resolveAgentSkill(source: source)
        let validationErrors = SchemaValidator.shared.validate(manifest)
        if !validationErrors.isEmpty {
            throw SkillHubError.invalidManifest("Manifest validation failed: \(validationErrors.joined(separator: ", "))")
        }

        try store.upsertSkill(manifest: manifest, manifestPath: sourcePath)
        print("Added skill \(manifest.id) from \(source)")
    }

    func stage(arguments: [String]) throws {
        guard let source = arguments.first else {
            throw SkillHubError.invalidManifest("Usage: stage <source|skill-id>")
        }

        let state = try store.loadState()
        let manifest: SkillManifest
        let sourceDirectory: URL

        if let existing = state.skills.first(where: { $0.manifest.id == source }) {
            manifest = existing.manifest
            sourceDirectory = Self.expandPath(existing.manifestPath).deletingLastPathComponent()
        } else {
            let (resolvedManifest, resolvedPath) = try resolveAgentSkill(source: source)
            let validationErrors = SchemaValidator.shared.validate(resolvedManifest)
            if !validationErrors.isEmpty {
                throw SkillHubError.invalidManifest("Manifest validation failed: \(validationErrors.joined(separator: ", "))")
            }
            manifest = resolvedManifest
            sourceDirectory = URL(fileURLWithPath: resolvedPath).deletingLastPathComponent()
            try store.upsertSkill(manifest: manifest, manifestPath: resolvedPath)
        }

        let stagedPath = try stageSkillInStore(skillID: manifest.id, sourceDirectory: sourceDirectory)
        print("Staged \(manifest.id) at \(stagedPath.path)")
    }

    func unstage(arguments: [String]) throws {
        guard let skillID = arguments.first else {
            throw SkillHubError.invalidManifest("Usage: unstage <skill-id>")
        }

        let stagedPath = stagedSkillPath(skillID: skillID)
        if FileManager.default.fileExists(atPath: stagedPath.path) {
            try FileManager.default.removeItem(at: stagedPath)
            print("Unstaged \(skillID) from \(stagedPath.path)")
        } else {
            print("No staged directory found for \(skillID)")
        }
    }

    func install(arguments: [String]) throws {
        guard arguments.count >= 2 else {
            throw SkillHubError.invalidManifest("Usage: install <skill-id> <product-id> [--mode auto|symlink|copy|configPatch]")
        }

        let skillID = arguments[0]
        let productID = arguments[1]

        let mode: InstallMode
        if let modeIndex = arguments.firstIndex(of: "--mode"), arguments.indices.contains(modeIndex + 1) {
            mode = try parseInstallMode(arguments[modeIndex + 1])
        } else {
            mode = .auto
        }

        let state = try store.loadState()
        guard let skillRecord = state.skills.first(where: { $0.manifest.id == skillID }) else {
            throw SkillHubError.invalidManifest("Skill not found: \(skillID)")
        }

        let adapter = try adapterRegistry.adapter(for: productID)
        let detection = adapter.detect()
        guard detection.isDetected else {
            throw SkillHubError.adapterEnvironmentInvalid("\(detection.reason). Run: doctor")
        }

        let stagedPath = stagedSkillPath(skillID: skillID)
        guard FileManager.default.fileExists(atPath: stagedPath.path) else {
            throw SkillHubError.invalidManifest("Skill is not staged: \(stagedPath.path). Run: stage \(skillRecord.manifestPath) or apply \(skillRecord.manifestPath) \(productID)")
        }

        let chosenMode = try adapter.install(skill: skillRecord.manifest, mode: mode)

        try store.markInstalled(skillID: skillID, productID: productID, installMode: chosenMode)
        print("Installed \(skillID) for \(productID). requestedMode=\(mode.rawValue) chosenMode=\(chosenMode.rawValue) stagedPath=\(stagedPath.path)")
    }

    func apply(arguments: [String]) throws {
        guard arguments.count >= 2 else {
            throw SkillHubError.invalidManifest("Usage: apply <source|skill-id> <product-id> [--mode auto|symlink|copy|configPatch]")
        }

        let firstArgument = arguments[0]
        let productID = arguments[1]

        let mode: InstallMode
        if let modeIndex = arguments.firstIndex(of: "--mode"), arguments.indices.contains(modeIndex + 1) {
            mode = try parseInstallMode(arguments[modeIndex + 1])
        } else {
            mode = .auto
        }

        let stateBefore = try store.loadState()
        var skillID = firstArgument

        if stateBefore.skills.first(where: { $0.manifest.id == firstArgument }) == nil {
            let (manifest, sourcePath) = try resolveAgentSkill(source: firstArgument)
            let validationErrors = SchemaValidator.shared.validate(manifest)
            if !validationErrors.isEmpty {
                throw SkillHubError.invalidManifest("Manifest validation failed: \(validationErrors.joined(separator: ", "))")
            }

            print("[1/5] Registering skill \(manifest.id) from \(firstArgument)")
            try store.upsertSkill(manifest: manifest, manifestPath: sourcePath)
            skillID = manifest.id
        }

        let state = try store.loadState()
        guard let skillRecord = state.skills.first(where: { $0.manifest.id == skillID }) else {
            throw SkillHubError.invalidManifest("Skill not found: \(skillID)")
        }

        let manifestURL = Self.expandPath(skillRecord.manifestPath)

        let sourceDirectory = manifestURL.deletingLastPathComponent()
        print("[2/5] Staging \(skillID) from \(sourceDirectory.path)")
        let stagedPath = try stageSkillInStore(skillID: skillID, sourceDirectory: sourceDirectory)

        let adapter = try adapterRegistry.adapter(for: productID)
        let detection = adapter.detect()
        guard detection.isDetected else {
            throw SkillHubError.adapterEnvironmentInvalid("\(detection.reason). Run: doctor")
        }

        print("[3/5] Installing \(skillID) into \(productID) (requested mode: \(mode.rawValue))")
        let chosenMode = try adapter.install(skill: skillRecord.manifest, mode: mode)

        print("[4/5] Enabling \(skillID) for \(productID) with mode \(chosenMode.rawValue)")
        try adapter.enable(skillID: skillID, mode: chosenMode)

        print("[5/5] Updating state (installed + enabled)")
        try store.markInstalled(skillID: skillID, productID: productID, installMode: chosenMode)
        try store.setEnabled(skillID: skillID, productID: productID, enabled: true)

        print("Applied \(skillID) to \(productID). requestedMode=\(mode.rawValue) chosenMode=\(chosenMode.rawValue) stagedPath=\(stagedPath.path)")
    }

    func uninstall(arguments: [String]) throws {
        guard arguments.count >= 2 else {
            throw SkillHubError.invalidManifest("Usage: uninstall <skill-id> <product-id>")
        }

        let skillID = arguments[0]
        let productID = arguments[1]
        let adapter = try adapterRegistry.adapter(for: productID)

        let detection = adapter.detect()
        guard detection.isDetected else {
            throw SkillHubError.adapterEnvironmentInvalid("\(detection.reason). Run: doctor")
        }

        try adapter.disable(skillID: skillID)
        try store.markUninstalled(skillID: skillID, productID: productID)
        print("Uninstalled \(skillID) from \(productID). Staged files kept at \(stagedSkillPath(skillID: skillID).path)")
    }

    func toggle(arguments: [String], enabled: Bool) throws {
        guard arguments.count >= 2 else {
            throw SkillHubError.invalidManifest(enabled
                ? "Usage: enable <skill-id> <product-id>"
                : "Usage: disable <skill-id> <product-id>")
        }

        let skillID = arguments[0]
        let productID = arguments[1]
        let adapter = try adapterRegistry.adapter(for: productID)

        let detection = adapter.detect()
        guard detection.isDetected else {
            throw SkillHubError.adapterEnvironmentInvalid(detection.reason)
        }

        if enabled {
            let state = try store.loadState()
            guard let skillRecord = state.skills.first(where: { $0.manifest.id == skillID }) else {
                throw SkillHubError.invalidManifest("Skill not found: \(skillID)")
            }
            guard let installedMode = skillRecord.lastInstallModeByProduct[productID] else {
                throw SkillHubError.invalidManifest("Skill \(skillID) is not installed for \(productID). Run: install \(skillID) \(productID) or apply <source|skill-id> \(productID)")
            }
            try adapter.enable(skillID: skillID, mode: installedMode)
        } else {
            try adapter.disable(skillID: skillID)
        }

        try store.setEnabled(skillID: skillID, productID: productID, enabled: enabled)
        print("\(enabled ? "Enabled" : "Disabled") \(skillID) for \(productID)")
    }

    func status(arguments: [String], json: Bool = false) throws {
        let state = try store.loadState()
        let skillID = arguments.first

        let rows = state.skills.filter { record in
            if let skillID {
                return record.manifest.id == skillID
            }
            return true
        }

        if rows.isEmpty {
            print("No matching skill status found.")
            return
        }

        if json {
            var skillsList: [[String: Any]] = []
            for record in rows {
                var skillDict: [String: Any] = [
                    "id": record.manifest.id,
                    "version": record.manifest.version,
                    "name": record.manifest.name,
                    "manifestPath": record.manifestPath,
                    "installedProducts": record.installedProducts,
                    "enabledProducts": record.enabledProducts
                ]

                var modePairs: [String: String] = [:]
                for (product, mode) in record.lastInstallModeByProduct {
                    modePairs[product] = mode.rawValue
                }
                skillDict["installModes"] = modePairs

                skillsList.append(skillDict)
            }

            if let jsonData = try? JSONSerialization.data(withJSONObject: skillsList, options: .prettyPrinted),
               let jsonString = String(data: jsonData, encoding: .utf8)
            {
                print(jsonString)
            }
        } else {
            for record in rows {
                print("Skill: \(record.manifest.id) v\(record.manifest.version)")
                print("  Name: \(record.manifest.name)")
                print("  Manifest: \(record.manifestPath)")
                print("  Installed products: \(record.installedProducts.joined(separator: ", "))")
                print("  Enabled products: \(record.enabledProducts.joined(separator: ", "))")
                if !record.lastInstallModeByProduct.isEmpty {
                    let modePairs = record.lastInstallModeByProduct
                        .sorted { $0.key < $1.key }
                        .map { "\($0.key)=\($0.value.rawValue)" }
                        .joined(separator: ", ")
                    print("  Last install modes: \(modePairs)")
                }

                for productID in record.installedProducts {
                    if let adapter = try? adapterRegistry.adapter(for: productID) {
                        let productStatus = adapter.status(skillID: record.manifest.id)
                        print("  Product status [\(productID)]: installed=\(productStatus.isInstalled) enabled=\(productStatus.isEnabled) detail=\(productStatus.detail)")
                    }
                }
            }
        }
    }

    func remove(arguments: [String]) throws {
        guard let skillID = arguments.first else {
            throw SkillHubError.invalidManifest("Usage: remove <skill-id> [--purge]")
        }

        let purge = arguments.contains("--purge")
        try store.removeSkill(skillID: skillID)
        if purge {
            let stagedPath = stagedSkillPath(skillID: skillID)
            if FileManager.default.fileExists(atPath: stagedPath.path) {
                try FileManager.default.removeItem(at: stagedPath)
            }
        }

        print("Removed skill record \(skillID)\(purge ? " and purged staged files" : "")")
    }

    private func resolveAgentSkill(source: String) throws -> (SkillManifest, String) {
        if let githubTree = parseGitHubTreeURL(source) {
            let root = try cloneFromGit(sourceURL: githubTree.cloneURL, branch: githubTree.branch, preferredSubpath: githubTree.subpath, originalSource: source)
            return try loadAgentSkillFromDirectory(root, originalSource: source)
        }

        if source.hasPrefix("git@") || source.hasSuffix(".git") {
            let root = try cloneFromGit(sourceURL: source, branch: nil, preferredSubpath: nil, originalSource: source)
            return try loadAgentSkillFromDirectory(root, originalSource: source)
        }

        if let url = URL(string: source),
           let host = url.host,
           host.contains("github.com")
        {
            let root = try cloneFromGit(sourceURL: source, branch: nil, preferredSubpath: nil, originalSource: source)
            return try loadAgentSkillFromDirectory(root, originalSource: source)
        }

        if source.hasPrefix("http://") || source.hasPrefix("https://") {
            return try loadAgentSkillFromURL(source)
        }

        let localURL = Self.expandPath(source)
        var isDirectory: ObjCBool = false
        if FileManager.default.fileExists(atPath: localURL.path, isDirectory: &isDirectory), isDirectory.boolValue {
            return try loadAgentSkillFromDirectory(localURL, originalSource: source)
        }

        guard localURL.lastPathComponent.lowercased() == "skill.md" else {
            throw SkillHubError.invalidManifest("Source must be an Agent Skill directory containing SKILL.md or a SKILL.md file")
        }
        return try loadAgentSkillFromMarkdown(localURL)
    }

    private func loadAgentSkillFromURL(_ urlString: String) throws -> (SkillManifest, String) {
        guard let url = URL(string: urlString) else {
            throw SkillHubError.invalidManifest("Invalid URL: \(urlString)")
        }

        guard url.path.lowercased().hasSuffix("/skill.md") else {
            throw SkillHubError.invalidManifest("HTTP source must point to a raw SKILL.md file, or use a git/tree source")
        }

        print("Fetching \(urlString)...")
        let semaphore = DispatchSemaphore(value: 0)
        var resultData: Data?
        var resultError: Error?

        let task = URLSession.shared.dataTask(with: url) { data, _, error in
            resultData = data
            resultError = error
            semaphore.signal()
        }
        task.resume()
        semaphore.wait()

        if let error = resultError {
            throw SkillHubError.invalidManifest("Failed to fetch: \(error.localizedDescription)")
        }

        guard let data = resultData else {
            throw SkillHubError.invalidManifest("No data received from \(urlString)")
        }

        let inferredSkillDirectory = url.deletingLastPathComponent().lastPathComponent
        let tempRoot = FileManager.default.temporaryDirectory.appendingPathComponent("skillhub-fetch-\(UUID().uuidString)")
        let tempDir = tempRoot.appendingPathComponent(inferredSkillDirectory.isEmpty ? "imported-skill" : inferredSkillDirectory)
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        let skillMarkdownPath = tempDir.appendingPathComponent("SKILL.md")
        try data.write(to: skillMarkdownPath)

        print("Downloaded skill markdown to \(tempDir.path)")
        return try loadAgentSkillFromMarkdown(skillMarkdownPath)
    }

    private func cloneFromGit(sourceURL: String, branch: String?, preferredSubpath: String?, originalSource: String) throws -> URL {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("skillhub-git-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

        var cloneURL = sourceURL
        if sourceURL.hasPrefix("git@") {
            cloneURL = sourceURL.replacingOccurrences(of: ":", with: "/").replacingOccurrences(of: "git@", with: "https://")
        }

        if !cloneURL.hasSuffix(".git"), let url = URL(string: cloneURL), url.host?.contains("github.com") == true {
            cloneURL += ".git"
        }

        print("Cloning \(cloneURL)...")

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        var cloneArguments = ["clone", "--depth", "1"]
        if let branch, !branch.isEmpty {
            cloneArguments.append(contentsOf: ["--branch", branch, "--single-branch"])
        }
        cloneArguments.append(contentsOf: [cloneURL, tempDir.path])
        process.arguments = cloneArguments
        process.standardOutput = FileHandle.standardOutput
        process.standardError = FileHandle.standardError

        try process.run()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            throw SkillHubError.invalidManifest("Git clone failed for: \(originalSource)")
        }

        let searchRoot: URL
        if let preferredSubpath, !preferredSubpath.isEmpty {
            let candidate = tempDir.appendingPathComponent(preferredSubpath, isDirectory: true)
            var isDir: ObjCBool = false
            guard FileManager.default.fileExists(atPath: candidate.path, isDirectory: &isDir), isDir.boolValue else {
                throw SkillHubError.invalidManifest("Could not find skill directory in cloned repo: \(preferredSubpath)")
            }
            searchRoot = candidate
        } else {
            searchRoot = tempDir
        }

        print("Cloned source to \(tempDir.path)")
        return searchRoot
    }

    private func parseGitHubTreeURL(_ source: String) -> (cloneURL: String, branch: String, subpath: String)? {
        guard let url = URL(string: source),
              let host = url.host,
              host.contains("github.com")
        else {
            return nil
        }

        let parts = url.path.split(separator: "/", omittingEmptySubsequences: true).map(String.init)
        guard parts.count >= 5, parts[2] == "tree" else {
            return nil
        }

        let owner = parts[0]
        let repo = parts[1]
        let branch = parts[3]
        let subpath = parts.dropFirst(4).joined(separator: "/")
        let cloneURL = "https://github.com/\(owner)/\(repo).git"
        return (cloneURL, branch, subpath)
    }

    private func locateSkillMarkdown(in root: URL) throws -> URL {
        let preferredNames = ["SKILL.md", "skill.md"]
        let fm = FileManager.default

        for name in preferredNames {
            let candidate = root.appendingPathComponent(name)
            if fm.fileExists(atPath: candidate.path) {
                return candidate
            }
        }

        guard let enumerator = fm.enumerator(
            at: root,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else {
            throw SkillHubError.invalidManifest("Could not read skill directory: \(root.path)")
        }

        var matches: [URL] = []
        for case let fileURL as URL in enumerator {
            let name = fileURL.lastPathComponent
            guard preferredNames.contains(name) else {
                continue
            }

            matches.append(fileURL)
        }

        if matches.isEmpty {
            throw SkillHubError.invalidManifest("No SKILL.md found in source: \(root.path)")
        }

        if matches.count > 1 {
            let listed = matches.map(\.path).sorted().joined(separator: ", ")
            throw SkillHubError.invalidManifest("Multiple SKILL.md files found. Provide a specific skill directory (for GitHub use /tree/<branch>/<path>): \(listed)")
        }

        return matches[0]
    }

    private func loadAgentSkillFromDirectory(_ directory: URL, originalSource: String) throws -> (SkillManifest, String) {
        let skillMarkdown = try locateSkillMarkdown(in: directory)
        let loaded = try loadAgentSkillFromMarkdown(skillMarkdown)
        print("Resolved Agent Skill \(loaded.0.id) from \(originalSource)")
        return loaded
    }

    private func loadAgentSkillFromMarkdown(_ markdownURL: URL) throws -> (SkillManifest, String) {
        let markdown = try String(contentsOf: markdownURL, encoding: .utf8)
        let frontmatter = try parseFrontmatter(from: markdown)

        guard let skillNameRaw = frontmatter["name"], !skillNameRaw.isEmpty else {
            throw SkillHubError.invalidManifest("SKILL.md frontmatter requires non-empty 'name'")
        }
        guard let descriptionRaw = frontmatter["description"], !descriptionRaw.isEmpty else {
            throw SkillHubError.invalidManifest("SKILL.md frontmatter requires non-empty 'description'")
        }

        let skillName = skillNameRaw.trimmingCharacters(in: .whitespacesAndNewlines)
        let description = descriptionRaw.trimmingCharacters(in: .whitespacesAndNewlines)
        try validateAgentSkillName(skillName)
        if description.count > 1024 {
            throw SkillHubError.invalidManifest("SKILL.md frontmatter 'description' must be 1-1024 characters")
        }

        let expectedDirectoryName = markdownURL.deletingLastPathComponent().lastPathComponent
        if expectedDirectoryName != skillName {
            throw SkillHubError.invalidManifest("SKILL.md 'name' must match parent directory name. name=\(skillName), directory=\(expectedDirectoryName)")
        }

        let manifest = SkillManifest(
            id: skillName,
            name: skillName,
            version: "1.0.0",
            summary: description,
            entrypoint: markdownURL.lastPathComponent,
            tags: [],
            adapters: []
        )

        let manifestPath = markdownURL.deletingLastPathComponent().appendingPathComponent("skill.json")
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(manifest).write(to: manifestPath)
        return (manifest, manifestPath.path)
    }

    private func parseFrontmatter(from markdown: String) throws -> [String: String] {
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
                if parts.count == 2 {
                    let key = parts[0].trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                    let value = parts[1].trimmingCharacters(in: .whitespacesAndNewlines)
                        .trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))
                    if !key.isEmpty {
                        fields[key] = value
                    }
                }
            }
            index += 1
        }

        if !foundClosing {
            throw SkillHubError.invalidManifest("SKILL.md frontmatter must end with '---'")
        }

        return fields
    }

    private func validateAgentSkillName(_ skillName: String) throws {
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

    private func stageSkillInStore(skillID: String, sourceDirectory: URL) throws -> URL {
        let fileManager = FileManager.default

        guard fileManager.fileExists(atPath: sourceDirectory.path) else {
            throw SkillHubError.invalidManifest("Skill source directory missing: \(sourceDirectory.path)")
        }

        let skillStoreRoot = SkillHubPaths.defaultSkillsDirectory()
        try FileSystemUtils.ensureDirectoryExists(at: skillStoreRoot)
        let destination = skillStoreRoot.appendingPathComponent(skillID, isDirectory: true)

        let tempDestination = skillStoreRoot.appendingPathComponent(".\(skillID).staging-\(UUID().uuidString)", isDirectory: true)
        let backupURL = skillStoreRoot.appendingPathComponent(".\(skillID).backup-\(UUID().uuidString)", isDirectory: true)

        var shouldCleanupTemp = true
        defer {
            if shouldCleanupTemp, fileManager.fileExists(atPath: tempDestination.path) {
                try? fileManager.removeItem(at: tempDestination)
            }
        }

        try fileManager.copyItem(at: sourceDirectory, to: tempDestination)

        var hadExistingDestination = false
        do {
            try fileManager.moveItem(at: destination, to: backupURL)
            hadExistingDestination = true
        } catch let error as NSError {
            if !(error.domain == NSCocoaErrorDomain && error.code == NSFileNoSuchFileError) {
                throw error
            }
        }

        do {
            try fileManager.moveItem(at: tempDestination, to: destination)
            shouldCleanupTemp = false
            if hadExistingDestination, fileManager.fileExists(atPath: backupURL.path) {
                try? fileManager.removeItem(at: backupURL)
            }
        } catch {
            if hadExistingDestination,
               fileManager.fileExists(atPath: backupURL.path),
               !fileManager.fileExists(atPath: destination.path)
            {
                try? fileManager.moveItem(at: backupURL, to: destination)
            }
            throw error
        }

        return destination
    }

    private func stagedSkillPath(skillID: String) -> URL {
        SkillHubPaths.defaultSkillsDirectory().appendingPathComponent(skillID, isDirectory: true)
    }
}

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

        let (manifest, sourcePath) = try fetchOrCloneSkill(source: source)
        let manifestBytes = (try? Data(contentsOf: URL(fileURLWithPath: sourcePath))) ?? Data()
        let validationErrors = SchemaValidator.shared.validateManifestData(manifestBytes)
        if !validationErrors.isEmpty {
            throw SkillHubError.invalidManifest("Schema validation failed: \(validationErrors.joined(separator: ", "))")
        }

        try store.upsertSkill(manifest: manifest, manifestPath: sourcePath)
        print("Added skill \(manifest.id) from \(source)")
    }

    func stage(arguments: [String]) throws {
        guard let manifestPath = arguments.first else {
            throw SkillHubError.invalidManifest("Usage: stage <manifest-path>")
        }

        let manifestURL = Self.expandPath(manifestPath)
        let manifestData = try Data(contentsOf: manifestURL)
        let manifest = try JSONDecoder().decode(SkillManifest.self, from: manifestData)
        let sourceDirectory = manifestURL.deletingLastPathComponent()

        let validationErrors = SchemaValidator.shared.validateManifestData(manifestData)
        if !validationErrors.isEmpty {
            throw SkillHubError.invalidManifest("Schema validation failed: \(validationErrors.joined(separator: ", "))")
        }

        try store.upsertSkill(manifest: manifest, manifestPath: manifestURL.path)
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
            throw SkillHubError.invalidManifest("Usage: apply <manifest-path|skill-id> <product-id> [--mode auto|symlink|copy|configPatch]")
        }

        let firstArgument = arguments[0]
        let productID = arguments[1]

        let mode: InstallMode
        if let modeIndex = arguments.firstIndex(of: "--mode"), arguments.indices.contains(modeIndex + 1) {
            mode = try parseInstallMode(arguments[modeIndex + 1])
        } else {
            mode = .auto
        }

        let isManifestPathInput = firstArgument.lowercased().hasSuffix(".json")

        if isManifestPathInput {
            let manifestURL = Self.expandPath(firstArgument)
            let manifestData = try Data(contentsOf: manifestURL)
            let manifest = try JSONDecoder().decode(SkillManifest.self, from: manifestData)

            let validationErrors = SchemaValidator.shared.validateManifestData(manifestData)
            if !validationErrors.isEmpty {
                throw SkillHubError.invalidManifest("Schema validation failed: \(validationErrors.joined(separator: ", "))")
            }

            print("[1/5] Registering skill \(manifest.id) from \(manifestURL.path)")
            try store.upsertSkill(manifest: manifest, manifestPath: manifestURL.path)
        }

        let state = try store.loadState()
        let skillID = isManifestPathInput ? try skillIDFromManifestPath(firstArgument) : firstArgument
        guard let skillRecord = state.skills.first(where: { $0.manifest.id == skillID }) else {
            throw SkillHubError.invalidManifest("Skill not found: \(skillID)")
        }

        let manifestURL = isManifestPathInput
            ? Self.expandPath(firstArgument)
            : Self.expandPath(skillRecord.manifestPath)

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
                throw SkillHubError.invalidManifest("Skill \(skillID) is not installed for \(productID). Run: install \(skillID) \(productID) or apply <manifest-path|skill-id> \(productID)")
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

    private func fetchOrCloneSkill(source: String) throws -> (SkillManifest, String) {
        if source.hasPrefix("http://") || source.hasPrefix("https://") {
            return try fetchFromURL(source)
        }
        if source.hasPrefix("git@") || source.contains("github.com") {
            return try cloneFromGit(source)
        }

        let manifestURL = Self.expandPath(source)
        let manifestData = try Data(contentsOf: manifestURL)
        let manifest = try JSONDecoder().decode(SkillManifest.self, from: manifestData)
        return (manifest, manifestURL.path)
    }

    private func fetchFromURL(_ urlString: String) throws -> (SkillManifest, String) {
        guard let url = URL(string: urlString) else {
            throw SkillHubError.invalidManifest("Invalid URL: \(urlString)")
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

        let manifest = try JSONDecoder().decode(SkillManifest.self, from: data)

        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("skillhub-fetch-\(manifest.id)")
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        let manifestPath = tempDir.appendingPathComponent("skill.json")
        try data.write(to: manifestPath)

        print("Downloaded skill manifest to \(tempDir.path)")
        return (manifest, manifestPath.path)
    }

    private func cloneFromGit(_ gitURL: String) throws -> (SkillManifest, String) {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("skillhub-git-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

        var fullURL = gitURL
        if gitURL.hasPrefix("git@") {
            fullURL = gitURL.replacingOccurrences(of: ":", with: "/").replacingOccurrences(of: "git@", with: "https://")
        }

        print("Cloning \(fullURL)...")

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        process.arguments = ["clone", "--depth", "1", fullURL, tempDir.path]
        process.standardOutput = FileHandle.standardOutput
        process.standardError = FileHandle.standardError

        try process.run()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            throw SkillHubError.invalidManifest("Git clone failed for: \(gitURL)")
        }

        let contents = try FileManager.default.contentsOfDirectory(at: tempDir, includingPropertiesForKeys: nil)
        var manifestURL: URL?
        for item in contents {
            if item.lastPathComponent == "skill.json" {
                manifestURL = item
                break
            }
            if let subContents = try? FileManager.default.contentsOfDirectory(at: item, includingPropertiesForKeys: nil) {
                for subItem in subContents where subItem.lastPathComponent == "skill.json" {
                    manifestURL = subItem
                    break
                }
            }
            if manifestURL != nil {
                break
            }
        }

        guard let manifestFile = manifestURL else {
            throw SkillHubError.invalidManifest("No skill.json found in git repo: \(gitURL)")
        }

        let manifestData = try Data(contentsOf: manifestFile)
        let manifest = try JSONDecoder().decode(SkillManifest.self, from: manifestData)

        print("Cloned skill \(manifest.id) to \(tempDir.path)")
        return (manifest, manifestFile.path)
    }

    private func stageSkillInStore(skillID: String, sourceDirectory: URL) throws -> URL {
        guard FileManager.default.fileExists(atPath: sourceDirectory.path) else {
            throw SkillHubError.invalidManifest("Skill source directory missing: \(sourceDirectory.path)")
        }

        let skillStoreRoot = SkillHubPaths.defaultSkillsDirectory()
        try FileSystemUtils.ensureDirectoryExists(at: skillStoreRoot)
        let destination = skillStoreRoot.appendingPathComponent(skillID, isDirectory: true)
        try FileSystemUtils.copyItem(from: sourceDirectory, to: destination)
        return destination
    }

    private func stagedSkillPath(skillID: String) -> URL {
        SkillHubPaths.defaultSkillsDirectory().appendingPathComponent(skillID, isDirectory: true)
    }

    private func skillIDFromManifestPath(_ manifestPath: String) throws -> String {
        let manifestURL = Self.expandPath(manifestPath)
        let manifestData = try Data(contentsOf: manifestURL)
        return try JSONDecoder().decode(SkillManifest.self, from: manifestData).id
    }
}

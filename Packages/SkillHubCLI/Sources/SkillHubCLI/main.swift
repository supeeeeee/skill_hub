import Foundation
import SkillHubCore

// MARK: - Schema Validation

struct SchemaValidator: @unchecked Sendable {
    static let shared = SchemaValidator()

    private let schema: [String: Any]?

    private init() {
        self.schema = Self.loadSchema()
    }

    private static func loadSchema() -> [String: Any]? {
        let possibleURLs: [URL] = [
            URL(fileURLWithPath: "../docs/skill.schema.json"),
            URL(fileURLWithPath: "../../docs/skill.schema.json"),
            URL(fileURLWithPath: "docs/skill.schema.json"),
            URL(fileURLWithPath: FileManager.default.currentDirectoryPath).appendingPathComponent("docs/skill.schema.json")
        ]

        for url in possibleURLs {
            if let data = try? Data(contentsOf: url),
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                return json
            }
        }
        return nil
    }

    /// Validate raw manifest JSON bytes against docs/skill.schema.json.
    /// Enforces required keys and (when `additionalProperties=false`) rejects unknown keys.
    func validateManifestData(_ data: Data) -> [String] {
        guard let schema else {
            // Schema not found; fall back to decoding validation
            if let manifest = try? JSONDecoder().decode(SkillManifest.self, from: data) {
                return validateManifest(manifest)
            }
            return ["Unable to load docs/skill.schema.json and failed to decode manifest JSON"]
        }

        guard let manifestObj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return ["Manifest is not a valid JSON object"]
        }

        var errors: [String] = []

        let requiredKeys = (schema["required"] as? [String]) ?? []
        for key in requiredKeys {
            if manifestObj[key] == nil {
                errors.append("Missing required field: \(key)")
            } else if let s = manifestObj[key] as? String, s.isEmpty {
                errors.append("Required field is empty: \(key)")
            }
        }

        let properties = (schema["properties"] as? [String: Any]) ?? [:]
        if let additional = schema["additionalProperties"] as? Bool, additional == false {
            for key in manifestObj.keys where properties[key] == nil {
                errors.append("Unknown top-level field (additionalProperties=false): \(key)")
            }
        }

        // Validate adapters items if present
        if let adapters = manifestObj["adapters"] as? [Any],
           let adaptersSchema = (properties["adapters"] as? [String: Any]),
           let itemsSchema = adaptersSchema["items"] as? [String: Any] {

            let adapterRequired = (itemsSchema["required"] as? [String]) ?? []
            let adapterProps = (itemsSchema["properties"] as? [String: Any]) ?? [:]
            let adapterAdditional = (itemsSchema["additionalProperties"] as? Bool) ?? true

            for (idx, item) in adapters.enumerated() {
                guard let obj = item as? [String: Any] else {
                    errors.append("adapters[\(idx)] is not an object")
                    continue
                }
                for key in adapterRequired {
                    if obj[key] == nil {
                        errors.append("adapters[\(idx)] missing required field: \(key)")
                    } else if let s = obj[key] as? String, s.isEmpty {
                        errors.append("adapters[\(idx)] required field is empty: \(key)")
                    }
                }
                if adapterAdditional == false {
                    for key in obj.keys where adapterProps[key] == nil {
                        errors.append("adapters[\(idx)] unknown field (additionalProperties=false): \(key)")
                    }
                }
            }
        }

        return errors
    }

    func validateManifest(_ manifest: SkillManifest) -> [String] {
        var errors: [String] = []
        if manifest.id.isEmpty { errors.append("Missing or empty required field: id") }
        if manifest.name.isEmpty { errors.append("Missing or empty required field: name") }
        if manifest.version.isEmpty { errors.append("Missing or empty required field: version") }
        if manifest.summary.isEmpty { errors.append("Missing or empty required field: summary") }
        for (index, adapter) in manifest.adapters.enumerated() {
            if adapter.productID.isEmpty {
                errors.append("adapters[\(index)]: missing required field 'productID'")
            }
        }
        return errors
    }

    /// Back-compat convenience used by the CLI.
    func validate(_ manifest: SkillManifest) -> [String] {
        validateManifest(manifest)
    }
}

// MARK: - Readiness Report

struct ReadinessReport: Codable {
    let timestamp: Date
    let version: String
    let adapters: [AdapterReadiness]
    let overallReady: Bool
    
    struct AdapterReadiness: Codable {
        let id: String
        let name: String
        let detected: Bool
        let reason: String
        let supportedModes: [String]
    }
}

struct CLI {
    let store: JSONSkillStore
    let adapterRegistry: AdapterRegistry

    init(statePath: String? = nil) {
        let stateURL = statePath.map(Self.expandPath) ?? SkillHubPaths.defaultStateFile()
        self.store = JSONSkillStore(stateFileURL: stateURL)
        self.adapterRegistry = AdapterRegistry(adapters: [
            OpenClawAdapter(),
            OpenCodeAdapter(),
            ClaudeCodeAdapter(),
            CodexAdapter(),
            CursorAdapter()
        ])
    }

    func run(arguments: [String]) throws {
        // Check for global --json flag
        let jsonOutput = arguments.contains("--json")
        var cmdArgs = arguments.filter { $0 != "--json" }
        
        guard let command = cmdArgs.first else {
            printUsage()
            return
        }

        switch command {
        case "products":
            try products()
        case "detect", "doctor":
            try detect(json: jsonOutput)
        case "skills":
            try skills()
        case "add":
            try add(arguments: Array(cmdArgs.dropFirst()))
        case "stage":
            try stage(arguments: Array(cmdArgs.dropFirst()))
        case "unstage":
            try unstage(arguments: Array(cmdArgs.dropFirst()))
        case "install":
            try install(arguments: Array(cmdArgs.dropFirst()))
        case "apply", "setup":
            try apply(arguments: Array(cmdArgs.dropFirst()))
        case "uninstall":
            try uninstall(arguments: Array(cmdArgs.dropFirst()))
        case "enable":
            try toggle(arguments: Array(cmdArgs.dropFirst()), enabled: true)
        case "disable":
            try toggle(arguments: Array(cmdArgs.dropFirst()), enabled: false)
        case "remove":
            try remove(arguments: Array(cmdArgs.dropFirst()))
        case "status":
            try status(arguments: Array(cmdArgs.dropFirst()))
        case "help", "-h", "--help":
            printUsage()
        default:
            throw SkillHubError.invalidManifest("Unknown command: \(command)")
        }
    }

    private func products() throws {
        for adapter in adapterRegistry.all() {
            let detection = adapter.detect()
            let supportedModes = adapter.supportedInstallModes.map(\.rawValue).joined(separator: ", ")
            print("\(adapter.id) (\(adapter.name)) - \(detection.isDetected ? "detected" : "not detected") - \(detection.reason) - modes=[\(supportedModes)]")
        }
    }

    private func detect(json: Bool = false) throws {
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

    private func skills() throws {
        let state = try store.loadState()
        if state.skills.isEmpty {
            print("No skills registered.")
            return
        }

        for record in state.skills {
            print("\(record.manifest.id) v\(record.manifest.version) - \(record.manifest.name)")
        }
    }

    private func add(arguments: [String]) throws {
        guard let source = arguments.first else {
            throw SkillHubError.invalidManifest("Usage: add <source>")
        }

        let (manifest, sourcePath) = try fetchOrCloneSkill(source: source)

        // Validate against schema (docs/skill.schema.json)
        let manifestBytes = (try? Data(contentsOf: URL(fileURLWithPath: sourcePath))) ?? Data()
        let validationErrors = SchemaValidator.shared.validateManifestData(manifestBytes)
        if !validationErrors.isEmpty {
            throw SkillHubError.invalidManifest("Schema validation failed: \(validationErrors.joined(separator: ", "))")
        }

        try store.upsertSkill(manifest: manifest, manifestPath: sourcePath)
        print("Added skill \(manifest.id) from \(source)")
    }

    // MARK: - Remote Fetch & Git Clone

    private func fetchOrCloneSkill(source: String) throws -> (SkillManifest, String) {
        if source.hasPrefix("http://") || source.hasPrefix("https://") {
            return try fetchFromURL(source)
        } else if source.hasPrefix("git@") || source.contains("github.com") {
            return try cloneFromGit(source)
        } else {
            // Local file
            let manifestURL = Self.expandPath(source)
            let manifestData = try Data(contentsOf: manifestURL)
            let manifest = try JSONDecoder().decode(SkillManifest.self, from: manifestData)
            return (manifest, manifestURL.path)
        }
    }

    private func fetchFromURL(_ urlString: String) throws -> (SkillManifest, String) {
        guard let url = URL(string: urlString) else {
            throw SkillHubError.invalidManifest("Invalid URL: \(urlString)")
        }

        print("Fetching \(urlString)...")
        let semaphore = DispatchSemaphore(value: 0)
        var resultData: Data?
        var resultError: Error?

        let task = URLSession.shared.dataTask(with: url) { data, response, error in
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

        // Save to temp directory
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

        // Convert GitHub shorthand to full URL if needed
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

        // Find skill.json in cloned repo
        let contents = try FileManager.default.contentsOfDirectory(at: tempDir, includingPropertiesForKeys: nil)
        var manifestURL: URL?
        for item in contents {
            if item.lastPathComponent == "skill.json" {
                manifestURL = item
                break
            }
            // Check subdirectories
            if let subContents = try? FileManager.default.contentsOfDirectory(at: item, includingPropertiesForKeys: nil) {
                for subItem in subContents where subItem.lastPathComponent == "skill.json" {
                    manifestURL = subItem
                    break
                }
            }
            if manifestURL != nil { break }
        }

        guard let manifestFile = manifestURL else {
            throw SkillHubError.invalidManifest("No skill.json found in git repo: \(gitURL)")
        }

        let manifestData = try Data(contentsOf: manifestFile)
        let manifest = try JSONDecoder().decode(SkillManifest.self, from: manifestData)

        print("Cloned skill \(manifest.id) to \(tempDir.path)")
        return (manifest, manifestFile.path)
    }

    private func stage(arguments: [String]) throws {
        guard let manifestPath = arguments.first else {
            throw SkillHubError.invalidManifest("Usage: stage <manifest-path>")
        }

        let manifestURL = Self.expandPath(manifestPath)
        let manifestData = try Data(contentsOf: manifestURL)
        let manifest = try JSONDecoder().decode(SkillManifest.self, from: manifestData)
        let sourceDirectory = manifestURL.deletingLastPathComponent()

        // Validate against schema (docs/skill.schema.json)
        let validationErrors = SchemaValidator.shared.validateManifestData(manifestData)
        if !validationErrors.isEmpty {
            throw SkillHubError.invalidManifest("Schema validation failed: \(validationErrors.joined(separator: ", "))")
        }

        try store.upsertSkill(manifest: manifest, manifestPath: manifestURL.path)
        let stagedPath = try stageSkillInStore(skillID: manifest.id, sourceDirectory: sourceDirectory)
        print("Staged \(manifest.id) at \(stagedPath.path)")
    }

    private func unstage(arguments: [String]) throws {
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

    private func install(arguments: [String]) throws {
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

    private func apply(arguments: [String]) throws {
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
            
            // Validate against schema (docs/skill.schema.json)
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

    private func uninstall(arguments: [String]) throws {
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

    private func toggle(arguments: [String], enabled: Bool) throws {
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

    private func status(arguments: [String], json: Bool = false) throws {
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
               let jsonString = String(data: jsonData, encoding: .utf8) {
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

    private func remove(arguments: [String]) throws {
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

    private func printUsage() {
        print("""
        skillhub <command> [args]

        Commands:
          products                        List known product adapters
          detect | doctor                 Show detection status for known products [--json]
          skills                          List registered skills
          add <source>                    Register or update a skill from skill.json (local path, URL, or git repo)
          stage <skill.json-path>         Register and copy skill directory into ~/.skillhub/skills/<id>
          unstage <skill-id>              Remove staged skill directory from ~/.skillhub/skills
          install <skill-id> <product-id> [--mode auto|symlink|copy|configPatch]
                                             Validate staged skill and record install mode
          apply <skill.json|skill-id> <product-id> [--mode auto|symlink|copy|configPatch]
                                            Register/stage/install/enable in one command
          setup <skill.json|skill-id> <product-id> [--mode auto|symlink|copy|configPatch]
                                            Register/stage/install/enable in one command
          uninstall <skill-id> <product-id>
                                             Disable skill and remove product installation state
          enable <skill-id> <product-id>  Enable a skill for a product
          disable <skill-id> <product-id> Disable a skill for a product
          remove <skill-id> [--purge]     Remove skill state; optionally purge staged files
          status [skill-id]               Show state for one or all skills

        Optional flags:
          --state <path>                  Override state file path
          --json                          Output as JSON (for detect/doctor commands)
        """)
    }

    private static func expandPath(_ input: String) -> URL {
        if input.hasPrefix("~/") {
            let home = FileManager.default.homeDirectoryForCurrentUser.path
            return URL(fileURLWithPath: input.replacingOccurrences(of: "~", with: home))
        }
        return URL(fileURLWithPath: input)
    }

    private func parseInstallMode(_ raw: String) throws -> InstallMode {
        if raw == "config-patch" {
            return .configPatch
        }
        guard let parsed = InstallMode(rawValue: raw) else {
            throw SkillHubError.unsupportedInstallMode(raw)
        }
        return parsed
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

func extractStatePath(args: inout [String]) -> String? {
    guard let stateIndex = args.firstIndex(of: "--state"), args.indices.contains(stateIndex + 1) else {
        return nil
    }
    let statePath = args[stateIndex + 1]
    args.removeSubrange(stateIndex...(stateIndex + 1))
    return statePath
}

do {
    var args = Array(CommandLine.arguments.dropFirst())
    let statePath = extractStatePath(args: &args)
    try CLI(statePath: statePath).run(arguments: args)
} catch {
    fputs("Error: \(error)\n", stderr)
    exit(1)
}

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
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
            {
                return json
            }
        }
        return nil
    }

    func validateManifestData(_ data: Data) -> [String] {
        guard let schema else {
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
            } else if let value = manifestObj[key] as? String, value.isEmpty {
                errors.append("Required field is empty: \(key)")
            }
        }

        let properties = (schema["properties"] as? [String: Any]) ?? [:]
        if let additional = schema["additionalProperties"] as? Bool, additional == false {
            for key in manifestObj.keys where properties[key] == nil {
                errors.append("Unknown top-level field (additionalProperties=false): \(key)")
            }
        }

        if let adapters = manifestObj["adapters"] as? [Any],
           let adaptersSchema = properties["adapters"] as? [String: Any],
           let itemsSchema = adaptersSchema["items"] as? [String: Any]
        {
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
                    } else if let value = obj[key] as? String, value.isEmpty {
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
        for (index, adapter) in manifest.adapters.enumerated() where adapter.productID.isEmpty {
            errors.append("adapters[\(index)]: missing required field 'productID'")
        }
        return errors
    }

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

protocol CLICommandHandler {
    var names: [String] { get }
    func execute(cli: CLI, arguments: [String], jsonOutput: Bool) throws
}

extension CLICommandHandler {
    func matches(_ command: String) -> Bool {
        names.contains(command)
    }
}

struct CLI {
    let store: JSONSkillStore
    let adapterRegistry: AdapterRegistry
    private let commandHandlers: [any CLICommandHandler]

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
        self.commandHandlers = [
            ProductsCommandHandler(),
            DetectCommandHandler(),
            SkillsCommandHandler(),
            AddCommandHandler(),
            StageCommandHandler(),
            UnstageCommandHandler(),
            InstallCommandHandler(),
            ApplyCommandHandler(),
            UninstallCommandHandler(),
            EnableCommandHandler(),
            DisableCommandHandler(),
            RemoveCommandHandler(),
            StatusCommandHandler(),
            HelpCommandHandler()
        ]
    }

    func run(arguments: [String]) throws {
        let jsonOutput = arguments.contains("--json")
        let cmdArgs = arguments.filter { $0 != "--json" }

        guard let command = cmdArgs.first else {
            printUsage()
            return
        }

        guard let handler = commandHandlers.first(where: { $0.matches(command) }) else {
            throw SkillHubError.invalidManifest("Unknown command: \(command)")
        }

        try handler.execute(cli: self, arguments: Array(cmdArgs.dropFirst()), jsonOutput: jsonOutput)
    }

    func printUsage() {
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

    static func expandPath(_ input: String) -> URL {
        if input.hasPrefix("~/") {
            let home = FileManager.default.homeDirectoryForCurrentUser.path
            return URL(fileURLWithPath: input.replacingOccurrences(of: "~", with: home))
        }
        return URL(fileURLWithPath: input)
    }

    func parseInstallMode(_ raw: String) throws -> InstallMode {
        if raw == "config-patch" {
            return .configPatch
        }
        guard let parsed = InstallMode(rawValue: raw) else {
            throw SkillHubError.unsupportedInstallMode(raw)
        }
        return parsed
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

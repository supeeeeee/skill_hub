import Foundation
import SkillHubCore

private struct AppCustomProductAdapter: ProductAdapter {
    let config: CustomProductConfig
    let supportedInstallModes: [InstallMode] = [.copy]

    var id: String { config.id }
    var name: String { config.name }

    private var skillStoreRoot: URL {
        SkillHubPaths.defaultSkillsDirectory()
    }

    func skillsDirectory() -> URL {
        URL(fileURLWithPath: config.skillsDirectoryPath, isDirectory: true)
    }

    func detect() -> ProductDetectionResult {
        if FileManager.default.fileExists(atPath: skillsDirectory().path) {
            return ProductDetectionResult(isDetected: true, reason: "Detected filesystem footprint at \(skillsDirectory().path)")
        }

        if let executable = detectExecutable(named: config.executableNames) {
            return ProductDetectionResult(isDetected: true, reason: "Detected executable at \(executable)")
        }

        if config.executableNames.isEmpty {
            return ProductDetectionResult(isDetected: false, reason: "Missing \(skillsDirectory().path)")
        }

        return ProductDetectionResult(
            isDetected: false,
            reason: "Missing \(skillsDirectory().path) and no executable found: \(config.executableNames.joined(separator: ", "))"
        )
    }

    func install(skill: SkillManifest, mode: InstallMode) throws -> InstallMode {
        let resolvedMode = try resolveInstallMode(mode)
        let stagedSkillPath = skillStoreRoot.appendingPathComponent(skill.id, isDirectory: true)
        guard FileManager.default.fileExists(atPath: stagedSkillPath.path) else {
            throw SkillHubError.invalidManifest("Skill not staged in \(stagedSkillPath.path)")
        }

        try FileSystemUtils.ensureDirectoryExists(at: skillsDirectory())
        return resolvedMode
    }

    func enable(skillID: String, mode: InstallMode) throws {
        let source = skillStoreRoot.appendingPathComponent(skillID, isDirectory: true)
        guard FileManager.default.fileExists(atPath: source.path) else {
            throw SkillHubError.invalidManifest("Skill not staged in \(source.path)")
        }

        try FileSystemUtils.ensureDirectoryExists(at: skillsDirectory())
        let destination = skillsDirectory().appendingPathComponent(skillID, isDirectory: true)
        _ = try FileSystemUtils.backupIfExists(at: destination, productID: id, skillID: skillID)
        _ = try resolveInstallMode(mode)
        try FileSystemUtils.copyItem(from: source, to: destination)
    }

    func disable(skillID: String) throws {
        let destination = skillsDirectory().appendingPathComponent(skillID, isDirectory: true)
        if FileManager.default.fileExists(atPath: destination.path) {
            try FileManager.default.removeItem(at: destination)
        }
    }

    func status(skillID: String) -> ProductSkillStatus {
        let staged = skillStoreRoot.appendingPathComponent(skillID, isDirectory: true)
        let enabled = skillsDirectory().appendingPathComponent(skillID, isDirectory: true)
        let isInstalled = FileManager.default.fileExists(atPath: staged.path)
        let isEnabled = FileManager.default.fileExists(atPath: enabled.path)
        let detail = isEnabled
            ? "Enabled via copied files at \(enabled.path)"
            : "No enabled files at \(enabled.path)"

        return ProductSkillStatus(isInstalled: isInstalled, isEnabled: isEnabled, detail: detail)
    }

    private func detectExecutable(named names: [String]) -> String? {
        let envPaths = (ProcessInfo.processInfo.environment["PATH"] ?? "")
            .split(separator: ":")
            .map(String.init)

        for binary in names where !binary.isEmpty {
            if binary.contains("/") {
                let expanded = (binary as NSString).expandingTildeInPath
                if FileManager.default.isExecutableFile(atPath: expanded) {
                    return expanded
                }
                continue
            }

            for root in envPaths where !root.isEmpty {
                let candidate = URL(fileURLWithPath: root).appendingPathComponent(binary).path
                if FileManager.default.isExecutableFile(atPath: candidate) {
                    return candidate
                }
            }
        }

        return nil
    }
}

final class SkillService {
    struct UpdateCheckResult {
        let checkedGitSkills: Int
        let updatedSkillNames: [String]
        let skippedNonGitSkills: Int
        let unavailableSkills: [String]
    }

    private struct SkillHubCommand {
        let executablePath: String
        let prefixArguments: [String]
        let displayName: String
    }

    let skillStore: SkillStore
    private(set) var adapterRegistry: AdapterRegistry

    init(
        skillStore: SkillStore = JSONSkillStore(),
        adapterRegistry: AdapterRegistry = SkillService.makeAdapterRegistry()
    ) {
        self.skillStore = skillStore
        self.adapterRegistry = adapterRegistry
    }

    func loadSkills() throws -> [InstalledSkillRecord] {
        try skillStore.loadState().skills
    }

    func loadProducts() -> [Product] {
        reloadAdapterRegistry()

        let cfg = SkillHubConfig.load()
        let state = (try? skillStore.loadState()) ?? SkillHubState()
        let customProductsByID = Dictionary(uniqueKeysWithValues: cfg.customProducts.map { ($0.id, $0) })

        return adapterRegistry.all().map { adapter in
            let detection = adapter.detect()
            let status: ProductStatus = detection.isDetected ? .active : .notInstalled
            let customProduct = customProductsByID[adapter.id]

            return Product(
                id: adapter.id,
                name: adapter.name,
                iconName: iconName(for: adapter.id, customIconName: customProduct?.iconName),
                description: detection.reason,
                status: status,
                health: .unknown,
                supportedModes: adapter.supportedInstallModes,
                customSkillsPath: cfg.productSkillsDirectoryOverrides[adapter.id],
                customConfigPath: state.productConfigFilePathOverrides[adapter.id],
                isCustom: customProduct != nil
            )
        }
    }

    func addCustomProduct(
        name: String,
        id: String,
        skillsDirectoryPath: String,
        executableNamesRaw: String,
        iconName: String?,
        configFilePath: String?
    ) throws {
        let normalizedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedName.isEmpty else {
            throw SkillHubError.invalidManifest("Product name cannot be empty")
        }

        let normalizedID = normalizeProductID(id)
        guard !normalizedID.isEmpty else {
            throw SkillHubError.invalidManifest("Product ID cannot be empty")
        }

        guard isValidProductID(normalizedID) else {
            throw SkillHubError.invalidManifest("Product ID can only contain lowercase letters, digits, '-' and '_'")
        }

        let normalizedSkillsPath = (skillsDirectoryPath as NSString)
            .expandingTildeInPath
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard normalizedSkillsPath.hasPrefix("/") else {
            throw SkillHubError.invalidManifest("Skills directory path must be an absolute path")
        }

        let executableNames = executableNamesRaw
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        let normalizedConfigPath: String?
        if let rawConfigPath = configFilePath {
            let trimmedConfig = (rawConfigPath as NSString)
                .expandingTildeInPath
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmedConfig.isEmpty {
                normalizedConfigPath = nil
            } else {
                guard trimmedConfig.hasPrefix("/") else {
                    throw SkillHubError.invalidManifest("Config file path must be an absolute path")
                }
                normalizedConfigPath = trimmedConfig
            }
        } else {
            normalizedConfigPath = nil
        }

        var cfg = SkillHubConfig.load()
        let builtInIDs = Set(Self.builtInAdapters().map(\.id))

        if builtInIDs.contains(normalizedID) {
            throw SkillHubError.invalidManifest("Product ID '\(normalizedID)' conflicts with a built-in product")
        }

        if cfg.customProducts.contains(where: { $0.id == normalizedID }) {
            throw SkillHubError.invalidManifest("Product ID '\(normalizedID)' already exists")
        }

        cfg.customProducts.append(
            CustomProductConfig(
                id: normalizedID,
                name: normalizedName,
                skillsDirectoryPath: normalizedSkillsPath,
                executableNames: executableNames,
                iconName: iconName?.trimmingCharacters(in: .whitespacesAndNewlines)
            )
        )
        try cfg.save()
        try skillStore.setProductConfigPath(productID: normalizedID, configPath: normalizedConfigPath)
        reloadAdapterRegistry()
    }

    func removeCustomProduct(productID: String) throws {
        let normalizedID = normalizeProductID(productID)
        var cfg = SkillHubConfig.load()
        let beforeCount = cfg.customProducts.count
        cfg.customProducts.removeAll { $0.id == normalizedID }

        guard cfg.customProducts.count != beforeCount else {
            throw SkillHubError.invalidManifest("Custom product '\(normalizedID)' not found")
        }

        cfg.productSkillsDirectoryOverrides.removeValue(forKey: normalizedID)
        try cfg.save()

        var state = try skillStore.loadState()
        state.productConfigFilePathOverrides.removeValue(forKey: normalizedID)
        for index in state.skills.indices {
            state.skills[index].installedProducts.removeAll { $0 == normalizedID }
            state.skills[index].enabledProducts.removeAll { $0 == normalizedID }
            state.skills[index].lastInstallModeByProduct.removeValue(forKey: normalizedID)
        }
        try skillStore.saveState(state)

        reloadAdapterRegistry()
    }

    func reconcileInstalledSkillsFromProducts(
        products: [Product],
        currentSkills: [InstalledSkillRecord]
    ) throws -> Int {
        var updatedCount = 0

        for product in products {
            let adapter = try adapterRegistry.adapter(for: product.id)
            let installedSkillIDs = scanInstalledSkillIDs(at: adapter.skillsDirectory())
            if installedSkillIDs.isEmpty {
                continue
            }

            for skill in currentSkills where installedSkillIDs.contains(skill.manifest.id) {
                let isInstalled = skill.installedProducts.contains(product.id)
                let isEnabled = skill.enabledProducts.contains(product.id)
                let mode = skill.lastInstallModeByProduct[product.id] ?? .unknown

                if isInstalled && isEnabled && mode == .copy {
                    continue
                }

                try skillStore.markInstalled(skillID: skill.manifest.id, productID: product.id, installMode: .copy)
                try skillStore.setEnabled(skillID: skill.manifest.id, productID: product.id, enabled: true)
                updatedCount += 1
            }
        }

        return updatedCount
    }

    func setProductConfigPath(productID: String, rawPath: String) throws {
        let trimmed = rawPath.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty && !trimmed.hasPrefix("/") {
            throw SkillHubError.invalidManifest("Config path must be an absolute path")
        }

        try skillStore.setProductConfigPath(productID: productID, configPath: trimmed.isEmpty ? nil : trimmed)
    }

    func importSkill(at url: URL) throws -> SkillManifest {
        let sourcePath = url.standardizedFileURL.path
        let manifest: SkillManifest

        var isDirectory: ObjCBool = false
        if FileManager.default.fileExists(atPath: sourcePath, isDirectory: &isDirectory), isDirectory.boolValue {
            manifest = try AgentSkillLoader.loadFromDirectory(URL(fileURLWithPath: sourcePath)).manifest
        } else {
            manifest = try AgentSkillLoader.loadManifest(from: URL(fileURLWithPath: sourcePath))
        }

        try runSkillHub(arguments: ["add", sourcePath], action: "register skill")
        return manifest
    }

    func registerSkill(from source: String) throws {
        try runSkillHub(arguments: ["add", source], action: "register skill")
    }

    func installSkill(
        manifest: SkillManifest,
        productID: String,
        mode: InstallMode,
        currentSkills: [InstalledSkillRecord]
    ) throws {
        guard let skillRecord = currentSkills.first(where: { $0.manifest.id == manifest.id }) else {
            throw SkillHubError.invalidManifest("Skill record not found for \(manifest.name)")
        }

        let sourcePath = URL(fileURLWithPath: skillRecord.manifestPath).deletingLastPathComponent()
        let destPath = SkillHubPaths.defaultSkillsDirectory().appendingPathComponent(manifest.id)

        if sourcePath.standardizedFileURL != destPath.standardizedFileURL {
            try FileSystemUtils.ensureDirectoryExists(at: SkillHubPaths.defaultSkillsDirectory())
            try FileSystemUtils.copyItem(from: sourcePath, to: destPath)
        }

        let stagedManifestPath = destPath.appendingPathComponent("SKILL.md").path
        try skillStore.upsertSkill(
            manifest: manifest,
            manifestPath: stagedManifestPath,
            manifestSource: skillRecord.manifestSource
        )

        let adapter = try adapterRegistry.adapter(for: productID)
        let finalMode = try adapter.resolveInstallMode(mode)
        try adapter.enable(skillID: manifest.id, mode: finalMode)
        try skillStore.markInstalled(skillID: manifest.id, productID: productID, installMode: finalMode)
        try skillStore.setEnabled(skillID: manifest.id, productID: productID, enabled: true)
    }

    func uninstallSkill(manifest: SkillManifest, productID: String) throws {
        let adapter = try adapterRegistry.adapter(for: productID)
        try adapter.disable(skillID: manifest.id)
        try skillStore.markUninstalled(skillID: manifest.id, productID: productID)
    }

    func removeSkillFromHub(skillID: String) throws {
        try runSkillHub(arguments: ["remove", skillID, "--purge"], action: "remove skill")
    }

    func setSkillEnabled(
        manifest: SkillManifest,
        productID: String,
        enabled: Bool,
        currentSkills: [InstalledSkillRecord]
    ) throws {
        if enabled {
            if let skillRecord = currentSkills.first(where: { $0.manifest.id == manifest.id }),
               let mode = skillRecord.lastInstallModeByProduct[productID] {
                let adapter = try adapterRegistry.adapter(for: productID)
                try adapter.enable(skillID: manifest.id, mode: mode)
                try skillStore.setEnabled(skillID: manifest.id, productID: productID, enabled: true)
                return
            }

            try installSkill(
                manifest: manifest,
                productID: productID,
                mode: .copy,
                currentSkills: currentSkills
            )
            return
        }

        let adapter = try adapterRegistry.adapter(for: productID)
        if let skillRecord = currentSkills.first(where: { $0.manifest.id == manifest.id }),
           skillRecord.lastInstallModeByProduct[productID] != nil {
            try adapter.disable(skillID: manifest.id)
            try skillStore.setEnabled(skillID: manifest.id, productID: productID, enabled: false)
        } else {
            throw SkillHubError.invalidManifest("Skill \(manifest.name) is not installed for \(productID)")
        }

    }

    func acquireSkill(manifest: SkillManifest, fromProduct productID: String, skillsPath: String) throws {
        let rootURL = URL(fileURLWithPath: expandedPath(skillsPath)).standardizedFileURL
        let fm = Foundation.FileManager()

        var isRootDirectory: ObjCBool = false
        guard fm.fileExists(atPath: rootURL.path, isDirectory: &isRootDirectory), isRootDirectory.boolValue else {
            throw SkillHubError.invalidManifest("Skills directory does not exist or is not a directory: \(rootURL.path)")
        }

        guard fm.isReadableFile(atPath: rootURL.path) else {
            throw SkillHubError.invalidManifest("Skills directory is not readable: \(rootURL.path)")
        }

        var sourceFolder: URL?
        var manifestFile: URL?

        if let contents = try? fm.contentsOfDirectory(
            at: rootURL,
            includingPropertiesForKeys: [],
            options: Foundation.FileManager.DirectoryEnumerationOptions.skipsHiddenFiles
        ) {
            for folderURL in contents {
                var isDirectory: ObjCBool = false
                guard fm.fileExists(atPath: folderURL.path, isDirectory: &isDirectory), isDirectory.boolValue else {
                    continue
                }

                if let loaded = try? AgentSkillLoader.loadFromDirectory(folderURL), loaded.manifest.id == manifest.id {
                    sourceFolder = folderURL
                    manifestFile = loaded.markdownPath
                    break
                }

                if sourceFolder != nil {
                    break
                }
            }
        }

        guard let source = sourceFolder, let manifestPath = manifestFile else {
            throw SkillHubError.invalidManifest("Could not find source folder for skill \(manifest.id) in \(skillsPath)")
        }

        try ensureSkillHubDirectoryAccess()

        // Use CLI to stage the skill (robust copy and store update)
        let normalizedManifestPath = normalizePathForCLI(manifestPath)
        try runSkillHub(arguments: ["stage", normalizedManifestPath], action: "stage skill")

        let hubSkillsDir = SkillHubPaths.defaultSkillsDirectory()
        let destination = hubSkillsDir.appendingPathComponent(manifest.id)
        guard fm.fileExists(atPath: destination.path) else {
            throw SkillHubError.invalidManifest("Staged skill directory missing after stage command: \(destination.path)")
        }

        _ = try FileSystemUtils.backupIfExists(at: source, productID: productID, skillID: manifest.id)
        try FileSystemUtils.copyItem(from: destination, to: source)

        // Update installation status
        try skillStore.markInstalled(skillID: manifest.id, productID: productID, installMode: .copy)
        try skillStore.setEnabled(skillID: manifest.id, productID: productID, enabled: true)
    }

    func checkForUpdates(productID: String, skills: [InstalledSkillRecord]) throws -> UpdateCheckResult {
        let skillsToCheck = skills.filter { $0.installedProducts.contains(productID) }
        guard !skillsToCheck.isEmpty else {
            return UpdateCheckResult(
                checkedGitSkills: 0,
                updatedSkillNames: [],
                skippedNonGitSkills: 0,
                unavailableSkills: []
            )
        }

        var checkedGitSkills = 0
        var skippedNonGitSkills = 0
        var updatedSkillNames: [String] = []
        var unavailableSkills: [String] = []

        for skill in skillsToCheck {
            let source = skill.manifestSource?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            guard isGitSource(source) else {
                skippedNonGitSkills += 1
                try skillStore.setHasUpdate(skillID: skill.manifest.id, hasUpdate: false)
                continue
            }

            checkedGitSkills += 1

            do {
                let hasUpdate = try hasGitRemoteUpdate(skill: skill)
                try skillStore.setHasUpdate(skillID: skill.manifest.id, hasUpdate: hasUpdate)
                if hasUpdate {
                    updatedSkillNames.append(skill.manifest.name)
                }
            } catch {
                unavailableSkills.append(skill.manifest.name)
                try skillStore.setHasUpdate(skillID: skill.manifest.id, hasUpdate: false)
            }
        }

        return UpdateCheckResult(
            checkedGitSkills: checkedGitSkills,
            updatedSkillNames: updatedSkillNames,
            skippedNonGitSkills: skippedNonGitSkills,
            unavailableSkills: unavailableSkills
        )
    }

    private func isGitSource(_ source: String) -> Bool {
        let normalized = source.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !normalized.isEmpty else { return false }
        if normalized.hasPrefix("git@") || normalized.hasSuffix(".git") {
            return true
        }

        guard let url = URL(string: normalized), let host = url.host else {
            return false
        }

        return host.contains("github.com") || host.contains("gitlab.com") || host.contains("bitbucket.org")
    }

    private func hasGitRemoteUpdate(skill: InstalledSkillRecord) throws -> Bool {
        let repoRoot = URL(fileURLWithPath: skill.manifestPath).deletingLastPathComponent()
        let gitDirectory = repoRoot.appendingPathComponent(".git")
        guard FileManager.default.fileExists(atPath: gitDirectory.path) else {
            throw SkillHubError.invalidManifest("No git metadata found at \(repoRoot.path)")
        }

        let localSHA = try runGit(
            arguments: ["-C", repoRoot.path, "rev-parse", "HEAD"],
            action: "read local commit"
        )

        let branchName = try runGit(
            arguments: ["-C", repoRoot.path, "rev-parse", "--abbrev-ref", "HEAD"],
            action: "read current branch"
        )

        let remoteSHA: String
        if branchName != "HEAD" {
            let lsRemoteHead = try runGit(
                arguments: ["-C", repoRoot.path, "ls-remote", "--heads", "origin", branchName],
                action: "read remote branch"
            )

            if let sha = parseLSRemoteSHA(lsRemoteHead) {
                remoteSHA = sha
            } else {
                let lsRemoteDefault = try runGit(
                    arguments: ["-C", repoRoot.path, "ls-remote", "origin", "HEAD"],
                    action: "read remote default branch"
                )
                guard let sha = parseLSRemoteSHA(lsRemoteDefault) else {
                    throw SkillHubError.invalidManifest("Could not resolve remote SHA")
                }
                remoteSHA = sha
            }
        } else {
            let lsRemoteDefault = try runGit(
                arguments: ["-C", repoRoot.path, "ls-remote", "origin", "HEAD"],
                action: "read remote default branch"
            )
            guard let sha = parseLSRemoteSHA(lsRemoteDefault) else {
                throw SkillHubError.invalidManifest("Could not resolve remote SHA")
            }
            remoteSHA = sha
        }

        if localSHA == remoteSHA {
            return false
        }

        let localBehindRemote = try runGitExitCode(
            arguments: ["-C", repoRoot.path, "merge-base", "--is-ancestor", localSHA, remoteSHA],
            action: "check ancestry"
        ) == 0
        if localBehindRemote {
            return true
        }

        let remoteBehindLocal = try runGitExitCode(
            arguments: ["-C", repoRoot.path, "merge-base", "--is-ancestor", remoteSHA, localSHA],
            action: "check ancestry"
        ) == 0

        return !remoteBehindLocal
    }

    private func parseLSRemoteSHA(_ output: String) -> String? {
        output
            .split(separator: "\n")
            .first?
            .split(whereSeparator: { $0 == "\t" || $0 == " " })
            .first
            .map(String.init)
            .flatMap { sha in
                let trimmed = sha.trimmingCharacters(in: .whitespacesAndNewlines)
                return trimmed.isEmpty ? nil : trimmed
            }
    }

    private func runGit(arguments: [String], action: String) throws -> String {
        let process = Process()
        let outputPipe = Pipe()
        let errorPipe = Pipe()

        process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        process.arguments = arguments
        var environment = ProcessInfo.processInfo.environment
        environment["GIT_TERMINAL_PROMPT"] = "0"
        process.environment = environment
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        do {
            try process.run()
        } catch {
            throw SkillHubError.invalidManifest("Failed to \(action): \(error.localizedDescription)")
        }

        process.waitUntilExit()
        let stdoutOutput = readPipeOutput(outputPipe)
        let stderrOutput = readPipeOutput(errorPipe)

        guard process.terminationStatus == 0 else {
            var details: [String] = []
            if !stderrOutput.isEmpty {
                details.append("stderr: \(stderrOutput)")
            }
            if !stdoutOutput.isEmpty {
                details.append("stdout: \(stdoutOutput)")
            }
            let detailSuffix = details.isEmpty ? "" : ". " + details.joined(separator: " | ")
            throw SkillHubError.invalidManifest(
                "Failed to \(action) (exit code: \(process.terminationStatus), args: \(arguments))\(detailSuffix)"
            )
        }

        return stdoutOutput
    }

    private func runGitExitCode(arguments: [String], action: String) throws -> Int32 {
        let process = Process()
        let outputPipe = Pipe()
        let errorPipe = Pipe()

        process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        process.arguments = arguments
        var environment = ProcessInfo.processInfo.environment
        environment["GIT_TERMINAL_PROMPT"] = "0"
        process.environment = environment
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        do {
            try process.run()
        } catch {
            throw SkillHubError.invalidManifest("Failed to \(action): \(error.localizedDescription)")
        }

        process.waitUntilExit()
        return process.terminationStatus
    }

    private func iconName(for id: String, customIconName: String?) -> String {
        if let customIcon = customIconName,
           !customIcon.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return customIcon
        }

        switch id {
        case "vscode": return "chevron.left.forwardslash.chevron.right"
        case "cursor": return "cursorarrow.rays"
        case "claude-code": return "bubble.left.and.bubble.right.fill"
        case "windsurf": return "wind"
        case "aider": return "person.badge.key"
        case "goose": return "bird"
        case "openclaw": return "shippingbox"
        case "codex": return "brain"
        case "opencode": return "terminal"
        default: return customIconName == nil ? "questionmark.circle" : "shippingbox.fill"
        }
    }

    private func normalizeProductID(_ id: String) -> String {
        id.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private func isValidProductID(_ id: String) -> Bool {
        let allowed = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyz0123456789-_")
        return id.rangeOfCharacter(from: allowed.inverted) == nil
    }

    private func reloadAdapterRegistry() {
        self.adapterRegistry = Self.makeAdapterRegistry()
    }

    private func runSkillHub(arguments: [String], action: String) throws {
        let command = try resolveSkillHubCommand()
        let process = Process()
        let outputPipe = Pipe()
        let errorPipe = Pipe()

        process.executableURL = URL(fileURLWithPath: command.executablePath)
        process.arguments = command.prefixArguments + arguments
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        do {
            try process.run()
        } catch {
            throw SkillHubError.invalidManifest(
                "Failed to \(action): unable to launch command \(command.displayName). \(error.localizedDescription)"
            )
        }

        process.waitUntilExit()

        let stdoutOutput = readPipeOutput(outputPipe)
        let stderrOutput = readPipeOutput(errorPipe)

        guard process.terminationStatus == 0 else {
            var details: [String] = []
            if !stderrOutput.isEmpty {
                details.append("stderr: \(stderrOutput)")
            }
            if !stdoutOutput.isEmpty {
                details.append("stdout: \(stdoutOutput)")
            }
            let detailSuffix = details.isEmpty ? "" : ". " + details.joined(separator: " | ")

            throw SkillHubError.invalidManifest(
                "Failed to \(action) (exit code: \(process.terminationStatus), command: \(command.displayName), args: \(arguments))\(detailSuffix)"
            )
        }
    }

    private func readPipeOutput(_ pipe: Pipe) -> String {
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        return String(data: data, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }

    private func ensureSkillHubDirectoryAccess() throws {
        let fm = Foundation.FileManager()
        let requiredDirectories = [
            SkillHubPaths.defaultStateDirectory(),
            SkillHubPaths.defaultSkillsDirectory(),
            SkillHubPaths.defaultBackupsDirectory()
        ]

        for directory in requiredDirectories {
            do {
                try FileSystemUtils.ensureDirectoryExists(at: directory)
            } catch {
                throw SkillHubError.invalidManifest(
                    "Cannot create SkillHub directory at \(directory.path): \(error.localizedDescription)"
                )
            }

            var isDirectory: ObjCBool = false
            guard fm.fileExists(atPath: directory.path, isDirectory: &isDirectory), isDirectory.boolValue else {
                throw SkillHubError.invalidManifest("SkillHub path is not a directory: \(directory.path)")
            }

            guard fm.isReadableFile(atPath: directory.path), fm.isWritableFile(atPath: directory.path) else {
                throw SkillHubError.invalidManifest(
                    "Insufficient permissions for SkillHub directory: \(directory.path). Please grant read/write access."
                )
            }
        }
    }

    private func normalizePathForCLI(_ url: URL) -> String {
        url.standardizedFileURL.resolvingSymlinksInPath().path
    }

    private func scanInstalledSkillIDs(at skillsDirectory: URL) -> Set<String> {
        var result = Set<String>()
        let fm = Foundation.FileManager.default

        guard let contents = try? fm.contentsOfDirectory(
            at: skillsDirectory,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ) else {
            return result
        }

        for folderURL in contents {
            var isDirectory: ObjCBool = false
            guard fm.fileExists(atPath: folderURL.path, isDirectory: &isDirectory), isDirectory.boolValue else {
                continue
            }

            if let loaded = try? AgentSkillLoader.loadFromDirectory(folderURL) {
                result.insert(loaded.manifest.id)
            }
        }

        return result
    }

    private func expandedPath(_ path: String) -> String {
        (path as NSString).expandingTildeInPath
    }

    private func resolveSkillHubCommand() throws -> SkillHubCommand {
        if let binaryPath = findSkillHubBinary() {
            return SkillHubCommand(
                executablePath: binaryPath,
                prefixArguments: [],
                displayName: binaryPath
            )
        }

        if let packagePath = findLocalCLIPath(),
           let swiftPath = findSwiftExecutablePath()
        {
            let prefixArguments = ["run", "--package-path", packagePath, "skillhub"]
            return SkillHubCommand(
                executablePath: swiftPath,
                prefixArguments: prefixArguments,
                displayName: ([swiftPath] + prefixArguments).joined(separator: " ")
            )
        }

        throw SkillHubError.invalidManifest(
            "Could not locate executable 'skillhub' and no local SkillHubCLI package was found for 'swift run'. Build SkillHubCLI first, add it to PATH, or set SKILLHUB_CLI_PATH to the CLI binary path."
        )
    }

    private func findSkillHubBinary() -> String? {
        let fm = Foundation.FileManager()
        var candidates: [String] = []

        if let overridePath = ProcessInfo.processInfo.environment["SKILLHUB_CLI_PATH"]?.trimmingCharacters(in: .whitespacesAndNewlines),
           !overridePath.isEmpty
        {
            candidates.append((overridePath as NSString).expandingTildeInPath)
        }

        candidates.append(contentsOf: [
            "/usr/local/bin/skillhub",
            "/opt/homebrew/bin/skillhub",
            "~/.local/bin/skillhub",
            "skillhub"
        ])

        for root in searchRoots() {
            candidates.append(contentsOf: [
                "\(root)/.build/debug/skillhub",
                "\(root)/.build/arm64-apple-macosx/debug/skillhub",
                "\(root)/Packages/SkillHubCLI/.build/debug/skillhub",
                "\(root)/Packages/SkillHubCLI/.build/arm64-apple-macosx/debug/skillhub",
                "\(root)/SkillHubCLI/.build/debug/skillhub",
                "\(root)/SkillHubCLI/.build/arm64-apple-macosx/debug/skillhub"
            ])
        }

        var visited = Set<String>()
        for path in candidates {
            let expanded = (path as NSString).expandingTildeInPath
            guard visited.insert(expanded).inserted else {
                continue
            }

            if expanded == "skillhub" {
                if let resolved = resolveFromPATH(binary: expanded) {
                    return (resolved as NSString).expandingTildeInPath
                }
                continue
            }

            if fm.isExecutableFile(atPath: expanded) {
                return (expanded as NSString).expandingTildeInPath
            }
        }

        return nil
    }

    private func searchRoots() -> [String] {
        var roots: [String] = []
        var seen = Set<String>()

        func append(_ path: String) {
            let normalized = URL(fileURLWithPath: path).standardizedFileURL.path
            if seen.insert(normalized).inserted {
                roots.append(normalized)
            }
        }

        append(URL(fileURLWithPath: ".").standardizedFileURL.path)

        if let executableURL = Bundle.main.executableURL {
            var cursor = executableURL.deletingLastPathComponent()
            for _ in 0..<10 {
                append(cursor.path)
                let parent = cursor.deletingLastPathComponent()
                if parent.path == cursor.path {
                    break
                }
                cursor = parent
            }
        }

        return roots
    }

    private func findLocalCLIPath() -> String? {
        let fm = Foundation.FileManager()

        for root in searchRoots() {
            let packageCandidates = [
                URL(fileURLWithPath: root).appendingPathComponent("Packages/SkillHubCLI", isDirectory: true),
                URL(fileURLWithPath: root).appendingPathComponent("SkillHubCLI", isDirectory: true)
            ]

            for candidate in packageCandidates {
                let packageFile = candidate.appendingPathComponent("Package.swift")
                if fm.fileExists(atPath: packageFile.path) {
                    return candidate.path
                }
            }
        }

        return nil
    }

    private func findSwiftExecutablePath() -> String? {
        let fm = Foundation.FileManager()
        let preferred = [
            "/usr/bin/swift",
            "/usr/local/bin/swift",
            "/opt/homebrew/bin/swift"
        ]

        for path in preferred where fm.isExecutableFile(atPath: path) {
            return path
        }

        return resolveFromPATH(binary: "swift")
    }

    private func resolveFromPATH(binary: String) -> String? {
        let fm = Foundation.FileManager()
        let pathVariable = ProcessInfo.processInfo.environment["PATH"] ?? ""
        let components = pathVariable.split(separator: ":").map(String.init)

        for component in components where !component.isEmpty {
            let candidate = URL(fileURLWithPath: component).appendingPathComponent(binary).path
            if fm.isExecutableFile(atPath: candidate) {
                return candidate
            }
        }

        return nil
    }

    private static func builtInAdapters() -> [ProductAdapter] {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let adapters: [ProductAdapter] = [
            OpenClawAdapter(),
            CodexAdapter(),
            OpenCodeAdapter(),
            ClaudeCodeAdapter(),
            CursorAdapter(),
            AppCustomProductAdapter(
                config: CustomProductConfig(
                    id: "windsurf",
                    name: "Windsurf",
                    skillsDirectoryPath: "\(home)/.windsurf/skills",
                    executableNames: ["windsurf"],
                    iconName: "wind"
                )
            ),
            AppCustomProductAdapter(
                config: CustomProductConfig(
                    id: "aider",
                    name: "Aider",
                    skillsDirectoryPath: "\(home)/.aider/skills",
                    executableNames: ["aider"],
                    iconName: "person.badge.key"
                )
            ),
            AppCustomProductAdapter(
                config: CustomProductConfig(
                    id: "goose",
                    name: "Goose",
                    skillsDirectoryPath: "\(home)/.config/goose/skills",
                    executableNames: ["goose"],
                    iconName: "bird"
                )
            )
        ]
        return adapters
    }

    private static func makeAdapterRegistry() -> AdapterRegistry {
        let cfg = SkillHubConfig.load()
        let builtIn = builtInAdapters()
        let builtInIDs = Set(builtIn.map(\.id))

        let customAdapters: [ProductAdapter] = cfg.customProducts.compactMap { config in
            if builtInIDs.contains(config.id) {
                return nil
            }
            return AppCustomProductAdapter(config: config)
        }

        return AdapterRegistry(adapters: builtIn + customAdapters)
    }
}

import Foundation

public protocol SkillStore {
    func loadState() throws -> SkillHubState
    func saveState(_ state: SkillHubState) throws
    func upsertSkill(manifest: SkillManifest, manifestPath: String) throws
    func setEnabled(skillID: String, productID: String, enabled: Bool) throws
    func markInstalled(skillID: String, productID: String, installMode: InstallMode) throws
    func markUninstalled(skillID: String, productID: String) throws
    func setHasUpdate(skillID: String, hasUpdate: Bool) throws
    func removeSkill(skillID: String) throws
}

public final class JSONSkillStore: SkillStore {
    public let stateFileURL: URL
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    public init(stateFileURL: URL = SkillHubPaths.defaultStateFile()) {
        self.stateFileURL = stateFileURL
        self.encoder = JSONEncoder()
        self.decoder = JSONDecoder()

        self.encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        self.encoder.dateEncodingStrategy = .iso8601
        self.decoder.dateDecodingStrategy = .iso8601
    }

    public func loadState() throws -> SkillHubState {
        let fm = FileManager.default
        if !fm.fileExists(atPath: stateFileURL.path) {
            return SkillHubState()
        }

        let data = try Data(contentsOf: stateFileURL)
        do {
            return try decoder.decode(SkillHubState.self, from: data)
        } catch {
            throw SkillHubError.stateFileCorrupted(error.localizedDescription)
        }
    }

    public func saveState(_ state: SkillHubState) throws {
        let directory = stateFileURL.deletingLastPathComponent()
        try FileSystemUtils.ensureDirectoryExists(at: directory)

        let tempURL = stateFileURL.appendingPathExtension("tmp")
        let payload = try encoder.encode(state)
        try payload.write(to: tempURL, options: .atomic)

        let fm = FileManager.default
        if fm.fileExists(atPath: stateFileURL.path) {
            try fm.removeItem(at: stateFileURL)
        }
        try fm.moveItem(at: tempURL, to: stateFileURL)
    }

    public func upsertSkill(manifest: SkillManifest, manifestPath: String) throws {
        var state = try loadState()
        state.updatedAt = Date()

        if let index = state.skills.firstIndex(where: { $0.manifest.id == manifest.id }) {
            state.skills[index].manifest = manifest
            state.skills[index].manifestPath = manifestPath
        } else {
            state.skills.append(
                InstalledSkillRecord(
                    manifest: manifest,
                    manifestPath: manifestPath
                )
            )
        }

        try saveState(state)
    }
    
    public func setHasUpdate(skillID: String, hasUpdate: Bool) throws {
        var state = try loadState()
        guard let index = state.skills.firstIndex(where: { $0.manifest.id == skillID }) else {
            throw SkillHubError.invalidManifest("Skill not found: \(skillID)")
        }

        state.skills[index].hasUpdate = hasUpdate
        state.updatedAt = Date()
        try saveState(state)
    }

    public func setEnabled(skillID: String, productID: String, enabled: Bool) throws {
        var state = try loadState()
        guard let index = state.skills.firstIndex(where: { $0.manifest.id == skillID }) else {
            throw SkillHubError.invalidManifest("Skill not found: \(skillID)")
        }

        var enabledSet = Set(state.skills[index].enabledProducts)
        if enabled {
            enabledSet.insert(productID)
        } else {
            enabledSet.remove(productID)
        }

        state.skills[index].enabledProducts = enabledSet.sorted()
        state.updatedAt = Date()
        try saveState(state)
    }

    public func markInstalled(skillID: String, productID: String, installMode: InstallMode) throws {
        var state = try loadState()
        guard let index = state.skills.firstIndex(where: { $0.manifest.id == skillID }) else {
            throw SkillHubError.invalidManifest("Skill not found: \(skillID)")
        }

        var installedSet = Set(state.skills[index].installedProducts)
        installedSet.insert(productID)

        state.skills[index].installedProducts = installedSet.sorted()
        state.skills[index].lastInstallModeByProduct[productID] = installMode
        state.updatedAt = Date()
        try saveState(state)
    }

    public func markUninstalled(skillID: String, productID: String) throws {
        var state = try loadState()
        guard let index = state.skills.firstIndex(where: { $0.manifest.id == skillID }) else {
            throw SkillHubError.invalidManifest("Skill not found: \(skillID)")
        }

        var installedSet = Set(state.skills[index].installedProducts)
        var enabledSet = Set(state.skills[index].enabledProducts)
        installedSet.remove(productID)
        enabledSet.remove(productID)

        state.skills[index].installedProducts = installedSet.sorted()
        state.skills[index].enabledProducts = enabledSet.sorted()
        state.skills[index].lastInstallModeByProduct.removeValue(forKey: productID)
        state.updatedAt = Date()
        try saveState(state)
    }

    public func removeSkill(skillID: String) throws {
        var state = try loadState()
        let originalCount = state.skills.count
        state.skills.removeAll(where: { $0.manifest.id == skillID })
        guard state.skills.count != originalCount else {
            throw SkillHubError.invalidManifest("Skill not found: \(skillID)")
        }

        state.updatedAt = Date()
        try saveState(state)
    }
}

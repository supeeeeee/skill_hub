import Foundation
import SwiftUI
import SkillHubCore

@MainActor
class SkillHubViewModel: ObservableObject {
    @Published var products: [Product] = []
    @Published var skills: [InstalledSkillRecord] = []
    @Published var unregisteredSkillsByProduct: [String: [SkillManifest]] = [:]
    @Published var toasts: [Toast] = []
    @Published var isLoading = false
    
    private let skillStore: SkillStore
    let adapterRegistry: AdapterRegistry
    
    init() {
        let store = JSONSkillStore()
        self.skillStore = store
        
        // Initialize adapters
        let adapters: [ProductAdapter] = [
            OpenClawAdapter(),
            CodexAdapter(),
            OpenCodeAdapter(),
            ClaudeCodeAdapter(),
            CursorAdapter()
        ]
        self.adapterRegistry = AdapterRegistry(adapters: adapters)
        
        loadData()
    }
    
    func loadData() {
        isLoading = true
        // Load skills
        do {
            let state = try skillStore.loadState()
            self.skills = state.skills
            log("Loaded \(state.skills.count) skills from state.", type: .info)
        } catch {
            log("Failed to load skills: \(error.localizedDescription)", type: .error)
            self.skills = []
        }
        
        // Load products
        let cfg = SkillHubConfig.load()
        var newProducts: [Product] = []
        for adapter in adapterRegistry.all() {
            let detection = adapter.detect()
            let status: ProductStatus = detection.isDetected ? .active : .notInstalled
            
            let product = Product(
                id: adapter.id,
                name: adapter.name,
                iconName: iconName(for: adapter.id),
                description: detection.reason,
                status: status,
                supportedModes: adapter.supportedInstallModes,
                customSkillsPath: cfg.productSkillsDirectoryOverrides[adapter.id]
            )
            newProducts.append(product)
        }
        self.products = newProducts
        
        // Scan for unregistered skills
        var newUnregistered: [String: [SkillManifest]] = [:]
        for product in newProducts {
            let skillsPath = product.customSkillsPath ?? defaultSkillsPath(for: product.id)
            let found = scanForUnregisteredSkills(at: skillsPath)
            let unregistered = found.filter { m in
                !self.skills.contains(where: { $0.manifest.id == m.id })
            }
            if !unregistered.isEmpty {
                newUnregistered[product.id] = unregistered
            }
        }
        self.unregisteredSkillsByProduct = newUnregistered
        
        isLoading = false
    }
    
    private func defaultSkillsPath(for productID: String) -> String {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        switch productID {
        case "openclaw": return "\(home)/.openclaw/skills"
        case "opencode": return "\(home)/.config/opencode/skills"
        case "codex": return "\(home)/.codex/skills"
        case "cursor": return "\(home)/.cursor/skills"
        case "claude-code": return "\(home)/.claude/skills"
        default: return "\(home)/.skillhub/products/\(productID)/skills"
        }
    }
    
    private func scanForUnregisteredSkills(at path: String) -> [SkillManifest] {
        var results: [SkillManifest] = []
        let fm = FileManager.default
        let url = URL(fileURLWithPath: path)
        
        guard let contents = try? fm.contentsOfDirectory(at: url, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]) else {
            return []
        }
        
        for folderURL in contents {
            var isDir: ObjCBool = false
            if fm.fileExists(atPath: folderURL.path, isDirectory: &isDir), isDir.boolValue {
                // Check for skill.json or manifest.json
                let candidates = [
                    folderURL.appendingPathComponent("skill.json"),
                    folderURL.appendingPathComponent("manifest.json")
                ]
                
                for fileURL in candidates {
                    if let data = try? Data(contentsOf: fileURL),
                       let manifest = try? JSONDecoder().decode(SkillManifest.self, from: data) {
                        results.append(manifest)
                        break
                    }
                }
            }
        }
        return results
    }
    
    func log(_ message: String, type: ToastType = .info) {
        // Show toast for success/error
        switch type {
        case .success:
            showToast(message: message, type: .success)
        case .error:
            showToast(message: message, type: .error)
        case .info:
            break
        }
    }
    
    func showToast(message: String, type: ToastType) {
        let toast = Toast(message: message, type: type)
        toasts.append(toast)
        
        // Auto dismiss after 3 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            self.toasts.removeAll { $0.id == toast.id }
        }
    }
    
    private func iconName(for id: String) -> String {
        switch id {
        case "vscode": return "chevron.left.forwardslash.chevron.right"
        case "cursor": return "cursorarrow.rays"
        case "claude-code": return "bubble.left.and.bubble.right.fill"
        case "windsurf": return "wind"
        case "openclaw": return "shippingbox"
        case "codex": return "brain"
        case "opencode": return "terminal"
        default: return "questionmark.circle"
        }
    }
    
    func importSkill(at url: URL) {
        do {
            let data = try Data(contentsOf: url)
            let manifest = try JSONDecoder().decode(SkillManifest.self, from: data)
            
            try skillStore.upsertSkill(manifest: manifest, manifestPath: url.path)
            log("Imported skill: \(manifest.name)", type: .success)
            loadData()
        } catch {
            log("Failed to import skill: \(error.localizedDescription)", type: .error)
        }
    }

    func registerSkill(from source: String) {
        log("Registering skill from: \(source)", type: .info)

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        
        // Try to find skillhub CLI
        let cliPath = findSkillHubCLI()
        
        if source.hasPrefix("http://") || source.hasPrefix("https://") || source.hasPrefix("git@") || source.contains("github.com") {
            process.arguments = [cliPath, "register", source]
        } else {
            // Local file
            process.arguments = [cliPath, "register", source]
        }
        
        process.standardOutput = FileHandle.standardOutput
        process.standardError = FileHandle.standardError
        
        do {
            try process.run()
            process.waitUntilExit()
            
            if process.terminationStatus == 0 {
                log("Successfully registered skill from \(source)", type: .success)
                loadData()
            } else {
                log("Failed to register skill (exit code: \(process.terminationStatus))", type: .error)
            }
        } catch {
            log("Failed to run skillhub: \(error.localizedDescription)", type: .error)
        }
    }

    private func findSkillHubCLI() -> String {
        // Check common locations
        let paths = [
            "/usr/local/bin/skillhub",
            "/opt/homebrew/bin/skillhub",
            "~/.local/bin/skillhub",
            "./.build/debug/skillhub"
        ]
        
        for path in paths {
            let expanded = (path as NSString).expandingTildeInPath
            if FileManager.default.fileExists(atPath: expanded) {
                return expanded
            }
        }
        
        return "skillhub" // Fallback to PATH
    }

    func installSkill(manifest: SkillManifest, productID: String, mode: InstallMode = .auto) async -> (success: Bool, message: String, isStubbed: Bool) {
        let isStubbed = true // This is true for MVP as per README.md
        
        do {
            log("Starting installation of \(manifest.name) for \(productID)...", type: .info)
            
            let adapter = try adapterRegistry.adapter(for: productID)
            
            // Find existing record to get source path
            guard let skillRecord = skills.first(where: { $0.manifest.id == manifest.id }) else {
                 let msg = "Skill record not found for \(manifest.name)"
                 log(msg, type: .error)
                 return (false, msg, isStubbed)
            }
            
            // 1. Stage skill
            let sourcePath = URL(fileURLWithPath: skillRecord.manifestPath).deletingLastPathComponent()
            let destPath = SkillHubPaths.defaultSkillsDirectory().appendingPathComponent(manifest.id)
            
            if sourcePath.standardizedFileURL != destPath.standardizedFileURL {
                try FileSystemUtils.ensureDirectoryExists(at: SkillHubPaths.defaultSkillsDirectory())
                try FileSystemUtils.copyItem(from: sourcePath, to: destPath)
                log("Staged skill to \(destPath.path)", type: .info)
            }
            
            // Update manifest path to point to the staged file
            let stagedManifestPath = destPath.appendingPathComponent("skill.json").path
            try skillStore.upsertSkill(manifest: manifest, manifestPath: stagedManifestPath)

            // 2. Install
            let finalMode = try adapter.install(skill: manifest, mode: mode)
            try skillStore.markInstalled(skillID: manifest.id, productID: productID, installMode: finalMode)
            log("Installed to \(productID) via \(finalMode)", type: .info)
            
            // 3. Enable
            try adapter.enable(skillID: manifest.id, mode: finalMode)
            try skillStore.setEnabled(skillID: manifest.id, productID: productID, enabled: true)
            
            let successMsg = "Successfully installed and enabled \(manifest.name) for \(productID)"
            log(successMsg, type: .success)
            
            // Refresh data
            loadData()
            
            return (true, successMsg, isStubbed)
            
        } catch {
            let errorMsg = "Error installing \(manifest.name): \(error.localizedDescription)"
            log(errorMsg, type: .error)
            return (false, errorMsg, isStubbed)
        }    }
    
    func uninstallSkill(manifest: SkillManifest, productID: String) async {
        do {
            log("Uninstalling \(manifest.name) from \(productID)...", type: .info)
            let adapter = try adapterRegistry.adapter(for: productID)
            
            try adapter.disable(skillID: manifest.id)
            try skillStore.markUninstalled(skillID: manifest.id, productID: productID)
            
            log("Successfully uninstalled \(manifest.name) from \(productID)", type: .success)
            loadData()
        } catch {
            log("Error uninstalling \(manifest.name): \(error.localizedDescription)", type: .error)
        }
    }
    
    func setSkillEnabled(manifest: SkillManifest, productID: String, enabled: Bool) async {
        do {
            let adapter = try adapterRegistry.adapter(for: productID)
            
            // Get current install mode to know how to enable/disable
            guard let skillRecord = skills.first(where: { $0.manifest.id == manifest.id }),
                  let mode = skillRecord.lastInstallModeByProduct[productID] else {
                log("Cannot change state for \(manifest.name): not installed", type: .error)
                return
            }
            
            if enabled {
                log("Enabling \(manifest.name) for \(productID)...", type: .info)
                try adapter.enable(skillID: manifest.id, mode: mode)
            } else {
                log("Disabling \(manifest.name) for \(productID)...", type: .info)
                try adapter.disable(skillID: manifest.id)
            }
            
            try skillStore.setEnabled(skillID: manifest.id, productID: productID, enabled: enabled)
            log("\(enabled ? "Enabled" : "Disabled") \(manifest.name) for \(productID)", type: .success)
            loadData()
        } catch {
            log("Error changing state for \(manifest.name): \(error.localizedDescription)", type: .error)
        }
    }
    
    func acquireSkill(manifest: SkillManifest, fromProduct productID: String) async {
        log("Acquiring skill \(manifest.name) from \(productID)...", type: .info)
        
        // 1. Find source path
        guard let product = products.first(where: { $0.id == productID }) else {
            log("Product \(productID) not found", type: .error)
            return
        }
        
        let skillsPath = product.customSkillsPath ?? defaultSkillsPath(for: productID)
        let rootUrl = URL(fileURLWithPath: skillsPath)
        let fm = FileManager.default
        
        // We need to find the specific folder that contains this manifest
        var sourceFolder: URL?
        if let contents = try? fm.contentsOfDirectory(at: rootUrl, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]) {
            for folderURL in contents {
                let candidates = [
                    folderURL.appendingPathComponent("skill.json"),
                    folderURL.appendingPathComponent("manifest.json")
                ]
                for fileURL in candidates {
                    if let data = try? Data(contentsOf: fileURL),
                       let found = try? JSONDecoder().decode(SkillManifest.self, from: data),
                       found.id == manifest.id {
                        sourceFolder = folderURL
                        break
                    }
                }
                if sourceFolder != nil { break }
            }
        }
        
        guard let source = sourceFolder else {
            log("Could not find source folder for skill \(manifest.id) in \(skillsPath)", type: .error)
            return
        }
        
        // 2. Copy to Hub
        let hubSkillsDir = SkillHubPaths.defaultSkillsDirectory()
        let dest = hubSkillsDir.appendingPathComponent(manifest.id)
        
        do {
            try FileSystemUtils.ensureDirectoryExists(at: hubSkillsDir)
            try FileSystemUtils.copyItem(from: source, to: dest)
            log("Copied skill to \(dest.path)", type: .info)
            
            // 3. Register and Mark Installed
            let manifestPath = dest.appendingPathComponent("skill.json").path // Assume skill.json or keep original name?
            // The copy keeps the original filenames. Let's check what it was.
            // But upsertSkill expects the path to the manifest file.
            // If source had manifest.json, dest has manifest.json.
            
            let destManifestPath: String
            if fm.fileExists(atPath: dest.appendingPathComponent("skill.json").path) {
                destManifestPath = dest.appendingPathComponent("skill.json").path
            } else {
                destManifestPath = dest.appendingPathComponent("manifest.json").path
            }
            
            try skillStore.upsertSkill(manifest: manifest, manifestPath: destManifestPath)
            
            // Mark as installed for this product (assuming 'copy' mode or 'auto')
            // Since we just copied it FROM the product, the product presumably has it.
            // But if we want to manage it, we might eventually want to overwrite the product's copy with ours?
            // For now, just mark it.
            try skillStore.markInstalled(skillID: manifest.id, productID: productID, installMode: .copy)
            try skillStore.setEnabled(skillID: manifest.id, productID: productID, enabled: true)
            
            log("Successfully acquired \(manifest.name)", type: .success)
            loadData()
            
        } catch {
            log("Failed to acquire skill: \(error.localizedDescription)", type: .error)
        }
    }
}

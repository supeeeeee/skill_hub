import Foundation
import SwiftUI
import SkillHubCore

@MainActor
class SkillHubViewModel: ObservableObject {
    @Published var products: [Product] = []
    @Published var skills: [InstalledSkillRecord] = []
    @Published var logs: [ActivityLog] = []
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
        isLoading = false
    }
    
    func log(_ message: String, type: LogType = .info) {
        let log = ActivityLog(timestamp: Date(), message: message, type: type)
        // Keep logs limited
        if logs.count > 100 {
            logs.removeLast()
        }
        logs.insert(log, at: 0)
        
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

    func addSkill(from source: String) {
        log("Adding skill from: \(source)", type: .info)

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        
        // Try to find skillhub CLI
        let cliPath = findSkillHubCLI()
        
        if source.hasPrefix("http://") || source.hasPrefix("https://") || source.hasPrefix("git@") || source.contains("github.com") {
            process.arguments = [cliPath, "add", source]
        } else {
            // Local file
            process.arguments = [cliPath, "add", source]
        }
        
        process.standardOutput = FileHandle.standardOutput
        process.standardError = FileHandle.standardError
        
        do {
            try process.run()
            process.waitUntilExit()
            
            if process.terminationStatus == 0 {
                log("Successfully added skill from \(source)", type: .success)
                loadData()
            } else {
                log("Failed to add skill (exit code: \(process.terminationStatus))", type: .error)
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

    func installSkill(manifest: SkillManifest, productID: String, mode: InstallMode = .auto) async {
        do {
            log("Starting installation of \(manifest.name) for \(productID)...", type: .info)
            
            let adapter = try adapterRegistry.adapter(for: productID)
            
            // Find existing record to get source path
            guard let skillRecord = skills.first(where: { $0.manifest.id == manifest.id }) else {
                 log("Skill record not found for \(manifest.name)", type: .error)
                 return
            }
            
            // 1. Stage skill
            // We copy from the current manifest location to the managed storage
            let sourcePath = URL(fileURLWithPath: skillRecord.manifestPath).deletingLastPathComponent()
            let destPath = SkillHubPaths.defaultSkillsDirectory().appendingPathComponent(manifest.id)
            
            // Only copy if source is different from destination
            if sourcePath.standardizedFileURL != destPath.standardizedFileURL {
                try FileSystemUtils.ensureDirectoryExists(at: SkillHubPaths.defaultSkillsDirectory())
                
                // Copy directory content
                // Note: FileSystemUtils.copyItem expects file/directory path.
                // If we want to copy the whole folder 'skill-name' to 'skills/skill-name', we use copyItem.
                // sourcePath should be the directory containing skill.json
                
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
            
            log("Successfully installed and enabled \(manifest.name) for \(productID)", type: .success)
            
            // Refresh data
            loadData()
            
        } catch {
            log("Error installing \(manifest.name): \(error.localizedDescription)", type: .error)
        }
    }
    
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
}

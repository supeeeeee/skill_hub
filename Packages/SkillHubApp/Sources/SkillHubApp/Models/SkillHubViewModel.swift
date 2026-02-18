import Foundation
import SwiftUI
import SkillHubCore

@MainActor
class SkillHubViewModel: ObservableObject {
    @Published var products: [Product] = []
    @Published var skills: [InstalledSkillRecord] = []
    @Published var unregisteredSkillsByProduct: [String: [SkillManifest]] = [:]
    @Published var healthResults: [String: DiagnosticIssue] = [:]
    @Published var toasts: [Toast] = []
    @Published var isLoading = false
    
    private let skillService: SkillService
    private let scanService: ScanService

    var adapterRegistry: AdapterRegistry {
        skillService.adapterRegistry
    }

    init(
        skillService: SkillService = SkillService(),
        scanService: ScanService? = nil
    ) {
        self.skillService = skillService
        self.scanService = scanService ?? ScanService(adapterRegistry: skillService.adapterRegistry)

        loadData()
    }
    
    func loadData() {
        isLoading = true
        
        // 1. Load local state (Synchronous/Fast)
        do {
            self.skills = try skillService.loadSkills()
        } catch {
            log("Failed to load skills: \(error.localizedDescription)", type: .error)
            self.skills = []
        }

        // 2. Load products and detection (Synchronous/Fast)
        let newProducts = skillService.loadProducts()
        self.products = newProducts
        
        // 3. Scan for unregistered skills (Asynchronous/Disk I/O)
        Task {
            let registeredIDs = Set(self.skills.map { $0.manifest.id })
            let unregistered = await scanService.scanUnregisteredSkills(
                for: newProducts,
                registeredSkillIDs: registeredIDs
            )
            self.unregisteredSkillsByProduct = unregistered
            self.isLoading = false
        }
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
    
    func importSkill(at url: URL) {
        do {
            let manifest = try skillService.importSkill(at: url)
            log("Imported skill: \(manifest.name)", type: .success)
            loadData()
        } catch {
            log("Failed to import skill: \(error.localizedDescription)", type: .error)
        }
    }

    func registerSkill(from source: String) {
        log("Registering skill from: \(source)", type: .info)

        do {
            try skillService.registerSkill(from: source)
            log("Successfully registered skill from \(source)", type: .success)
            loadData()
        } catch {
            log("Failed to register skill: \(error.localizedDescription)", type: .error)
        }
    }

    func installSkill(manifest: SkillManifest, productID: String, mode: InstallMode = .auto) async -> (success: Bool, message: String, isStubbed: Bool) {
        let isStubbed = true // This is true for MVP as per README.md

        do {
            log("Starting installation of \(manifest.name) for \(productID)...", type: .info)

            try skillService.installSkill(
                manifest: manifest,
                productID: productID,
                mode: mode,
                currentSkills: skills
            )

            let successMsg = "Successfully installed and enabled \(manifest.name) for \(productID)"
            log(successMsg, type: .success)

            // Refresh data
            loadData()

            return (true, successMsg, isStubbed)

        } catch {
            let errorMsg = "Error installing \(manifest.name): \(error.localizedDescription)"
            log(errorMsg, type: .error)
            return (false, errorMsg, isStubbed)
        }
    }
    
    func uninstallSkill(manifest: SkillManifest, productID: String) async {
        do {
            log("Uninstalling \(manifest.name) from \(productID)...", type: .info)
            try skillService.uninstallSkill(manifest: manifest, productID: productID)

            log("Successfully uninstalled \(manifest.name) from \(productID)", type: .success)
            loadData()
        } catch {
            log("Error uninstalling \(manifest.name): \(error.localizedDescription)", type: .error)
        }
    }
    
    func setSkillEnabled(manifest: SkillManifest, productID: String, enabled: Bool) async {
        do {
            if enabled {
                log("Enabling \(manifest.name) for \(productID)...", type: .info)
            } else {
                log("Disabling \(manifest.name) for \(productID)...", type: .info)
            }

            try skillService.setSkillEnabled(
                manifest: manifest,
                productID: productID,
                enabled: enabled,
                currentSkills: skills
            )

            log("\(enabled ? "Enabled" : "Disabled") \(manifest.name) for \(productID)", type: .success)
            loadData()
        } catch {
            log("Error changing state for \(manifest.name): \(error.localizedDescription)", type: .error)
        }
    }
    
    func acquireSkill(manifest: SkillManifest, fromProduct productID: String) async {
        log("Acquiring skill \(manifest.name) from \(productID)...", type: .info)

        guard let skillsPath = scanService.resolveSkillsPath(for: productID) else {
            log("Product \(productID) not found", type: .error)
            return
        }
 
        do {
            try skillService.acquireSkill(
                manifest: manifest,
                fromProduct: productID,
                skillsPath: skillsPath
            )

            log("Successfully acquired and took over \(manifest.name)", type: .success)
            loadData()

        } catch {
            log("Failed to acquire skill: \(error.localizedDescription)", type: .error)
        }
    }

    func runDoctor(for productID: String) {
        log("Running doctor for \(productID)...", type: .info)

        guard let skillsPath = scanService.resolveSkillsPath(for: productID) else {
            log("Doctor failed: Product \(productID) not found.", type: .error)
            return
        }

        let diagnosis = scanService.diagnose(productID: productID, skillsPath: skillsPath)
        healthResults[productID] = diagnosis.issue
        updateProductHealth(productID, status: diagnosis.status)

        log("Doctor completed for \(productID)", type: .info)
    }

    func fixIssue(for productID: String) async {
        guard let issue = healthResults[productID], issue.isFixable else { return }
        log("Attempting to fix issue for \(productID)...", type: .info)

        guard let skillsPath = scanService.resolveSkillsPath(for: productID) else {
            return
        }

        do {
            try scanService.fixIssue(issue, skillsPath: skillsPath)
            log("Applied fix for \(productID)", type: .success)

            // Re-run doctor to verify
            runDoctor(for: productID)
        } catch {
            log("Failed to fix issue: \(error.localizedDescription)", type: .error)
        }
    }

    private func updateProductHealth(_ productID: String, status: HealthStatus) {
        if let index = products.firstIndex(where: { $0.id == productID }) {
            products[index].health = status
        }
    }

    func checkForUpdates(for productID: String) {
        log("Checking for updates for \(productID)...", type: .info)

        do {
            if let skillName = try skillService.checkForUpdates(productID: productID, skills: skills) {
                log("Found update for \(skillName).", type: .success)
                loadData()
            } else {
                log("No installed skills to check for \(productID).", type: .info)
            }
        } catch {
            log("Failed to check updates for \(productID): \(error.localizedDescription)", type: .error)
        }
    }

    func setProductConfigPath(productID: String, path: String) {
        do {
            try skillService.setProductConfigPath(productID: productID, rawPath: path)
            loadData()
            let normalized = path.trimmingCharacters(in: .whitespacesAndNewlines)
            if normalized.isEmpty {
                log("Reset config path for \(productID) to default", type: .success)
            } else {
                log("Updated config path for \(productID)", type: .success)
            }
        } catch {
            log("Failed to update config path: \(error.localizedDescription)", type: .error)
        }
    }
}

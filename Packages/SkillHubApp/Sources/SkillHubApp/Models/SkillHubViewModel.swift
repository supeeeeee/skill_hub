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
            log("Failed to load skills: \(errorMessage(from: error))", type: .error)
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
            log("Failed to import skill: \(errorMessage(from: error))", type: .error)
        }
    }

    func registerSkill(from source: String) {
        log("Registering skill from: \(source)", type: .info)

        do {
            try skillService.registerSkill(from: source)
            log("Successfully registered skill from \(source)", type: .success)
            loadData()
        } catch {
            log("Failed to register skill: \(errorMessage(from: error))", type: .error)
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
            let errorMsg = "Error installing \(manifest.name): \(errorMessage(from: error))"
            log(errorMsg, type: .error)
            return (false, errorMsg, isStubbed)
        }
    }
    
    func bulkBindSkill(manifest: SkillManifest, productIDs: [String]) async {
        log("Bulk binding \(manifest.name) to \(productIDs.count) products...", type: .info)
        
        var successCount = 0
        var failCount = 0
        
        for productID in productIDs {
            // We use the internal logic of installSkill but might want to avoid excessive loadData calls
            // For now, reusing the existing method is safest to ensure consistency
            let result = await installSkill(manifest: manifest, productID: productID, mode: .auto)
            if result.success {
                successCount += 1
            } else {
                failCount += 1
            }
        }
        
        if failCount == 0 {
            log("Bulk bind completed: All \(successCount) products bound successfully", type: .success)
        } else {
            log("Bulk bind completed: \(successCount) success, \(failCount) failed", type: .info)
        }
    }
    
    func disableSkillGlobally(manifest: SkillManifest) async {
        log("Disabling \(manifest.name) on all products...", type: .info)
        
        guard let skillRecord = skills.first(where: { $0.id == manifest.id }) else {
            log("Skill record not found for \(manifest.name)", type: .error)
            return
        }
        
        let targets = skillRecord.installedProducts
        if targets.isEmpty {
            log("No products bound to \(manifest.name)", type: .info)
            return
        }

        for productID in targets {
             await setSkillEnabled(manifest: manifest, productID: productID, enabled: false)
        }
        
        log("Disabled \(manifest.name) on all bound products", type: .success)
    }
    
    func uninstallSkill(manifest: SkillManifest, productID: String) async {
        do {
            log("Uninstalling \(manifest.name) from \(productID)...", type: .info)
            try skillService.uninstallSkill(manifest: manifest, productID: productID)

            log("Successfully uninstalled \(manifest.name) from \(productID)", type: .success)
            loadData()
        } catch {
            log("Error uninstalling \(manifest.name): \(errorMessage(from: error))", type: .error)
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
            log("Error changing state for \(manifest.name): \(errorMessage(from: error))", type: .error)
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
            log("Failed to acquire skill: \(errorMessage(from: error))", type: .error)
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
            log("Failed to fix issue: \(errorMessage(from: error))", type: .error)
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
            log("Failed to check updates for \(productID): \(errorMessage(from: error))", type: .error)
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
            log("Failed to update config path: \(errorMessage(from: error))", type: .error)
        }
    }

    private func errorMessage(from error: Error) -> String {
        if let skillHubError = error as? SkillHubError {
            return skillHubError.description
        }

        if let localizedError = error as? LocalizedError,
           let description = localizedError.errorDescription?.trimmingCharacters(in: .whitespacesAndNewlines),
           !description.isEmpty {
            return description
        }

        let nsError = error as NSError
        if let underlying = nsError.userInfo[NSUnderlyingErrorKey] as? Error {
            let underlyingMessage = errorMessage(from: underlying)
            if !underlyingMessage.isEmpty {
                return underlyingMessage
            }
        }

        let localizedDescription = nsError.localizedDescription.trimmingCharacters(in: .whitespacesAndNewlines)
        if !localizedDescription.isEmpty && !isOpaqueNSErrorMessage(nsError, localizedDescription) {
            return localizedDescription
        }

        let reflected = String(describing: error).trimmingCharacters(in: .whitespacesAndNewlines)
        if !reflected.isEmpty {
            return reflected
        }

        return "Unknown error"
    }

    private func isOpaqueNSErrorMessage(_ error: NSError, _ message: String) -> Bool {
        if error.domain == SkillHubError.errorDomain && error.code == 0 {
            return true
        }

        return message.hasPrefix("The operation couldn’t be completed.")
            || message.hasPrefix("The operation could not be completed.")
    }
}

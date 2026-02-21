import Foundation
import SwiftUI
import SkillHubCore

@MainActor
class SkillDetailViewModel: ObservableObject {
    @Published var skill: InstalledSkillRecord
    private var hubViewModel: SkillHubViewModel?
    
    init(skill: InstalledSkillRecord) {
        self.skill = skill
    }
    
    func setHubViewModel(_ hubViewModel: SkillHubViewModel) {
        self.hubViewModel = hubViewModel
    }
    
    func bulkBindProducts(to productIDs: [String]) async {
        guard let hubViewModel = hubViewModel else { return }
        await hubViewModel.bulkBindSkill(manifest: skill.manifest, productIDs: productIDs)
        updateLocalSkill()
    }
    
    func bulkDisableProducts(productIDs: [String]) async {
        guard let hubViewModel = hubViewModel else { return }
        for productID in productIDs {
            await hubViewModel.setSkillEnabled(manifest: skill.manifest, productID: productID, enabled: false)
        }
        updateLocalSkill()
    }
    
    func bulkUninstallProducts(productIDs: [String]) async {
        guard let hubViewModel = hubViewModel else { return }
        for productID in productIDs {
            await hubViewModel.uninstallSkill(manifest: skill.manifest, productID: productID)
        }
        updateLocalSkill()
    }
    
    func disableAllProducts() async {
        guard let hubViewModel = hubViewModel else { return }
        await hubViewModel.disableSkillGlobally(manifest: skill.manifest)
        updateLocalSkill()
    }

    func removeFromHub() async -> Bool {
        guard let hubViewModel = hubViewModel else { return false }
        return await hubViewModel.removeSkillFromHub(manifest: skill.manifest)
    }
    
    func enable(on productID: String) async {
        guard let hubViewModel = hubViewModel else { return }
        _ = await hubViewModel.installSkill(manifest: skill.manifest, productID: productID)
        updateLocalSkill()
    }
    
    func toggleEnable(on productID: String) async {
        guard let hubViewModel = hubViewModel else { return }
        let currentlyEnabled = skill.enabledProducts.contains(productID)
        await hubViewModel.setSkillEnabled(
            manifest: skill.manifest,
            productID: productID,
            enabled: !currentlyEnabled
        )
        updateLocalSkill()
    }
    
    private func updateLocalSkill() {
        guard let hubViewModel = hubViewModel else { return }
        if let updated = hubViewModel.skills.first(where: { $0.id == skill.id }) {
            self.skill = updated
        }
    }
}

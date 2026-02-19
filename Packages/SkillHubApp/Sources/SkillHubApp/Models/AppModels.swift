import Foundation
import SkillHubCore

enum ProductStatus: String, CaseIterable, Sendable {
    case active
    case notInstalled
    case error
}

struct Product: Identifiable, Hashable, Sendable {
    let id: String
    let name: String
    let iconName: String
    let description: String
    let status: ProductStatus
    var health: HealthStatus = .unknown
    let supportedModes: [InstallMode]
    var customSkillsPath: String? = nil // from SkillHubConfig.productSkillsDirectoryOverrides
    var customConfigPath: String? = nil // from state.json productConfigFilePathOverrides
    var isCustom: Bool = false
}

struct SkillBinding: Identifiable, Sendable {
    let id = UUID()
    let skillName: String
    let products: [String] // List of product IDs
    let isEnabled: Bool
}

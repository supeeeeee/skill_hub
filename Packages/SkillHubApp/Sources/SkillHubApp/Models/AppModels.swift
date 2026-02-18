import Foundation
import SkillHubCore

enum ProductStatus: String, CaseIterable, Sendable {
    case active
    case notInstalled
    case error
}

enum HealthStatus: String, CaseIterable, Sendable {
    case healthy
    case warning
    case unknown
}

struct DiagnosticIssue: Identifiable, Sendable {
    let id: String // Product ID
    let message: String
    let isFixable: Bool
    let fixActionLabel: String?
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
}

struct SkillBinding: Identifiable, Sendable {
    let id = UUID()
    let skillName: String
    let products: [String] // List of product IDs
    let isEnabled: Bool
}

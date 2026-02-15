import Foundation
import SkillHubCore

struct Product: Identifiable, Hashable, Sendable {
    let id: String
    let name: String
    let iconName: String
    let description: String
    let status: ProductStatus
    let supportedModes: [InstallMode]
    var customSkillsPath: String? = nil // from SkillHubConfig.productSkillsDirectoryOverrides
}

enum ProductStatus: String, CaseIterable, Sendable {
    case active
    case notInstalled
    case error
}

struct SkillBinding: Identifiable, Sendable {
    let id = UUID()
    let skillName: String
    let products: [String] // List of product IDs
    let isEnabled: Bool
}

struct ActivityLog: Identifiable, Sendable {
    let id = UUID()
    let timestamp: Date
    let message: String
    let type: LogType
}

enum LogType: Sendable {
    case info
    case success
    case error
}

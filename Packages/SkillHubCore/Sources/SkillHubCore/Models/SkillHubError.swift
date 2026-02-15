import Foundation

public enum SkillHubError: Error, CustomStringConvertible {
    case invalidManifest(String)
    case stateFileCorrupted(String)
    case adapterNotFound(String)
    case adapterEnvironmentInvalid(String)
    case unsupportedInstallMode(String)
    case notImplemented(String)

    public var description: String {
        switch self {
        case .invalidManifest(let reason):
            return "Invalid manifest: \(reason)"
        case .stateFileCorrupted(let reason):
            return "State file corrupted: \(reason)"
        case .adapterNotFound(let productID):
            return "Adapter not found for product: \(productID)"
        case .adapterEnvironmentInvalid(let reason):
            return "Adapter environment invalid: \(reason)"
        case .unsupportedInstallMode(let reason):
            return "Unsupported install mode: \(reason)"
        case .notImplemented(let reason):
            return "Not implemented: \(reason)"
        }
    }
}

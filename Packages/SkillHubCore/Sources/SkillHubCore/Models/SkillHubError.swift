import Foundation

public enum SkillHubError: Error, LocalizedError, CustomNSError, CustomStringConvertible {
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

    public var errorDescription: String? {
        description
    }

    public static var errorDomain: String {
        "SkillHubCore.SkillHubError"
    }

    public var errorCode: Int {
        switch self {
        case .invalidManifest:
            return 1001
        case .stateFileCorrupted:
            return 1002
        case .adapterNotFound:
            return 1003
        case .adapterEnvironmentInvalid:
            return 1004
        case .unsupportedInstallMode:
            return 1005
        case .notImplemented:
            return 1006
        }
    }

    public var errorUserInfo: [String : Any] {
        [NSLocalizedDescriptionKey: description]
    }
}

import Foundation

public enum SkillHubPaths {
    public static func defaultStateDirectory() -> URL {
        let home = FileManager.default.homeDirectoryForCurrentUser
        return home.appendingPathComponent(".skillhub", isDirectory: true)
    }

    public static func defaultStateFile() -> URL {
        defaultStateDirectory().appendingPathComponent("state.json", isDirectory: false)
    }

    public static func defaultSkillsDirectory() -> URL {
        defaultStateDirectory().appendingPathComponent("skills", isDirectory: true)
    }

    public static func defaultBackupsDirectory() -> URL {
        defaultStateDirectory().appendingPathComponent("backups", isDirectory: true)
    }
}

public enum FileSystemUtils {
    public static func ensureDirectoryExists(at url: URL) throws {
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    }

    public static func copyItem(from source: URL, to destination: URL) throws {
        let fm = FileManager.default
        if fm.fileExists(atPath: destination.path) {
            try fm.removeItem(at: destination)
        }
        try fm.copyItem(at: source, to: destination)
    }

    public static func createSymlink(from source: URL, to destination: URL) throws {
        let fm = FileManager.default
        if fm.fileExists(atPath: destination.path) {
            try fm.removeItem(at: destination)
        }
        try fm.createSymbolicLink(at: destination, withDestinationURL: source)
    }

    public static func backupPath(
        timestamp: Date = Date(),
        productID: String,
        skillID: String
    ) -> URL {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withDashSeparatorInDate, .withColonSeparatorInTime]
        let timestampLabel = formatter.string(from: timestamp).replacingOccurrences(of: ":", with: "-")
        return SkillHubPaths.defaultBackupsDirectory()
            .appendingPathComponent(timestampLabel, isDirectory: true)
            .appendingPathComponent(productID, isDirectory: true)
            .appendingPathComponent(skillID, isDirectory: true)
    }

    @discardableResult
    public static func backupIfExists(
        at path: URL,
        productID: String,
        skillID: String,
        timestamp: Date = Date()
    ) throws -> URL? {
        let fm = FileManager.default
        guard fm.fileExists(atPath: path.path) else {
            return nil
        }

        let backupDestination = backupPath(timestamp: timestamp, productID: productID, skillID: skillID)
        try ensureDirectoryExists(at: backupDestination.deletingLastPathComponent())
        try fm.moveItem(at: path, to: backupDestination)
        return backupDestination
    }

    public static func applyConfigPatch(
        at _: URL,
        with _: [String: String]
    ) throws {
        throw SkillHubError.notImplemented("Config patching engine is not implemented in MVP")
    }
}

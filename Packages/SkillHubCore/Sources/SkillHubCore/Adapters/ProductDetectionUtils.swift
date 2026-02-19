import Foundation

enum ProductDetectionUtils {
    private static let defaultBinarySearchPaths: [String] = [
        "/usr/local/bin",
        "/opt/homebrew/bin",
        "~/.local/bin"
    ]

    static func firstExistingPath(in candidates: [String]) -> String? {
        let fm = FileManager.default
        for path in candidates {
            let expanded = (path as NSString).expandingTildeInPath
            if fm.fileExists(atPath: expanded) {
                return expanded
            }
        }
        return nil
    }

    static func firstExecutablePath(named binaries: [String], additionalSearchPaths: [String] = []) -> String? {
        let fm = FileManager.default
        var searchPaths = defaultBinarySearchPaths.map { ($0 as NSString).expandingTildeInPath }
        searchPaths.append(contentsOf: additionalSearchPaths.map { ($0 as NSString).expandingTildeInPath })

        let pathEnv = ProcessInfo.processInfo.environment["PATH"] ?? ""
        let envPaths = pathEnv.split(separator: ":").map(String.init)
        searchPaths.append(contentsOf: envPaths)

        var dedupedSearchPaths: [String] = []
        var seenPaths = Set<String>()
        for path in searchPaths where !path.isEmpty {
            if seenPaths.insert(path).inserted {
                dedupedSearchPaths.append(path)
            }
        }

        for binary in binaries {
            let expandedBinary = (binary as NSString).expandingTildeInPath
            if expandedBinary.contains("/") {
                if fm.isExecutableFile(atPath: expandedBinary) {
                    return expandedBinary
                }
                continue
            }

            for searchPath in dedupedSearchPaths {
                let candidate = URL(fileURLWithPath: searchPath).appendingPathComponent(expandedBinary).path
                if fm.isExecutableFile(atPath: candidate) {
                    return candidate
                }
            }
        }

        return nil
    }
}

import Foundation
import SkillHubCore

struct DoctorResult {
    let issue: DiagnosticIssue
    let status: HealthStatus
}

final class ScanService: @unchecked Sendable {
    private let fileManager: FileManager
    private let adapterRegistry: AdapterRegistry

    init(adapterRegistry: AdapterRegistry, fileManager: FileManager = .default) {
        self.adapterRegistry = adapterRegistry
        self.fileManager = fileManager
    }

    func resolveSkillsPath(for productID: String) -> String? {
        guard let adapter = try? adapterRegistry.adapter(for: productID) else {
            return nil
        }
        return adapter.skillsDirectory().path
    }

    func scanUnregisteredSkills(
        for products: [Product],
        registeredSkillIDs: Set<String>
    ) async -> [String: [SkillManifest]] {
        var newUnregistered: [String: [SkillManifest]] = [:]

        for product in products {
            guard let skillsPath = resolveSkillsPath(for: product.id) else {
                continue
            }
            let found = scanForUnregisteredSkills(at: skillsPath, fileManager: fileManager)
            let unregistered = found.filter { !registeredSkillIDs.contains($0.id) }

            if !unregistered.isEmpty {
                newUnregistered[product.id] = unregistered
            }
        }

        return newUnregistered
    }

    func diagnose(productID: String, skillsPath: String) -> DoctorResult {
        let pathURL = URL(fileURLWithPath: skillsPath)

        if !fileManager.fileExists(atPath: pathURL.path) {
            return DoctorResult(
                issue: DiagnosticIssue(
                    id: productID,
                    message: "⚠️ Skills directory does not exist: \(skillsPath)",
                    isFixable: true,
                    suggestion: FixSuggestion(
                        label: "Create Directory",
                        action: "create-directory",
                        description: "Create missing skills directory"
                    )
                ),
                status: .warning
            )
        }

        if !fileManager.isReadableFile(atPath: pathURL.path) || !fileManager.isWritableFile(atPath: pathURL.path) {
            return DoctorResult(
                issue: DiagnosticIssue(
                    id: productID,
                    message: "⚠️ Permissions issue for \(skillsPath). Please check Read/Write access.",
                    isFixable: false
                ),
                status: .warning
            )
        }

        return DoctorResult(
            issue: DiagnosticIssue(
                id: productID,
                message: "✅ No issues found.",
                isFixable: false
            ),
            status: .healthy
        )
    }

    func fixIssue(_ issue: DiagnosticIssue, skillsPath: String) throws {
        guard issue.isFixable else { return }
        let action = issue.suggestion?.action

        switch action {
        case "create-directory":
            try fileManager.createDirectory(
                at: URL(fileURLWithPath: skillsPath),
                withIntermediateDirectories: true
            )
        default:
            throw SkillHubError.notImplemented("Unsupported doctor fix action: \(action ?? "nil")")
        }
    }

    private func scanForUnregisteredSkills(at path: String, fileManager: FileManager) -> [SkillManifest] {
        var results: [SkillManifest] = []
        let url = URL(fileURLWithPath: path)

        guard let contents = try? fileManager.contentsOfDirectory(
            at: url,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        for folderURL in contents {
            var isDir: ObjCBool = false
            if fileManager.fileExists(atPath: folderURL.path, isDirectory: &isDir), isDir.boolValue {
                let candidates = [
                    folderURL.appendingPathComponent("skill.json"),
                    folderURL.appendingPathComponent("manifest.json")
                ]

                for fileURL in candidates {
                    if let data = try? Data(contentsOf: fileURL),
                       let manifest = try? JSONDecoder().decode(SkillManifest.self, from: data) {
                        results.append(manifest)
                        break
                    }
                }
            }
        }

        return results
    }
}

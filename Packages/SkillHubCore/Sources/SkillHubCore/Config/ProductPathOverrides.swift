import Foundation

public enum ProductPathOverrides {
    public static func configFilePathOverride(
        for productID: String,
        stateFileURL: URL = SkillHubPaths.defaultStateFile()
    ) -> URL? {
        let store = JSONSkillStore(stateFileURL: stateFileURL)
        guard let state = try? store.loadState(),
              let raw = state.productConfigFilePathOverrides[productID]
        else {
            return nil
        }

        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return nil
        }

        return URL(fileURLWithPath: trimmed, isDirectory: false)
    }
}

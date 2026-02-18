import Foundation
import Combine

@MainActor
final class UserPreferences: ObservableObject {
    private enum Keys {
        static let isAdvancedMode = "skillhub.isAdvancedMode"
    }

    @Published var isAdvancedMode: Bool {
        didSet {
            UserDefaults.standard.set(isAdvancedMode, forKey: Keys.isAdvancedMode)
        }
    }

    init() {
        isAdvancedMode = UserDefaults.standard.bool(forKey: Keys.isAdvancedMode)
    }
}

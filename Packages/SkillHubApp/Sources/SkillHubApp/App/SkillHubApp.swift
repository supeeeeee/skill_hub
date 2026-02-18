import SwiftUI
import SkillHubCore

@main
struct SkillHubApp: App {
    @StateObject private var viewModel = SkillHubViewModel()
    @StateObject private var preferences = UserPreferences()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(viewModel)
                .environmentObject(preferences)
        }
        .windowStyle(.hiddenTitleBar)
        .commands {
            SidebarCommands()
        }
    }
}

import SwiftUI
import SkillHubCore

@main
struct SkillHubApp: App {
    @StateObject private var viewModel = SkillHubViewModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(viewModel)
        }
        .windowStyle(.hiddenTitleBar)
        .commands {
            SidebarCommands()
        }
    }
}

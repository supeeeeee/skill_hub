import SwiftUI
import SkillHubCore
#if os(macOS)
import AppKit
#endif

@main
struct SkillHubApp: App {
    @StateObject private var viewModel = SkillHubViewModel()
#if os(macOS)
    @State private var didActivateApp = false
#endif

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(viewModel)
#if os(macOS)
                .onAppear {
                    guard !didActivateApp else { return }
                    didActivateApp = true
                    NSApp.setActivationPolicy(.regular)
                    NSApp.activate(ignoringOtherApps: true)
                }
#endif
        }
        .windowStyle(.hiddenTitleBar)
        .commands {
            SidebarCommands()
        }
    }
}

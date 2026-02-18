import SwiftUI
import SkillHubCore

enum NavigationItem: Hashable, Identifiable {
    case products
    case skills
    case discover
    
    var id: Self { self }
}

struct ContentView: View {
    @EnvironmentObject private var viewModel: SkillHubViewModel
    @EnvironmentObject private var preferences: UserPreferences
    @State private var selectedItem: NavigationItem? = .products
    @State private var columnVisibility: NavigationSplitViewVisibility = .all
    @State private var showCommandPalette = false
    @State private var showSettings = false
    
    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            List(selection: $selectedItem) {
                Label("Products", systemImage: "macbook.and.iphone")
                    .tag(NavigationItem.products)
                Label("Skills", systemImage: "wrench.and.screwdriver")
                    .tag(NavigationItem.skills)
                Label("Discover", systemImage: "safari")
                    .tag(NavigationItem.discover)
            }
            .navigationTitle("SkillHub")
            .listStyle(.sidebar)
        } detail: {
            if let item = selectedItem {
                NavigationStack {
                    switch item {
                    case .products:
                        ProductsView()
                    case .skills:
                        SkillsView()
                    case .discover:
                        DiscoverView()
                    }
                }
                .id(item)
            } else {
                Text("Select an item")
                    .foregroundStyle(.secondary)
            }
        }
        #if os(macOS)
        .background(VisualEffect().ignoresSafeArea())
        #endif
        .sheet(isPresented: $showCommandPalette) {
            VStack(spacing: 20) {
                Image(systemName: "command")
                    .font(.system(size: 40))
                Text("Command Palette")
                    .font(.title)
                Text("This is a stub for the command palette.\nFuture versions will allow quick actions here.")
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)
                Button("Close") {
                    showCommandPalette = false
                }
                .keyboardShortcut(.cancelAction)
            }
            .padding()
            .frame(width: 400, height: 250)
        }
        .sheet(isPresented: $showSettings) {
            SettingsView()
        }
        .toolbar {
            ToolbarItemGroup(placement: .automatic) {
                Toggle(isOn: $preferences.isAdvancedMode) {
                    Text(preferences.isAdvancedMode ? "Pro" : "Simple")
                }
                .toggleStyle(.switch)
                .help("Switch between Simple and Pro mode")

                Button {
                    showSettings = true
                } label: {
                    Label("Settings", systemImage: "gearshape")
                }
            }
        }
        .overlay(alignment: .topTrailing) {
            ToastHostView(toasts: $viewModel.toasts)
                .padding(.top, 16)
                .padding(.trailing, 16)
        }
        .background(
            Button("Toggle Command Palette") {
                showCommandPalette.toggle()
            }
            .keyboardShortcut("k", modifiers: .command)
            .opacity(0)
        )
    }
}

#if os(macOS)
struct VisualEffect: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.blendingMode = .behindWindow
        view.state = .active
        view.material = .sidebar
        return view
    }
    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {}
}
#endif

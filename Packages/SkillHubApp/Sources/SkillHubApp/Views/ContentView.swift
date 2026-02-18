import SwiftUI
import SkillHubCore

enum NavigationItem: Hashable, Identifiable {
    case products
    case skills
    
    var id: Self { self }
}

struct ContentView: View {
    @EnvironmentObject private var viewModel: SkillHubViewModel
    @State private var selectedItem: NavigationItem? = .products
    @State private var columnVisibility: NavigationSplitViewVisibility = .all
    @State private var showCommandPalette = false
    
    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            List(selection: $selectedItem) {
                Label("Products", systemImage: "macbook.and.iphone")
                    .tag(NavigationItem.products)
                Label("Skills", systemImage: "wrench.and.screwdriver")
                    .tag(NavigationItem.skills)
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

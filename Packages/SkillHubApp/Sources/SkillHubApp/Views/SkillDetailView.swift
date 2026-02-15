import SwiftUI
import SkillHubCore

struct SkillDetailView: View {
    let skill: InstalledSkillRecord
    @EnvironmentObject var viewModel: SkillHubViewModel
    @State private var showApplySheet = false
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(skill.manifest.name)
                            .font(.largeTitle)
                            .fontWeight(.bold)
                        Text(skill.manifest.summary)
                            .font(.title3)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    VStack(alignment: .trailing) {
                        Text("v\(skill.manifest.version)")
                            .font(.headline)
                            .padding(6)
                            .background(Color.secondary.opacity(0.1))
                            .cornerRadius(6)
                    }
                }
                .padding()
                .background(Color(nsColor: .controlBackgroundColor))
                .cornerRadius(12)
                
                // Bindings
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Bindings")
                            .font(.headline)
                        Spacer()
                        Button("Add Binding") {
                            showApplySheet = true
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                    
                    if skill.manifest.adapters.isEmpty && skill.installedProducts.isEmpty {
                        Text("No bindings configured")
                            .foregroundColor(.secondary)
                    } else {
                        ForEach(skill.manifest.adapters, id: \.productID) { adapter in
                            if let productAdapter = try? viewModel.adapterRegistry.adapter(for: adapter.productID) {
                                let actualMode = skill.lastInstallModeByProduct[adapter.productID] ?? adapter.installMode
                                BindingRowView(
                                    productID: adapter.productID,
                                    installMode: actualMode,
                                    status: productAdapter.status(skillID: skill.manifest.id)
                                )
                            }
                        }
                    }
                }
                .padding()
                .background(Color(nsColor: .controlBackgroundColor))
                .cornerRadius(12)
                
                // Recent Activity
                VStack(alignment: .leading, spacing: 12) {
                    Text("Recent Activity")
                        .font(.headline)
                    
                    ForEach(viewModel.logs) { log in
                        InlineLogView(log: log)
                    }
                }
                .padding()
                .background(Color(nsColor: .controlBackgroundColor))
                .cornerRadius(12)
            }
            .padding()
        }
        .navigationTitle(skill.manifest.name)
        .background(Color(nsColor: .windowBackgroundColor))
        .sheet(isPresented: $showApplySheet) {
            ApplySkillView(skill: skill, isPresented: $showApplySheet)
        }
    }
}

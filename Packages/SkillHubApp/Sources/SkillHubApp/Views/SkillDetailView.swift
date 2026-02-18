import SwiftUI
import SkillHubCore

struct SkillDetailView: View {
    let skill: InstalledSkillRecord
    @EnvironmentObject var viewModel: SkillHubViewModel
    @EnvironmentObject var preferences: UserPreferences
    
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
                
                // Deployed Products
                VStack(alignment: .leading, spacing: 12) {
                    Text("Deployed Products")
                        .font(.headline)
                    
                    if viewModel.products.isEmpty {
                        Text("No products detected")
                            .foregroundColor(.secondary)
                    } else {
                        ForEach(viewModel.products) { product in
                            if let adapter = try? viewModel.adapterRegistry.adapter(for: product.id) {
                                let status = adapter.status(skillID: skill.manifest.id)
                                let installMode = skill.lastDeployModeByProduct[product.id]
                                
                                InstalledProductRowView(
                                    product: product,
                                    installMode: installMode,
                                    status: status,
                                    showAdvancedMode: preferences.isAdvancedMode
                                )
                            }
                        }
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
    }
}

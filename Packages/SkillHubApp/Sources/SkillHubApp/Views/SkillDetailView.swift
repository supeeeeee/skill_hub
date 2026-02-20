import SwiftUI
import SkillHubCore

struct SkillDetailView: View {
    @StateObject private var detailViewModel: SkillDetailViewModel
    @EnvironmentObject var hubViewModel: SkillHubViewModel
    @State private var showingBatchManagement = false
    @State private var showingDisableConfirm = false
    
    init(skill: InstalledSkillRecord) {
        _detailViewModel = StateObject(wrappedValue: SkillDetailViewModel(skill: skill))
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Header
                HStack(alignment: .top, spacing: 16) {
                    Image(systemName: "puzzlepiece.extension.fill")
                        .font(.system(size: 48))
                        .foregroundColor(.accentColor)
                        .padding()
                        .background(Color.accentColor.opacity(0.1))
                        .cornerRadius(12)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(detailViewModel.skill.manifest.name)
                                .font(.largeTitle)
                                .fontWeight(.bold)
                            
                            Spacer()
                            
                            Text("v\(detailViewModel.skill.manifest.version)")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.secondary.opacity(0.1))
                                .cornerRadius(6)
                        }
                        
                        Text(detailViewModel.skill.manifest.summary)
                            .font(.title3)
                            .foregroundColor(.secondary)
                    }
                }
                .padding()
                .background(Color(nsColor: .controlBackgroundColor))
                .cornerRadius(16)
                .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
                
                // Actions Toolbar
                HStack(spacing: 16) {
                    Button(action: { showingBatchManagement = true }) {
                        Label("Enable on Products", systemImage: "plus.square.on.square")
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    
                    Button(role: .destructive, action: { showingDisableConfirm = true }) {
                        Label("Disable on All Products", systemImage: "power.circle")
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("Lifecycle")
                        .font(.headline)
                    Text("Source -> Installed in SkillHub -> Enabled on Product -> Disabled or Uninstalled on Product")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(nsColor: .controlBackgroundColor))
                .cornerRadius(10)
                
                VStack(alignment: .leading, spacing: 16) {
                    Text("Product Activation")
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    if hubViewModel.products.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "magnifyingglass")
                                .font(.largeTitle)
                                .foregroundColor(.secondary)
                            Text("No products detected")
                                .font(.headline)
                                .foregroundColor(.secondary)
                            Text("Install this skill to SkillHub first, then enable it per product.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(32)
                        .background(Color(nsColor: .controlBackgroundColor))
                        .cornerRadius(12)
                    } else {
                        LazyVStack(spacing: 12) {
                            ForEach(hubViewModel.products) { product in
                                if let adapter = try? hubViewModel.adapterRegistry.adapter(for: product.id) {
                                    let status = adapter.status(skillID: detailViewModel.skill.manifest.id)
                                     
                                    InstalledProductRowView(
                                        product: product,
                                        status: status,
                                        onInstall: {
                                            Task {
                                                await detailViewModel.enable(on: product.id)
                                            }
                                        },
                                        onToggle: {
                                            Task {
                                                await detailViewModel.toggleEnable(on: product.id)
                                            }
                                        }
                                    )
                                }
                            }
                        }
                    }
                }
            }
            .padding()
        }
        .navigationTitle(detailViewModel.skill.manifest.name)
        .background(Color(nsColor: .windowBackgroundColor))
        .onAppear {
            detailViewModel.setHubViewModel(hubViewModel)
        }
        .sheet(isPresented: $showingBatchManagement) {
            BatchManagementView(skill: detailViewModel.skill, detailViewModel: detailViewModel)
                .environmentObject(hubViewModel)
        }
        .alert("Confirm Disable All", isPresented: $showingDisableConfirm) {
            Button("Cancel", role: .cancel) { }
            Button("Disable", role: .destructive) {
                Task {
                    await detailViewModel.disableAllProducts()
                }
            }
        } message: {
            Text("Are you sure you want to disable this skill on all products? This will not uninstall the skill.")
        }
    }
}

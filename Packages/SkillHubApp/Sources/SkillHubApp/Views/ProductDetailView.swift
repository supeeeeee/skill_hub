import SwiftUI
import SkillHubCore

struct ProductDetailView: View {
    let product: Product
    @EnvironmentObject var viewModel: SkillHubViewModel
    @State private var setupSkill: InstalledSkillRecord?
    @State private var filter: FilterState = .all
    @State private var searchText = ""
    @State private var productDetection: ProductDetectionResult?
    
    enum FilterState: String, CaseIterable, Identifiable {
        case all = "All"
        case installed = "Installed"
        case enabled = "Enabled"
        var id: String { rawValue }
    }
    
    var filteredSkills: [InstalledSkillRecord] {
        viewModel.skills.filter { skill in
            let matchesSearch = searchText.isEmpty ||
                skill.manifest.name.localizedCaseInsensitiveContains(searchText) ||
                skill.manifest.id.localizedCaseInsensitiveContains(searchText)
            guard matchesSearch else { return false }
            switch filter {
            case .all: return true
            case .installed: return skill.installedProducts.contains(product.id)
            case .enabled: return skill.enabledProducts.contains(product.id)
            }
        }
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Product Summary Card
                HStack(alignment: .top, spacing: 16) {
                    Image(systemName: product.iconName)
                        .font(.system(size: 48))
                        .foregroundColor(.accentColor)
                        .frame(width: 64, height: 64)
                        .background(Color.accentColor.opacity(0.1))
                        .cornerRadius(12)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text(product.name)
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        Text(product.description)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        HStack(spacing: 8) {
                            StatusBadgeView(status: productDetection?.isDetected == true ? .active : .notInstalled)
                            
                            ForEach(product.supportedModes, id: \.self) { mode in
                                ModePillView(mode: mode)
                            }
                        }
                    }
                    
                    Spacer()
                }
                .padding()
                .background(Color.accentColor.opacity(0.1))
                .cornerRadius(12)
                
                Divider()
                
                // Skills Section Header
                HStack {
                    Text("Skills")
                        .font(.headline)
                        .fontWeight(.bold)
                    
                    Spacer()
                    
                    if productDetection?.isDetected != true {
                        Button("Run Doctor") {
                            // Navigate to Doctor or show hint
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                }
                
                // Filters & Search
                if !viewModel.skills.isEmpty {
                    VStack(spacing: 12) {
                        Picker("Filter", selection: $filter) {
                            ForEach(FilterState.allCases) { f in
                                Text(f.rawValue).tag(f)
                            }
                        }
                        .pickerStyle(.segmented)
                        
                        TextField("Search skills (name or ID)...", text: $searchText)
                            .textFieldStyle(.roundedBorder)
                    }
                }
                
                // Skills List
                if viewModel.skills.isEmpty {
                    Text("No skills installed.")
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding()
                } else if filteredSkills.isEmpty {
                    Text("No matching skills found.")
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding()
                } else {
                    LazyVStack(spacing: 12) {
                        ForEach(filteredSkills) { skill in
                            ProductSkillRow(
                                product: product,
                                skill: skill,
                                productDetected: productDetection?.isDetected ?? false,
                                onSetup: { setupSkill = skill }
                            )
                        }
                    }
                }
            }
            .padding()
        }
        .navigationTitle(product.name)
        .onAppear {
            if let adapter = try? viewModel.adapterRegistry.adapter(for: product.id) {
                productDetection = adapter.detect()
            }
        }
        .sheet(item: $setupSkill) { skill in
            ApplySkillView(
                skill: skill,
                preselectedProductID: product.id,
                isPresented: Binding(
                    get: { setupSkill != nil },
                    set: { if !$0 { setupSkill = nil } }
                )
            )
        }
    }
}

struct ProductSkillRow: View {
    let product: Product
    let skill: InstalledSkillRecord
    let productDetected: Bool
    let onSetup: () -> Void
    @EnvironmentObject var viewModel: SkillHubViewModel
    
    private var isInstalled: Bool {
        skill.installedProducts.contains(product.id)
    }
    
    private var isEnabled: Bool {
        skill.enabledProducts.contains(product.id)
    }
    
    private var installMode: InstallMode? {
        skill.lastInstallModeByProduct[product.id]
    }
    
    private var statusDetail: String {
        if !productDetected { return "Product not detected" }
        if !isInstalled { return "Not installed" }
        if let mode = installMode {
            return isEnabled ? "Enabled (\(mode.rawValue)" : "Installed (\(mode.rawValue)"
        }
        return isEnabled ? "Enabled" : "Installed"
    }
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "wrench.and.screwdriver.fill")
                .font(.title2)
                .foregroundColor(.accentColor)
                .frame(width: 44, height: 44)
                .background(Color.accentColor.opacity(0.1))
                .cornerRadius(8)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(skill.manifest.name)
                    .font(.headline)
                Text(statusDetail)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // CTA Area
            if !productDetected {
                Button("Run Doctor") {
                    // Guide user
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(true)
            } else if !isInstalled {
                Button("Setup & Enable") {
                    onSetup()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            } else if !isEnabled {
                Button("Enable") {
                    Task {
                        await viewModel.setSkillEnabled(manifest: skill.manifest, productID: product.id, enabled: true)
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            } else {
                Button("Disable") {
                    Task {
                        await viewModel.setSkillEnabled(manifest: skill.manifest, productID: product.id, enabled: false)
                    }
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .tint(.orange)
            }
        }
        .padding()
        .background(Color.accentColor.opacity(0.1))
        .cornerRadius(8)
    }
}

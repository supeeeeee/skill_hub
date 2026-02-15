import SwiftUI
import SkillHubCore

struct ProductDetailView: View {
    let product: Product
    @EnvironmentObject var viewModel: SkillHubViewModel
    @State private var setupSkill: InstalledSkillRecord?
    @State private var filter: FilterState = .all
    @State private var searchText = ""
    @State private var productDetection: ProductDetectionResult?
    @State private var showPathEditor = false
    @State private var editingPath = ""
    
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
                
                // Skills Directory Section
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Label("Skills Directory", systemImage: "folder")
                            .font(.headline)
                        
                        Spacer()
                        
                        Button(action: {
                            editingPath = product.customSkillsPath ?? defaultSkillsPath(for: product.id)
                            showPathEditor = true
                        }) {
                            Label("Edit", systemImage: "pencil")
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                    
                    HStack {
                        Image(systemName: "folder.fill")
                            .foregroundColor(.secondary)
                        Text(product.customSkillsPath ?? defaultSkillsPath(for: product.id))
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                        Spacer()
                    }
                    .padding(12)
                    .background(Color(nsColor: .controlBackgroundColor))
                    .cornerRadius(8)
                }
                
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
        .sheet(isPresented: $showPathEditor) {
            VStack(spacing: 20) {
                HStack {
                    Text("Edit Skills Directory")
                        .font(.title2)
                        .fontWeight(.bold)
                    Spacer()
                    Button(action: { showPathEditor = false }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
                
                HStack {
                    Image(systemName: "app.badge")
                        .font(.title2)
                        .foregroundColor(.accentColor)
                    Text(product.name)
                        .font(.headline)
                }
                
                Divider()
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Custom Skills Directory")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    TextField("Enter custom path or leave empty for default", text: $editingPath)
                        .textFieldStyle(.roundedBorder)
                    
                    Button(action: { editingPath = "" }) {
                        Label("Use Default Path", systemImage: "arrow.counterclockwise")
                            .font(.caption)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Will use:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(editingPath.isEmpty ? defaultSkillsPath(for: product.id) : editingPath)
                        .font(.caption)
                        .foregroundColor(editingPath.isEmpty ? .orange : .primary)
                        .padding(8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.secondary.opacity(0.1))
                        .cornerRadius(6)
                }
                
                Spacer()
                
                HStack {
                    Button("Cancel") {
                        showPathEditor = false
                    }
                    .buttonStyle(.bordered)
                    
                    Spacer()
                    
                    Button("Save") {
                        do {
                            var cfg = SkillHubConfig.load()
                            let trimmed = editingPath.trimmingCharacters(in: .whitespacesAndNewlines)
                            if trimmed.isEmpty {
                                cfg.productSkillsDirectoryOverrides.removeValue(forKey: product.id)
                            } else {
                                cfg.productSkillsDirectoryOverrides[product.id] = trimmed
                            }
                            try cfg.save()
                            viewModel.loadData()
                            showPathEditor = false
                        } catch {
                            // Best-effort: just close for now
                            showPathEditor = false
                        }
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .padding(20)
            .frame(width: 450, height: 350)
        }
    }
    
    private func defaultSkillsPath(for productID: String) -> String {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        switch productID {
        case "openclaw": return "\(home)/.openclaw/skills"
        case "opencode": return "\(home)/.config/opencode/skills"
        case "codex": return "\(home)/.codex/skills"
        case "cursor": return "\(home)/.cursor/skills"
        case "claude-code": return "\(home)/.claude/skills"
        default: return "\(home)/.skillhub/products/\(productID)/skills"
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

struct CustomPathEditorSheet: View {
    let productName: String
    let currentPath: String
    @Binding var isPresented: Bool
    let onSave: (String) -> Void
    
    @State private var customPath: String = ""
    @State private var showError = false
    
    var body: some View {
        VStack(spacing: 20) {
            // Header
            HStack {
                Text("Edit Skills Directory")
                    .font(.title2)
                    .fontWeight(.bold)
                Spacer()
                Button(action: { isPresented = false }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            
            // Product info
            HStack {
                Image(systemName: "app.badge")
                    .font(.title2)
                    .foregroundColor(.accentColor)
                Text(productName)
                    .font(.headline)
            }
            
            Divider()
            
            // Path input
            VStack(alignment: .leading, spacing: 8) {
                Text("Custom Skills Directory")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                TextField("Enter custom path or leave empty for default", text: $customPath)
                    .textFieldStyle(.roundedBorder)
                    .onChange(of: customPath) { newValue in
                        showError = !newValue.isEmpty && !newValue.hasPrefix("/")
                    }
                
                if showError {
                    Text("Path must be an absolute path (start with /)")
                        .font(.caption)
                        .foregroundColor(.red)
                }
                
                // Reset button
                Button(action: { customPath = "" }) {
                    Label("Use Default Path", systemImage: "arrow.counterclockwise")
                        .font(.caption)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
            
            // Current path preview
            VStack(alignment: .leading, spacing: 4) {
                Text("Will use:")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(customPath.isEmpty ? currentPath : customPath)
                    .font(.caption)
                    .foregroundColor(customPath.isEmpty ? .orange : .primary)
                    .padding(8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.secondary.opacity(0.1))
                    .cornerRadius(6)
            }
            
            Spacer()
            
            // Actions
            HStack {
                Button("Cancel") {
                    isPresented = false
                }
                .buttonStyle(.bordered)
                
                Spacer()
                
                Button("Save") {
                    onSave(customPath)
                    isPresented = false
                }
                .buttonStyle(.borderedProminent)
                .disabled(showError)
            }
        }
        .padding(20)
        .frame(width: 450, height: 350)
        .onAppear {
            customPath = currentPath
        }
    }
}

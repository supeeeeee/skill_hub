import SwiftUI
import SkillHubCore

struct ProductDetailView: View {
    let product: Product
    @EnvironmentObject var viewModel: SkillHubViewModel
    @EnvironmentObject var preferences: UserPreferences
    @State private var setupSkill: InstalledSkillRecord?
    @State private var searchText = ""
    @State private var productDetection: ProductDetectionResult?
    @State private var showPathEditor = false
    @State private var editingPath = ""

    var activeSkills: [InstalledSkillRecord] {
        viewModel.skills.filter { skill in
            matchesSearch(skill) && skill.deployedProducts.contains(product.id)
        }
    }

    var librarySkills: [InstalledSkillRecord] {
        viewModel.skills.filter { skill in
            matchesSearch(skill) && !skill.deployedProducts.contains(product.id)
        }
    }

    private func matchesSearch(_ skill: InstalledSkillRecord) -> Bool {
        searchText.isEmpty ||
        skill.manifest.name.localizedCaseInsensitiveContains(searchText) ||
        skill.manifest.id.localizedCaseInsensitiveContains(searchText)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Product Summary Card
                HStack(alignment: .top, spacing: 20) {
                    Image(systemName: product.iconName)
                        .font(.system(size: 48))
                        .foregroundColor(.accentColor)
                        .frame(width: 80, height: 80)
                        .background(Color.accentColor.opacity(0.1))
                        .cornerRadius(16)

                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(product.name)
                                .font(.title2)
                                .fontWeight(.bold)

                            Spacer()

                            // Summary Badge
                            if !activeSkills.isEmpty {
                                HStack(spacing: 4) {
                                    Image(systemName: "bolt.fill")
                                        .font(.caption2)
                                    Text("\(activeSkills.count) Active")
                                        .font(.caption)
                                        .fontWeight(.semibold)
                                }
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.accentColor.opacity(0.1))
                                .foregroundColor(.accentColor)
                                .cornerRadius(12)
                            }

                            // Health Badge
                            HStack(spacing: 4) {
                                Image(systemName: healthIcon(for: product.health))
                                    .font(.caption2)
                                Text(product.health.rawValue.capitalized)
                                    .font(.caption)
                                    .fontWeight(.semibold)
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(healthColor(for: product.health).opacity(0.1))
                            .foregroundColor(healthColor(for: product.health))
                            .cornerRadius(12)
                        }

                        Text(product.description)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .lineLimit(2)

                        HStack(spacing: 8) {
                            StatusBadgeView(status: productDetection?.isDetected == true ? .active : .notInstalled)

                            ForEach(product.supportedModes.filter { preferences.isAdvancedMode || $0 != .configPatch }, id: \.self) { mode in
                                ModePillView(mode: mode)
                            }
                        }
                    }
                }
                .padding(20)
                .background(Color(nsColor: .controlBackgroundColor))
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.secondary.opacity(0.1), lineWidth: 1)
                )

                if preferences.isAdvancedMode {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Label("Skills Directory", systemImage: "folder")
                                .font(.headline)

                            Spacer()

                            Button(action: {
                                editingPath = resolvedSkillsPath(for: product.id)
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
                            Text(resolvedSkillsPath(for: product.id))
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
                }

                // Skills Section Header
                HStack {
                    Text("Skills Management")
                        .font(.title3)
                        .fontWeight(.semibold)

                    Spacer()

                    HStack(spacing: 12) {
                        Button(action: {
                            viewModel.checkForUpdates(for: product.id)
                        }) {
                            Label("Check Updates", systemImage: "arrow.triangle.2.circlepath")
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)

                        if productDetection?.isDetected == true || product.health != .healthy {
                            Button(action: {
                                viewModel.runDoctor(for: product.id)
                            }) {
                                Label("Run Doctor", systemImage: "stethoscope")
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                            .tint(.orange)
                        }
                    }
                }

                // Health Result Display
                if let issue = viewModel.healthResults[product.id] {
                    HStack {
                        Image(systemName: "info.circle.fill")
                            .foregroundColor(.secondary)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text(issue.message)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.leading)
                            
                            if issue.isFixable, let label = issue.suggestion?.label {
                                Button(action: {
                                    Task {
                                        await viewModel.fixIssue(for: product.id)
                                    }
                                }) {
                                    Label(label, systemImage: "wand.and.stars")
                                        .font(.caption)
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                                .tint(.green)
                            }
                        }
                        
                        Spacer()
                        
                        Button(action: { viewModel.healthResults.removeValue(forKey: product.id) }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(12)
                    .background(Color(nsColor: .controlBackgroundColor))
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.orange.opacity(0.5), lineWidth: 1)
                    )
                    .padding(.bottom, 8)
                }

                // Filters & Search
                if !viewModel.skills.isEmpty {
                    TextField("Search skills (name or ID)...", text: $searchText)
                        .textFieldStyle(.roundedBorder)
                }

                // Skills List
                let unregistered = viewModel.unregisteredSkillsByProduct[product.id] ?? []
                let hasUnregistered = !unregistered.isEmpty

                if viewModel.skills.isEmpty && !hasUnregistered {
                    Text("No skills found in library.")
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding()
                } else if activeSkills.isEmpty && librarySkills.isEmpty && !hasUnregistered {
                    Text("No matching skills found.")
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding()
                } else {
                    LazyVStack(alignment: .leading, spacing: 32) {
                        // Detected Local Skills Section
                        if hasUnregistered {
                            VStack(alignment: .leading, spacing: 16) {
                                Label("Detected Local Skills", systemImage: "sparkles")
                                    .font(.headline)
                                    .foregroundColor(.purple)
                                    .padding(.horizontal, 4)

                                VStack(spacing: 12) {
                                    ForEach(unregistered, id: \.id) { manifest in
                                        UnregisteredSkillRow(manifest: manifest, product: product)
                                    }
                                }
                            }
                        }

                        // Active Skills Section
                        if !activeSkills.isEmpty {
                            VStack(alignment: .leading, spacing: 16) {
                                Label("Deployed & Active", systemImage: "checkmark.circle.fill")
                                    .font(.headline)
                                    .foregroundColor(.green)
                                    .padding(.horizontal, 4)

                                VStack(spacing: 12) {
                                    ForEach(activeSkills) { skill in
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

                        // Library Skills Section
                        if !librarySkills.isEmpty {
                            VStack(alignment: .leading, spacing: 16) {
                                Label("Available from Library", systemImage: "books.vertical.fill")
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                    .padding(.horizontal, 4)

                                VStack(spacing: 12) {
                                    ForEach(librarySkills) { skill in
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
                    }
                }
            }
            .padding(24)
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
            CustomPathEditorSheet(
                productName: product.name,
                currentPath: editingPath,
                isPresented: $showPathEditor,
                onSave: { newPath in
                    do {
                        var cfg = SkillHubConfig.load()
                        let trimmed = newPath.trimmingCharacters(in: .whitespacesAndNewlines)
                        if trimmed.isEmpty {
                            cfg.productSkillsDirectoryOverrides.removeValue(forKey: product.id)
                        } else {
                            cfg.productSkillsDirectoryOverrides[product.id] = trimmed
                        }
                        try cfg.save()
                        viewModel.loadData()
                    } catch {
                        print("Failed to save config: \(error)")
                    }
                }
            )
        }
    }

    private func resolvedSkillsPath(for productID: String) -> String {
        guard let adapter = try? viewModel.adapterRegistry.adapter(for: productID) else {
            return "Unavailable"
        }
        return adapter.skillsDirectory().path
    }

    private func healthIcon(for status: HealthStatus) -> String {
        switch status {
        case .healthy: return "checkmark.shield.fill"
        case .warning: return "exclamationmark.shield.fill"
        case .error: return "xmark.shield.fill"
        case .unknown: return "shield.slash"
        }
    }

    private func healthColor(for status: HealthStatus) -> Color {
        switch status {
        case .healthy: return .green
        case .warning: return .orange
        case .error: return .red
        case .unknown: return .secondary
        }
    }
}

struct UnregisteredSkillRow: View {
    let manifest: SkillManifest
    let product: Product
    @EnvironmentObject var viewModel: SkillHubViewModel

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "sparkles")
                .font(.title2)
                .foregroundColor(.purple)
                .frame(width: 44, height: 44)
                .background(Color.purple.opacity(0.1))
                .cornerRadius(8)

            VStack(alignment: .leading, spacing: 4) {
                Text(manifest.name)
                    .font(.headline)
                Text("Found locally in \(product.name)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Button("Acquire & Manage") {
                Task {
                    await viewModel.acquireSkill(manifest: manifest, fromProduct: product.id)
                }
            }
            .buttonStyle(.borderedProminent)
            .tint(.purple)
            .controlSize(.small)
        }
        .padding()
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.purple.opacity(0.3), lineWidth: 1)
        )
    }
}

struct ProductSkillRow: View {
    let product: Product
    let skill: InstalledSkillRecord
    let productDetected: Bool
    let onSetup: () -> Void
    @EnvironmentObject var viewModel: SkillHubViewModel
    @EnvironmentObject var preferences: UserPreferences

    private var isInstalled: Bool {
        skill.deployedProducts.contains(product.id)
    }

    private var isEnabled: Bool {
        skill.enabledProducts.contains(product.id)
    }

    private var installMode: InstallMode? {
        skill.lastDeployModeByProduct[product.id]
    }

    private var statusDetail: String {
        if !productDetected { return "Product not detected" }
        if !isInstalled { return "Available to deploy" }

        let status = isEnabled ? "Enabled" : "Disabled"
        if let mode = installMode {
            let modeLabel: String
            switch mode {
            case .symlink: modeLabel = "Synced"
            case .copy: modeLabel = "Standalone Copy"
            case .configPatch: modeLabel = "Native"
            case .auto: modeLabel = "Smart Deploy"
            default: modeLabel = "Unknown"
            }
            return preferences.isAdvancedMode ? "\(status) (\(modeLabel))" : status
        }
        return status
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: isInstalled ? "checkmark.circle.fill" : "arrow.down.circle")
                .font(.title2)
                .foregroundColor(isInstalled ? (isEnabled ? .green : .secondary) : .accentColor)
                .frame(width: 44, height: 44)
                .background(Color.accentColor.opacity(0.1))
                .cornerRadius(8)

            VStack(alignment: .leading, spacing: 4) {
                Text(skill.manifest.name)
                    .font(.headline)
                Text(statusDetail)
                    .font(.caption)
                    .foregroundColor(isEnabled ? .primary : .secondary)
            }

            Spacer()

            if !productDetected {
                Button("Run Doctor") {}
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .disabled(true)
            } else if !isInstalled {
                Button("Deploy to Product") {
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
            }
        }
        .padding()
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
        )
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

            HStack {
                Image(systemName: "app.badge")
                    .font(.title2)
                    .foregroundColor(.accentColor)
                Text(productName)
                    .font(.headline)
            }

            Divider()

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

                Button(action: { customPath = "" }) {
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
                Text(customPath.isEmpty ? currentPath : customPath)
                    .font(.caption)
                    .foregroundColor(customPath.isEmpty ? .orange : .primary)
                    .padding(8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.secondary.opacity(0.1))
                    .cornerRadius(6)
            }

            Spacer()

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

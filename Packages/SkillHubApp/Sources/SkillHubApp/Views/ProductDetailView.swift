import SwiftUI
import SkillHubCore

struct ProductDetailView: View {
    let product: Product
    @EnvironmentObject var viewModel: SkillHubViewModel
    @State private var setupSkill: InstalledSkillRecord?
    @State private var searchText = ""
    @State private var productDetection: ProductDetectionResult?
    @State private var showPathEditor = false
    @State private var editingPath = ""
    @State private var showConfigPathEditor = false
    @State private var editingConfigPath = ""
    @State private var isHoveringHeader = false

    private var currentProduct: Product {
        viewModel.products.first(where: { $0.id == product.id }) ?? product
    }

    var activeSkills: [InstalledSkillRecord] {
        viewModel.skills.filter { skill in
            skill.installedProducts.contains(product.id)
        }
    }

    var projectSkills: [InstalledSkillRecord] {
        viewModel.skills.filter { matchesSearch($0) }
            .sorted { s1, s2 in
                let p1 = s1.installedProducts.contains(product.id)
                let p2 = s2.installedProducts.contains(product.id)
                if p1 && !p2 { return true }
                if !p1 && p2 { return false }
                return s1.manifest.name < s2.manifest.name
            }
    }

    private func matchesSearch(_ skill: InstalledSkillRecord) -> Bool {
        searchText.isEmpty ||
        skill.manifest.name.localizedCaseInsensitiveContains(searchText) ||
        skill.manifest.id.localizedCaseInsensitiveContains(searchText)
    }

    var body: some View {
        ZStack {
            // Immersive Background
            LinearGradient(
                colors: [
                    Color(nsColor: .windowBackgroundColor),
                    Color(nsColor: .controlBackgroundColor).opacity(0.8)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 24) {
                    // 1. Compact Header Section
                    headerSection
                        .padding(.top, 8)

                    // 2. Configuration Grid (Compact)
                    configGridSection

                    // 3. Health Issues (if any)
                    if let issue = viewModel.healthResults[product.id] {
                        HealthIssueCard(issue: issue,
                                        onFix: {
                                            Task {
                                                await viewModel.fixIssue(for: product.id)
                                            }
                                        },
                                        onDismiss: { viewModel.healthResults.removeValue(forKey: product.id) })
                            .transition(AnyTransition.move(edge: .top).combined(with: .opacity))
                    }

                    // 4. Skills Directory
                    skillsDirectorySection
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 40)
            }
        }
        .navigationTitle(product.name)
        .onAppear {
            if let adapter = try? viewModel.adapterRegistry.adapter(for: product.id) {
                withAnimation {
                    productDetection = adapter.detect()
                }
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
                    saveSkillsPath(newPath)
                }
            )
        }
        .sheet(isPresented: $showConfigPathEditor) {
            CustomConfigPathEditorSheet(
                productName: product.name,
                currentPath: editingConfigPath,
                isPresented: $showConfigPathEditor,
                onSave: { newPath in
                    viewModel.setProductConfigPath(productID: product.id, path: newPath)
                }
            )
        }
    }

    // MARK: - Sections

    private var headerSection: some View {
        HStack(alignment: .top, spacing: 20) {
            // Product Icon with Gradient
            ZStack {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [Color.accentColor.opacity(0.2), Color.accentColor.opacity(0.05)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .shadow(color: Color.accentColor.opacity(0.1), radius: 8, x: 0, y: 4)
                
                Image(systemName: product.iconName)
                    .font(.system(size: 40))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color.accentColor, Color.accentColor.opacity(0.7)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
            }
            .frame(width: 72, height: 72)

            // Info Column
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .center, spacing: 12) {
                    Text(product.name)
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    // Status Pill
                    HStack(spacing: 4) {
                        Circle()
                            .fill(productDetection?.isDetected == true ? Color.green : Color.secondary)
                            .frame(width: 8, height: 8)
                        Text(productDetection?.isDetected == true ? "Active" : "Not Detected")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.ultraThinMaterial)
                    .cornerRadius(12)
                }

                Text(product.description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(1)

                // Quick Actions Row
                HStack(spacing: 12) {
                    Button(action: { viewModel.checkForUpdates(for: product.id) }) {
                        Label("Check Updates", systemImage: "arrow.triangle.2.circlepath")
                            .font(.caption)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)

                    if productDetection?.isDetected == true || product.health != .healthy {
                        Button(action: { viewModel.runDoctor(for: product.id) }) {
                            Label("Run Doctor", systemImage: "stethoscope")
                                .font(.caption)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .tint(product.health == .healthy ? .secondary : .orange)
                    }
                }
                .padding(.top, 4)
            }
            
            Spacer()
            
            // Health Status Indicator (Compact)
            VStack(alignment: .trailing, spacing: 4) {
                Label(product.health.rawValue.capitalized, systemImage: healthIcon(for: product.health))
                    .font(.headline)
                    .foregroundColor(healthColor(for: product.health))
                
                Text("\(activeSkills.count) skills active")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(12)
            .background(.ultraThinMaterial)
            .cornerRadius(12)
        }
        .padding(20)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.6))
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 5)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.white.opacity(0.2), lineWidth: 1)
        )
        .onHover { hovering in
            withAnimation(.spring()) {
                isHoveringHeader = hovering
            }
        }
        .scaleEffect(isHoveringHeader ? 1.01 : 1.0)
    }

    private var configGridSection: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
            // Skills Path Card
            ConfigCard(
                title: "Skills Directory",
                icon: "folder.fill",
                path: resolvedSkillsPath(for: product.id),
                actionIcon: "pencil",
                action: {
                    editingPath = resolvedSkillsPath(for: product.id)
                    showPathEditor = true
                }
            )

            // Config Path Card
            if let configPath = resolvedConfigPath(for: product.id) {
                ConfigCard(
                    title: "Config Path",
                    icon: "doc.text.fill",
                    path: configPath,
                    isCustom: currentProduct.customConfigPath != nil,
                    actionIcon: "pencil",
                    action: {
                        editingConfigPath = currentProduct.customConfigPath ?? configPath
                        showConfigPathEditor = true
                    }
                )
            }
        }
    }

    private var skillsDirectorySection: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(alignment: .firstTextBaseline) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text("Skills Management")
                        .font(.title3)
                        .fontWeight(.semibold)
                    
                    let activeCount = activeSkills.count
                    let totalCount = viewModel.skills.count
                    
                    Text("\(activeCount) Active / \(totalCount) Total")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.secondary.opacity(0.1))
                        .cornerRadius(8)
                }
                
                Spacer()
                
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    TextField("Search skills...", text: $searchText)
                        .textFieldStyle(.plain)
                        .frame(width: 200)
                }
                .padding(8)
                .background(Color(nsColor: .controlBackgroundColor))
                .cornerRadius(8)
            }

            let unregistered = viewModel.unregisteredSkillsByProduct[product.id] ?? []
            let hasUnregistered = !unregistered.isEmpty

            if viewModel.skills.isEmpty && !hasUnregistered {
                emptyStateView(message: "No skills found in library.")
            } else if projectSkills.isEmpty && !hasUnregistered {
                emptyStateView(message: "No matching skills found.")
            } else {
                LazyVStack(spacing: 32) {
                    // Detected Local Skills
                    if hasUnregistered {
                        SectionHeader(title: "Detected Local Skills", icon: "sparkles", color: .purple)
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 16) {
                                ForEach(unregistered, id: \.id) { manifest in
                                    UnregisteredSkillCard(manifest: manifest, product: product)
                                        .frame(width: 260)
                                }
                            }
                            .padding(.horizontal, 4)
                            .padding(.bottom, 8)
                        }
                    }

                    // Merged Skills List
                    if !projectSkills.isEmpty {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 280), spacing: 16)], spacing: 16) {
                            ForEach(projectSkills) { skill in
                                SkillCard(
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

    private func emptyStateView(message: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "square.dashed")
                .font(.system(size: 48))
                .foregroundColor(.secondary.opacity(0.5))
            Text(message)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 40)
    }

    // MARK: - Helpers

    private func resolvedSkillsPath(for productID: String) -> String {
        guard let adapter = try? viewModel.adapterRegistry.adapter(for: productID) else {
            return "Unavailable"
        }
        return adapter.skillsDirectory().path
    }

    private func resolvedConfigPath(for productID: String) -> String? {
        guard let adapter = try? viewModel.adapterRegistry.adapter(for: productID) else {
            return nil
        }
        return adapter.configFilePath()?.path
    }
    
    private func saveSkillsPath(_ newPath: String) {
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

// MARK: - Subviews

struct ConfigCard: View {
    let title: String
    let icon: String
    let path: String
    var isCustom: Bool = false
    let actionIcon: String
    let action: () -> Void

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Label(title, systemImage: icon)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    if isCustom {
                        Text("Custom")
                            .font(.caption2)
                            .fontWeight(.bold)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.accentColor.opacity(0.2))
                            .foregroundColor(.accentColor)
                            .cornerRadius(4)
                    }
                }
                
                Text(path)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .help(path)
            }
            
            Spacer()
            
            Button(action: action) {
                Image(systemName: actionIcon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.secondary)
                    .padding(8)
                    .background(Color.secondary.opacity(0.1))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
        }
        .padding(16)
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
    }
}

struct SectionHeader: View {
    let title: String
    let icon: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(color)
            Text(title)
                .font(.title3)
                .fontWeight(.semibold)
            Spacer()
        }
        .padding(.vertical, 8)
    }
}

struct SkillCard: View {
    let product: Product
    let skill: InstalledSkillRecord
    let productDetected: Bool
    let onSetup: () -> Void
    @EnvironmentObject var viewModel: SkillHubViewModel
    @State private var isHovering = false
    @State private var isDeleting = false
    @State private var isToggling = false

    private var isInstalled: Bool {
        skill.installedProducts.contains(product.id)
    }

    private var isEnabled: Bool {
        skill.enabledProducts.contains(product.id)
    }

    private var statusDetail: String {
        if !productDetected { return "Product not detected" }
        if !isInstalled { return "Available to install" }
        return isEnabled ? "Enabled" : "Disabled"
    }
    
    // Modern status colors
    private var statusColor: Color {
        if !isInstalled { return .secondary }
        return isEnabled ? .green : .orange
    }

    var body: some View {
        HStack(spacing: 12) {
            // 1. Icon & Status Indicator
            ZStack(alignment: .bottomTrailing) {
                Image(systemName: "cube.box.fill") // Placeholder icon
                    .font(.title2)
                    .foregroundStyle(
                        isInstalled
                            ? (isEnabled
                               ? AnyShapeStyle(LinearGradient(colors: [.green, .mint], startPoint: .topLeading, endPoint: .bottomTrailing))
                               : AnyShapeStyle(LinearGradient(colors: [.orange.opacity(0.8), .orange], startPoint: .topLeading, endPoint: .bottomTrailing)))
                            : AnyShapeStyle(LinearGradient(colors: [.secondary, .gray], startPoint: .topLeading, endPoint: .bottomTrailing))
                    )
                    .frame(width: 44, height: 44)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color(nsColor: .controlBackgroundColor))
                            .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
                    )
                    .overlay(
                         RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(Color.primary.opacity(0.05), lineWidth: 1)
                    )
                
                if isInstalled {
                    Circle()
                        .fill(isEnabled ? Color.green : Color.orange)
                        .frame(width: 10, height: 10)
                        .overlay(Circle().stroke(Color(nsColor: .controlBackgroundColor), lineWidth: 2))
                        .offset(x: 2, y: 2)
                        .shadow(color: (isEnabled ? Color.green : Color.orange).opacity(0.3), radius: 2, x: 0, y: 1)
                }
            }
            
            // 2. Info
            VStack(alignment: .leading, spacing: 3) {
                Text(skill.manifest.name)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.primary)
                    .lineLimit(1)
                
                HStack(spacing: 6) {
                    Text("v\(skill.manifest.version)")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(Color.secondary.opacity(0.1))
                        .cornerRadius(4)
                    
                    Text(statusDetail)
                        .font(.caption2)
                        .foregroundColor(statusColor)
                }
            }
            
            Spacer()
            
            // 3. Actions (Compact & Modern)
            HStack(spacing: 8) {
                if !productDetected {
                     // No actions
                } else if !isInstalled {
                    Button(action: onSetup) {
                        Image(systemName: "arrow.down.circle.fill")
                            .font(.system(size: 20))
                            .foregroundColor(.accentColor)
                    }
                    .buttonStyle(.plain)
                    .help("Install Skill")
                } else {
                    // Actions visible on hover or always visible but subtle
                    if isHovering {
                        // Toggle Status
                        Button(action: {
                            withAnimation(.spring()) { isToggling = true }
                            Task {
                                await viewModel.setSkillEnabled(manifest: skill.manifest, productID: product.id, enabled: !isEnabled)
                                isToggling = false
                            }
                        }) {
                            ZStack {
                                if isToggling {
                                    ProgressView()
                                        .controlSize(.mini)
                                } else {
                                    Image(systemName: isEnabled ? "power.circle.fill" : "power.circle")
                                        .font(.system(size: 18))
                                        .foregroundColor(isEnabled ? .green : .secondary)
                                }
                            }
                            .frame(width: 28, height: 28)
                            .background(isEnabled ? Color.green.opacity(0.1) : Color.secondary.opacity(0.1))
                            .clipShape(Circle())
                        }
                        .buttonStyle(.plain)
                        .help(isEnabled ? "Disable Skill" : "Enable Skill")
                        .disabled(isToggling)
                        .transition(.scale.combined(with: .opacity))
                        
                        // Remove
                        Button(action: {
                            withAnimation(.spring()) { isDeleting = true }
                            Task {
                                await viewModel.uninstallSkill(manifest: skill.manifest, productID: product.id)
                                // No need to set isDeleting = false as card will disappear
                            }
                        }) {
                            ZStack {
                                if isDeleting {
                                    ProgressView()
                                        .controlSize(.mini)
                                } else {
                                    Image(systemName: "trash")
                                        .font(.system(size: 14))
                                        .foregroundColor(.red.opacity(0.8))
                                }
                            }
                            .frame(width: 28, height: 28)
                            .background(Color.red.opacity(0.1))
                            .clipShape(Circle())
                        }
                        .buttonStyle(.plain)
                        .help("Uninstall Skill")
                        .disabled(isDeleting)
                        .transition(.scale.combined(with: .opacity))
                    }
                }
            }
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isHovering)
        }
        .padding(12)
        .frame(height: 80) // Compact fixed height
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor))
                .shadow(
                    color: isHovering ? Color.black.opacity(0.1) : Color.black.opacity(0.04),
                    radius: isHovering ? 12 : 4,
                    x: 0,
                    y: isHovering ? 6 : 2
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(
                    isHovering ? Color.accentColor.opacity(0.3) : Color.primary.opacity(0.05),
                    lineWidth: isHovering ? 1 : 0.5
                )
        )
        .scaleEffect(isHovering ? 1.02 : 1.0)
        .onHover { hovering in
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                isHovering = hovering
            }
        }
    }
}

struct UnregisteredSkillCard: View {
    let manifest: SkillManifest
    let product: Product
    @EnvironmentObject var viewModel: SkillHubViewModel
    @State private var isHovering = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 10) {
                // Icon
                Image(systemName: "sparkles")
                    .font(.title3)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.purple, .blue],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 32, height: 32)
                    .background(
                        Circle()
                            .fill(.ultraThinMaterial)
                            .shadow(color: .purple.opacity(0.2), radius: 4, x: 0, y: 2)
                    )

                VStack(alignment: .leading, spacing: 2) {
                    Text(manifest.name)
                        .font(.headline)
                        .lineLimit(1)
                    Text("Found locally")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                Spacer()
            }
            
            Text(manifest.summary)
                .font(.caption)
                .foregroundColor(.secondary)
                .lineLimit(2)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            Spacer()

            Button(action: {
                Task { await viewModel.acquireSkill(manifest: manifest, fromProduct: product.id) }
            }) {
                HStack {
                    Text("Acquire")
                    Image(systemName: "arrow.right.circle.fill")
                }
                .fontWeight(.medium)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
            }
            .buttonStyle(.borderedProminent)
            .tint(.purple)
            .controlSize(.small)
            .clipShape(Capsule())
            .shadow(color: .purple.opacity(0.3), radius: 4, x: 0, y: 2)
        }
        .padding(12)
        .frame(height: 150)
        .background(.ultraThinMaterial)
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(
                    LinearGradient(
                        colors: [.purple.opacity(0.3), .clear],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
        .shadow(color: isHovering ? Color.black.opacity(0.15) : Color.black.opacity(0.05), radius: isHovering ? 12 : 6, x: 0, y: isHovering ? 6 : 3)
        .scaleEffect(isHovering ? 1.02 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isHovering)
        .onHover { hovering in
            isHovering = hovering
        }
    }
}

struct HealthIssueCard: View {
    let issue: DiagnosticIssue
    let onFix: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.title2)
                .foregroundColor(.orange)
                .padding(.top, 2)
            
            VStack(alignment: .leading, spacing: 4) {
                Text("Health Issue Detected")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Text(issue.message)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                
                if issue.isFixable, let label = issue.suggestion?.label {
                    Button(action: onFix) {
                        Label(label, systemImage: "wand.and.stars")
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.orange)
                    .controlSize(.small)
                    .padding(.top, 4)
                }
            }
            
            Spacer()
            
            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(16)
        .background(Color.orange.opacity(0.05))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.orange.opacity(0.3), lineWidth: 1)
        )
    }
}

// Reusing existing editor sheets
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

struct CustomConfigPathEditorSheet: View {
    let productName: String
    let currentPath: String
    @Binding var isPresented: Bool
    let onSave: (String) -> Void

    @State private var customPath: String = ""
    @State private var showError = false

    var body: some View {
        VStack(spacing: 20) {
            HStack {
                Text("Edit Config Path")
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
                Text("Custom Config File")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                TextField("Enter custom config file path or leave empty for default", text: $customPath)
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

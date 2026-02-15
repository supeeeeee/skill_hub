import SwiftUI
import SkillHubCore

struct SkillsView: View {
    @EnvironmentObject var viewModel: SkillHubViewModel
    @State private var setupSkill: InstalledSkillRecord?
    @State private var isImporting = false
    @State private var showAddOptions = false
    @State private var showURLInput = false
    @State private var showGitInput = false
    @State private var remoteURL = ""
    @State private var gitURL = ""
    @State private var selectedProductForNavigation: Product?
    
    let columns = [
        GridItem(.adaptive(minimum: 300, maximum: 500), spacing: 16)
    ]
    
    var body: some View {
        Group {
            if viewModel.isLoading && viewModel.skills.isEmpty {
                VStack {
                    Spacer()
                    ProgressView("Loading...")
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if viewModel.skills.isEmpty {
                EmptyStateView(
                    title: "No Skills Installed",
                    message: "You haven't installed any skills yet.",
                    iconName: "wrench.and.screwdriver",
                    action: { showAddOptions = true },
                    actionLabel: "Add Skill"
                )
            } else {
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 16) {
                        ForEach(viewModel.skills) { skill in
                            NavigationLink(destination: SkillDetailView(skill: skill)) {
                                SkillCardView(skill: skill) {
                                    setupSkill = skill
                                } onNavigateToProduct: { productID in
                                    if let product = viewModel.products.first(where: { $0.id == productID }) {
                                        selectedProductForNavigation = product
                                    }
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding()
                }
            }
        }
        .navigationTitle("Skills")
        .toolbar {
            ToolbarItem(placement: .automatic) {
                Button(action: {
                    viewModel.loadData()
                }) {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
                .disabled(viewModel.isLoading)
            }
            
            ToolbarItem(placement: .primaryAction) {
                Button(action: { showAddOptions = true }) {
                    Label("Add Skill", systemImage: "plus")
                }
            }
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .onAppear {
            viewModel.loadData()
        }
        .sheet(item: $setupSkill) { skill in
            ApplySkillView(skill: skill, isPresented: Binding(
                get: { setupSkill != nil },
                set: { if !$0 { setupSkill = nil } }
            ))
        }
        .sheet(item: $selectedProductForNavigation) { product in
            NavigationStack {
                ProductDetailView(product: product)
            }
        }
        .sheet(isPresented: $showAddOptions) {
            AddSkillOptionsView(
                onLocalFile: {
                    showAddOptions = false
                    isImporting = true
                },
                onFromURL: {
                    showAddOptions = false
                    showURLInput = true
                },
                onFromGit: {
                    showAddOptions = false
                    showGitInput = true
                }
            )
        }
        .sheet(isPresented: $showURLInput) {
            RemoteInputView(
                title: "Add from URL",
                placeholder: "https://example.com/skill.json",
                buttonLabel: "Add",
                input: $remoteURL,
                onSubmit: {
                    if let url = URL(string: remoteURL), remoteURL.hasPrefix("http") {
                        viewModel.addSkill(from: remoteURL)
                    }
                    showURLInput = false
                    remoteURL = ""
                },
                onCancel: {
                    showURLInput = false
                    remoteURL = ""
                }
            )
        }
        .sheet(isPresented: $showGitInput) {
            RemoteInputView(
                title: "Add from GitHub",
                placeholder: "git@github.com:user/skill.git",
                buttonLabel: "Clone & Add",
                input: $gitURL,
                onSubmit: {
                    if !gitURL.isEmpty {
                        viewModel.addSkill(from: gitURL)
                    }
                    showGitInput = false
                    gitURL = ""
                },
                onCancel: {
                    showGitInput = false
                    gitURL = ""
                }
            )
        }
        .fileImporter(isPresented: $isImporting, allowedContentTypes: [.json]) { result in
            switch result {
            case .success(let url):
                guard url.startAccessingSecurityScopedResource() else {
                    viewModel.log("Failed to access file: Permission denied", type: .error)
                    return
                }
                defer { url.stopAccessingSecurityScopedResource() }
                viewModel.importSkill(at: url)
            case .failure(let error):
                viewModel.log("Import failed: \(error.localizedDescription)", type: .error)
            }
        }
    }
}

struct AddSkillOptionsView: View {
    let onLocalFile: () -> Void
    let onFromURL: () -> Void
    let onFromGit: () -> Void
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Add Skill")
                .font(.title2)
                .fontWeight(.bold)
            
            VStack(spacing: 12) {
                Button(action: {
                    dismiss()
                    onLocalFile()
                }) {
                    HStack {
                        Image(systemName: "folder")
                            .frame(width: 30)
                        VStack(alignment: .leading) {
                            Text("Local File")
                            Text("Select a manifest.json from your device")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .background(Color(nsColor: .controlBackgroundColor))
                    .cornerRadius(8)
                }
                .buttonStyle(.plain)
                
                Button(action: {
                    dismiss()
                    onFromURL()
                }) {
                    HStack {
                        Image(systemName: "link")
                            .frame(width: 30)
                        VStack(alignment: .leading) {
                            Text("From URL")
                            Text("Download manifest from a direct URL")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .background(Color(nsColor: .controlBackgroundColor))
                    .cornerRadius(8)
                }
                .buttonStyle(.plain)
                
                Button(action: {
                    dismiss()
                    onFromGit()
                }) {
                    HStack {
                        Image(systemName: "chevron.left.forwardslash.chevron.right")
                            .frame(width: 30)
                        VStack(alignment: .leading) {
                            Text("From GitHub")
                            Text("Clone from a Git repository")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .background(Color(nsColor: .controlBackgroundColor))
                    .cornerRadius(8)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal)
            
            Button("Cancel") {
                dismiss()
            }
            .buttonStyle(.bordered)
        }
        .padding()
        .frame(width: 400)
    }
}

struct RemoteInputView: View {
    let title: String
    let placeholder: String
    let buttonLabel: String
    @Binding var input: String
    let onSubmit: () -> Void
    let onCancel: () -> Void
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(spacing: 20) {
            Text(title)
                .font(.title2)
                .fontWeight(.bold)
            
            TextField(placeholder, text: $input)
                .textFieldStyle(.roundedBorder)
            
            HStack {
                Button("Cancel") {
                    dismiss()
                    onCancel()
                }
                    .buttonStyle(.bordered)
                
                Spacer()
                
                Button(buttonLabel, action: onSubmit)
                    .buttonStyle(.borderedProminent)
                    .disabled(input.isEmpty)
            }
        }
        .padding()
        .frame(width: 400)
    }
}

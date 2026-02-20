import SwiftUI
import SkillHubCore
import UniformTypeIdentifiers

struct SkillsView: View {
    @EnvironmentObject var viewModel: SkillHubViewModel
    @State private var isImporting = false
    @State private var showRegisterOptions = false
    @State private var showURLInput = false
    @State private var showGitInput = false
    @State private var remoteURL = ""
    @State private var gitURL = ""
    
    let columns = [
        GridItem(.adaptive(minimum: 360, maximum: 600), spacing: 20)
    ]
    
    var body: some View {
        Group {
            if viewModel.isLoading && viewModel.skills.isEmpty {
                VStack(spacing: 16) {
                    ProgressView()
                        .scaleEffect(1.2)
                    Text("Loading Skills...")
                        .font(.headline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if viewModel.skills.isEmpty {
                EmptyStateView(
                    title: "No Skills Installed",
                    message: "Register skills to extend your development tools.",
                    iconName: "square.grid.2x2",
                    action: { showRegisterOptions = true },
                    actionLabel: "Register New Skill"
                )
            } else {
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 20) {
                        ForEach(viewModel.skills) { skill in
                            NavigationLink(destination: SkillDetailView(skill: skill)) {
                                SkillCardView(skill: skill)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(24)
                }
                .background(Color(nsColor: .windowBackgroundColor))
            }
        }
        .navigationTitle("Skills Library")
        .toolbar {
            ToolbarItem(placement: .automatic) {
                Button(action: {
                    viewModel.loadData()
                }) {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
                .disabled(viewModel.isLoading)
                .help("Refresh skills list")
            }
            
            ToolbarItem(placement: .primaryAction) {
                Button(action: { showRegisterOptions = true }) {
                    Label("Register Skill", systemImage: "plus")
                }
                .help("Add a new skill")
            }
        }
        .onAppear {
            viewModel.loadData()
        }
        .sheet(isPresented: $showRegisterOptions) {
            RegisterSkillOptionsView(
                onLocalFile: {
                    showRegisterOptions = false
                    isImporting = true
                },
                onFromURL: {
                    showRegisterOptions = false
                    showURLInput = true
                },
                onFromGit: {
                    showRegisterOptions = false
                    showGitInput = true
                }
            )
        }
        .sheet(isPresented: $showURLInput) {
            RemoteInputView(
                title: "Register from URL",
                placeholder: "https://example.com/SKILL.md",
                buttonLabel: "Register",
                icon: "link",
                input: $remoteURL,
                onSubmit: {
                    if URL(string: remoteURL) != nil, remoteURL.hasPrefix("http") {
                        viewModel.registerSkill(from: remoteURL)
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
                title: "Register from GitHub",
                placeholder: "git@github.com:user/skill.git",
                buttonLabel: "Clone & Register",
                icon: "chevron.left.forwardslash.chevron.right",
                input: $gitURL,
                onSubmit: {
                    if !gitURL.isEmpty {
                        viewModel.registerSkill(from: gitURL)
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
        .fileImporter(isPresented: $isImporting, allowedContentTypes: [.folder, .plainText]) { result in
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

struct RegisterSkillOptionsView: View {
    let onLocalFile: () -> Void
    let onFromURL: () -> Void
    let onFromGit: () -> Void
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                Text("Register Skill")
                    .font(.headline)
                
                HStack {
                    Spacer()
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title3)
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding()
            .background(.ultraThinMaterial)
            
            VStack(spacing: 16) {
                RegisterOptionButton(
                    title: "Local File",
                    subtitle: "Select a skill folder or SKILL.md file",
                    iconName: "doc.text",
                    color: .blue,
                    action: onLocalFile
                )
                
                RegisterOptionButton(
                    title: "From URL",
                    subtitle: "Download SKILL.md from a direct URL",
                    iconName: "link",
                    color: .purple,
                    action: onFromURL
                )
                
                RegisterOptionButton(
                    title: "From GitHub",
                    subtitle: "Clone from a Git repository",
                    iconName: "chevron.left.forwardslash.chevron.right",
                    color: .orange,
                    action: onFromGit
                )
            }
            .padding(24)
            .background(Color(nsColor: .windowBackgroundColor))
        }
        .frame(width: 440)
    }
}

struct RegisterOptionButton: View {
    let title: String
    let subtitle: String
    let iconName: String
    let color: Color
    let action: () -> Void
    
    @State private var isHovered = false
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(color.opacity(0.1))
                        .frame(width: 48, height: 48)
                    
                    Image(systemName: iconName)
                        .font(.title3)
                        .foregroundColor(color)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.headline)
                        .foregroundColor(.primary)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary.opacity(0.5))
            }
            .padding(12)
            .background(isHovered ? Color.secondary.opacity(0.05) : Color(nsColor: .controlBackgroundColor))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.primary.opacity(isHovered ? 0.1 : 0.05), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(isHovered ? 0.05 : 0), radius: 4, x: 0, y: 2)
            .scaleEffect(isHovered ? 1.005 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isHovered)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovered = hovering
        }
    }
}

struct RemoteInputView: View {
    let title: String
    let placeholder: String
    let buttonLabel: String
    let icon: String
    @Binding var input: String
    let onSubmit: () -> Void
    let onCancel: () -> Void
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                Text(title)
                    .font(.headline)
                
                HStack {
                    Spacer()
                    Button(action: { 
                        dismiss()
                        onCancel()
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title3)
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding()
            .background(.ultraThinMaterial)
            
            VStack(spacing: 24) {
                VStack(spacing: 8) {
                    CleanTextField(
                        icon: icon,
                        placeholder: placeholder,
                        text: $input
                    )
                    
                    Text("Enter the full URL to proceed.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.leading, 4)
                }
                .padding(.horizontal, 24)
                .padding(.top, 24)
                .padding(.bottom, 24)
            }
            .background(Color(nsColor: .windowBackgroundColor))
            
            VStack(spacing: 0) {
                Divider()
                HStack {
                    Button("Cancel") { 
                        dismiss()
                        onCancel()
                    }
                    .keyboardShortcut(.cancelAction)
                    .buttonStyle(.bordered)
                    
                    Spacer()
                    
                    Button(buttonLabel, action: onSubmit)
                        .buttonStyle(.borderedProminent)
                        .disabled(input.isEmpty)
                        .keyboardShortcut(.defaultAction)
                }
                .padding()
                .background(.regularMaterial)
            }
        }
        .frame(width: 440)
    }
}

import SwiftUI
import SkillHubCore

struct ApplySkillView: View {
    let skill: InstalledSkillRecord
    var preselectedProductID: String? = nil
    @EnvironmentObject var viewModel: SkillHubViewModel
    @Binding var isPresented: Bool
    
    @State private var selectedProduct: String = ""
    @State private var selectedMode: InstallMode = .auto
    @State private var isInstalling = false
    @State private var installationStatus: (message: String, type: MessageType)? // New state for detailed status
    @State private var isInstallationComplete = false // New state to control button/dismissal
    
    enum MessageType {
        case info, success, error, warning
        
        var color: Color {
            switch self {
            case .info: return .blue
            case .success: return .green
            case .error: return .red
            case .warning: return .orange
            }
        }
    }
    
    var availableProducts: [Product] {
        viewModel.products.filter { $0.status == .active }
    }
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Install \(skill.manifest.name)")
                .font(.title2)
                .fontWeight(.bold)
            
            // Display installation status message
            if let status = installationStatus {
                Text(status.message)
                    .foregroundColor(status.type.color)
                    .font(.callout)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            
            Form {
                if preselectedProductID == nil {
                    Picker("Product", selection: $selectedProduct) {
                        Text("Select Product").tag("")
                        ForEach(availableProducts) { product in
                            Text(product.name).tag(product.id)
                        }
                    }
                } else {
                    // Show read-only product info or just a text
                    if let product = availableProducts.first(where: { $0.id == preselectedProductID }) {
                         HStack {
                             Text("Product:")
                             Spacer()
                             Text(product.name)
                                 .foregroundColor(.secondary)
                         }
                    }
                }
                
                DisclosureGroup("Advanced Options") {
                    VStack(alignment: .leading) {
                        Picker("Install Mode", selection: $selectedMode) {
                            ForEach(InstallMode.allCases, id: \.self) { mode in
                                Text(self.friendlyModeName(mode)).tag(mode)
                            }
                        }
                        Text("Choose how the skill will be installed.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding()
            .disabled(isInstalling || isInstallationComplete) // Disable form during/after install
            
            HStack {
                Button("Cancel") {
                    isPresented = false
                }
                .keyboardShortcut(.cancelAction)
                .disabled(isInstalling) // Cannot cancel during installation
                
                Spacer()
                
                if !isInstallationComplete {
                    Button("Smart Install") {
                        install()
                    }
                    .disabled(selectedProduct.isEmpty || isInstalling)
                    .keyboardShortcut(.defaultAction)
                } else {
                    Button("Done") {
                        isPresented = false
                    }
                    .keyboardShortcut(.defaultAction)
                }
            }
            
            if isInstalling {
                ProgressView("Installing...")
            }
        }
        .padding()
        .frame(width: 400)
        .onAppear {
            if let preselected = preselectedProductID {
                selectedProduct = preselected
            }
        }
    }
    
    func friendlyModeName(_ mode: InstallMode) -> String {
        switch mode {
        case .symlink: return "Synced (Recommended)"
        case .copy: return "Standalone Copy"
        case .configPatch: return "Native Integration"
        case .auto: return "Auto (Smart Select)"
        }
    }

    func install() {
        guard !selectedProduct.isEmpty else {
            installationStatus = ("Please select a product.", .warning)
            return
        }
        
        isInstalling = true
        installationStatus = ("Initiating installation...", .info)
        
        Task {
            // Assume viewModel.installSkill now returns a more detailed result
            // e.g., (success: Bool, message: String, isStubbed: Bool)
            let (success, message, isStubbed) = await viewModel.installSkill(
                manifest: skill.manifest,
                productID: selectedProduct,
                mode: selectedMode
            ) // This line would need to be updated in SkillHubViewModel
            
            if success {
                let summary: String
                switch selectedMode {
                case .symlink:
                    summary = "Installed in Synced mode. Changes will sync across all apps."
                case .copy:
                    summary = "Installed as Standalone Copy. Updates won't sync automatically."
                case .configPatch:
                    summary = "Installed via Native Integration."
                case .auto:
                    summary = "Smart Install complete."
                }
                
                installationStatus = (isStubbed ? "Installation simulated (MVP). \(message)" : "\(summary) \(message)", .success)
            } else {
                installationStatus = ("Installation failed: \(message)", .error)
            }
            
            isInstalling = false
            isInstallationComplete = true // Mark as complete to change button
            
            // Optionally, if the stubbed message is too long or requires user to check CLI,
            // we might want a way to display it better or provide a "View Log" button.
        }
    }
}

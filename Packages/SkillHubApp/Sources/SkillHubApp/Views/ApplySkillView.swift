import SwiftUI
import SkillHubCore

struct ApplySkillView: View {
    let skill: InstalledSkillRecord
    var preselectedProductID: String? = nil
    @EnvironmentObject var viewModel: SkillHubViewModel
    @Binding var isPresented: Bool
    
    @State private var selectedProduct: String = ""
    @State private var isInstalling = false
    @State private var installationStatus: (message: String, type: MessageType)?
    @State private var isInstallationComplete = false
    
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
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Install \(skill.manifest.name)")
                    .font(.title2.weight(.semibold))
                Text("Skill files will be installed as a local copy.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            VStack(alignment: .leading, spacing: 12) {
                if preselectedProductID == nil {
                    Picker("Product", selection: $selectedProduct) {
                        Text("Select Product").tag("")
                        ForEach(availableProducts) { product in
                            Text(product.name).tag(product.id)
                        }
                    }
                    .pickerStyle(.menu)
                } else if let product = availableProducts.first(where: { $0.id == preselectedProductID }) {
                    HStack {
                        Text("Product")
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(product.name)
                    }
                }

            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.primary.opacity(0.05))
            )
            .disabled(isInstalling || isInstallationComplete)

            if let status = installationStatus {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: iconName(for: status.type))
                        .foregroundColor(status.type.color)
                    Text(status.message)
                        .foregroundColor(status.type.color)
                        .font(.callout)
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(status.type.color.opacity(0.12))
                )
            }

            HStack {
                Button("Cancel") {
                    isPresented = false
                }
                .keyboardShortcut(.cancelAction)
                .disabled(isInstalling)
                
                Spacer()
                
                if !isInstallationComplete {
                    Button("Install (Copy)") {
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
        .padding(20)
        .frame(width: 440)
        .onAppear {
            if let preselected = preselectedProductID {
                selectedProduct = preselected
            }
        }
    }

    private func iconName(for type: MessageType) -> String {
        switch type {
        case .info:
            return "info.circle.fill"
        case .success:
            return "checkmark.circle.fill"
        case .error:
            return "xmark.octagon.fill"
        case .warning:
            return "exclamationmark.triangle.fill"
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
            let (success, message) = await viewModel.installSkill(
                manifest: skill.manifest,
                productID: selectedProduct,
                mode: .copy
            )
            
            if success {
                let summary: String
                summary = "Installed as Standalone Copy. Updates won't sync automatically."
                
                installationStatus = ("\(summary) \(message)", .success)
            } else {
                installationStatus = ("Installation failed: \(message)", .error)
            }
            
            isInstalling = false
            isInstallationComplete = true
        }
    }
}

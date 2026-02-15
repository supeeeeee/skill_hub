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
    @State private var installError: String?
    
    var availableProducts: [Product] {
        viewModel.products.filter { $0.status == .active }
    }
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Install \(skill.manifest.name)")
                .font(.title2)
                .fontWeight(.bold)
            
            if let error = installError {
                Text(error)
                    .foregroundColor(.red)
                    .font(.caption)
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
                
                Picker("Mode", selection: $selectedMode) {
                    ForEach(InstallMode.allCases, id: \.self) { mode in
                        Text(mode.rawValue.capitalized).tag(mode)
                    }
                }
            }
            .padding()
            
            HStack {
                Button("Cancel") {
                    isPresented = false
                }
                .keyboardShortcut(.cancelAction)
                
                Button("Install") {
                    install()
                }
                .disabled(selectedProduct.isEmpty || isInstalling)
                .keyboardShortcut(.defaultAction)
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
    
    func install() {
        guard !selectedProduct.isEmpty else { return }
        
        isInstalling = true
        installError = nil
        
        Task {
            await viewModel.installSkill(manifest: skill.manifest, productID: selectedProduct, mode: selectedMode)
            
            // Basic error handling based on logs could be better, but simplified for now
            // In a real app we might want viewModel.installSkill to throw or return result
            
            isInstalling = false
            isPresented = false
        }
    }
}

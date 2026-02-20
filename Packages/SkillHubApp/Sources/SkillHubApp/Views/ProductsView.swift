import SwiftUI
import SkillHubCore
import UniformTypeIdentifiers

struct ProductsView: View {
    @EnvironmentObject var viewModel: SkillHubViewModel
    @State private var showingAddProductSheet = false
    @State private var productPendingRemoval: Product?
    
    let columns = [
        GridItem(.adaptive(minimum: 360, maximum: 600), spacing: 20)
    ]
    
    var body: some View {
        ZStack {
            if viewModel.isLoading {
                VStack {
                    Spacer()
                    ProgressView("Loading Products...")
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if viewModel.products.isEmpty {
                EmptyStateView(
                    title: "No Products Found",
                    message: "It looks like no products are currently available.",
                    iconName: "macbook.and.iphone"
                )
            } else {
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 20) {
                        ForEach(viewModel.products) { product in
                            NavigationLink(destination: ProductDetailView(product: product)) {
                                ProductCardView(
                                    product: product,
                                    installedSkillsCount: installedSkillsCount(for: product.id),
                                    enabledSkillsCount: enabledSkillsCount(for: product.id)
                                )
                            }
                            .buttonStyle(.plain)
                            .contextMenu {
                                if product.isCustom {
                                    Button(role: .destructive) {
                                        productPendingRemoval = product
                                    } label: {
                                        Label("Remove Product", systemImage: "trash")
                                    }
                                }
                            }
                        }
                    }
                    .padding(24)
                }
            }
        }
        .navigationTitle("Products")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showingAddProductSheet = true
                } label: {
                    Label("Add Product", systemImage: "plus")
                }
            }
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .onAppear {
            viewModel.loadData()
        }
        .sheet(isPresented: $showingAddProductSheet) {
            AddCustomProductSheet { name, id, skillsPath, executableNames, iconName in
                viewModel.addCustomProduct(
                    name: name,
                    id: id,
                    skillsDirectoryPath: skillsPath,
                    executableNamesRaw: executableNames,
                    iconName: iconName
                )
            }
        }
        .alert("Remove Custom Product", isPresented: Binding(
            get: { productPendingRemoval != nil },
            set: { if !$0 { productPendingRemoval = nil } }
        )) {
            Button("Cancel", role: .cancel) {
                productPendingRemoval = nil
            }
            Button("Remove", role: .destructive) {
                if let product = productPendingRemoval {
                    viewModel.removeCustomProduct(productID: product.id)
                }
                productPendingRemoval = nil
            }
        } message: {
            if let product = productPendingRemoval {
                Text("This removes custom product '\(product.name)' from SkillHub and clears its local binding state.")
            }
        }
    }
    
    private func installedSkillsCount(for productID: String) -> Int {
        viewModel.skills.filter { $0.installedProducts.contains(productID) }.count
    }
    
    private func enabledSkillsCount(for productID: String) -> Int {
        viewModel.skills.filter { $0.enabledProducts.contains(productID) }.count
    }
}

private struct AddCustomProductSheet: View {
    private enum InputField: Hashable {
        case name
        case id
    }

    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var id = ""
    @State private var skillsPath = ""
    @State private var executableNames = ""
    @State private var iconName = ""
    @State private var showAdvanced = false
    @State private var idWasManuallyEdited = false
    @State private var showFileImporter = false
    @FocusState private var focusedField: InputField?

    let onSave: (_ name: String, _ id: String, _ skillsPath: String, _ executableNames: String, _ iconName: String?) -> Void

    private var normalizedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var normalizedID: String {
        id.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private var effectiveID: String {
        normalizedID.isEmpty ? suggestedID(from: normalizedName) : normalizedID
    }

    private var normalizedPath: String {
        (skillsPath as NSString).expandingTildeInPath.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var normalizedIcon: String {
        iconName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var canSave: Bool {
        !normalizedName.isEmpty && !effectiveID.isEmpty && !normalizedPath.isEmpty
    }

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                Text("Add Product")
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
            
            ScrollView {
                VStack(spacing: 32) {
                    VStack(spacing: 16) {
                        Text("PREVIEW")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(.regularMaterial)
                            .clipShape(Capsule())
                        
                        HStack(spacing: 16) {
                           ZStack {
                               RoundedRectangle(cornerRadius: 12)
                                   .fill(Color.secondary.opacity(0.1))
                                   .frame(width: 48, height: 48)
                               Image(systemName: normalizedIcon.isEmpty ? "cube.box.fill" : normalizedIcon)
                                   .font(.system(size: 24))
                                   .foregroundStyle(.secondary)
                           }
                           
                           VStack(alignment: .leading, spacing: 4) {
                               Text(normalizedName.isEmpty ? "Product Name" : normalizedName)
                                   .font(.headline)
                                   .foregroundStyle(.primary)
                               Text(normalizedPath.isEmpty ? "Path not set" : normalizedPath)
                                   .font(.caption)
                                   .foregroundStyle(.secondary)
                                   .lineLimit(1)
                                   .truncationMode(.middle)
                           }
                           
                           Spacer()
                           
                           Text("CUSTOM")
                               .font(.system(size: 10, weight: .bold))
                               .padding(.horizontal, 6)
                               .padding(.vertical, 2)
                               .background(Color.accentColor.opacity(0.1))
                               .foregroundStyle(Color.accentColor)
                               .clipShape(Capsule())
                        }
                        .padding(16)
                        .background(Color(nsColor: .controlBackgroundColor))
                        .cornerRadius(12)
                        .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 4)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.primary.opacity(0.05), lineWidth: 1)
                        )
                        .padding(.horizontal)
                    }
                    
                    VStack(spacing: 24) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Identity")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundStyle(.secondary)
                                .padding(.leading, 4)
                            
                            VStack(spacing: 12) {
                                HStack(alignment: .center, spacing: 8) {
                                    Image(systemName: "tag")
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundStyle(.secondary)
                                        .frame(width: 24, alignment: .center)

                                    TextField("Product Name", text: $name)
                                        .textFieldStyle(.plain)
                                        .font(.system(size: 13, weight: .regular))
                                        .focused($focusedField, equals: .name)
                                        .frame(maxWidth: .infinity, minHeight: 20, alignment: .leading)
                                }
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    focusedField = .name
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 10)
                                .background(Color(nsColor: .controlBackgroundColor))
                                .cornerRadius(8)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(focusedField == .name ? Color.accentColor.opacity(0.45) : Color.primary.opacity(0.1), lineWidth: 1)
                                )

                                HStack(alignment: .center, spacing: 8) {
                                    Image(systemName: "fingerprint")
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundStyle(.secondary)
                                        .frame(width: 24, alignment: .center)

                                    TextField("product-id", text: $id)
                                        .textFieldStyle(.plain)
                                        .font(.system(size: 13, weight: .regular, design: .monospaced))
                                        .focused($focusedField, equals: .id)
                                        .frame(maxWidth: .infinity, minHeight: 20, alignment: .leading)

                                    if !idWasManuallyEdited && !name.isEmpty {
                                        Image(systemName: "wand.and.stars")
                                            .font(.system(size: 14))
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    focusedField = .id
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 10)
                                .background(Color(nsColor: .controlBackgroundColor))
                                .cornerRadius(8)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(focusedField == .id ? Color.accentColor.opacity(0.45) : Color.primary.opacity(0.1), lineWidth: 1)
                                )
                            }
                        }
                        
                        VStack(alignment: .leading, spacing: 8) {
                             Text("Configuration")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundStyle(.secondary)
                                .padding(.leading, 4)
                                
                            PathPickerField(
                                placeholder: "Skills Folder Location",
                                text: $skillsPath,
                                actionLabel: "Browse"
                            ) {
                                showFileImporter = true
                            }
                            
                            HStack(spacing: 12) {
                                CleanTextField(
                                    icon: "terminal",
                                    placeholder: "Executables (cmd, cli)",
                                    text: $executableNames
                                )
                                
                                CleanTextField(
                                    icon: "star",
                                    placeholder: "SF Symbol",
                                    text: $iconName
                                )
                                .frame(width: 140)
                            }
                        }
                    }
                    .padding(.horizontal)
                }
                .padding(.bottom, 30)
            }
            .background(Color(nsColor: .windowBackgroundColor))
            
            VStack(spacing: 0) {
                Divider()
                HStack {
                    Button("Cancel") { dismiss() }
                        .keyboardShortcut(.cancelAction)
                        .buttonStyle(.bordered)
                        
                    Spacer()
                    
                    Button("Add Product") {
                        onSave(normalizedName, effectiveID, normalizedPath, executableNames, normalizedIcon.isEmpty ? nil : normalizedIcon)
                        dismiss()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(!canSave)
                    .keyboardShortcut(.defaultAction)
                }
                .padding()
                .background(.regularMaterial)
            }
        }
        .frame(width: 500, height: 600)
        .onAppear {
            DispatchQueue.main.async {
                focusedField = .name
            }
        }
        .onChange(of: name) { newValue in
            if !idWasManuallyEdited {
                id = suggestedID(from: newValue)
            }
            if skillsPath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                let suggested = suggestedID(from: newValue)
                if !suggested.isEmpty {
                    skillsPath = "~/.\(suggested)/skills"
                }
            }
        }
        .onChange(of: id) { newValue in
            let cleaned = newValue.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            if cleaned.isEmpty {
                idWasManuallyEdited = false
            } else {
                idWasManuallyEdited = cleaned != suggestedID(from: normalizedName)
            }
        }
        .fileImporter(isPresented: $showFileImporter, allowedContentTypes: [.folder], allowsMultipleSelection: false) { result in
            switch result {
            case .success(let urls):
                if let url = urls.first {
                    skillsPath = url.path(percentEncoded: false)
                }
            case .failure(let error):
                print("Error selecting folder: \(error.localizedDescription)")
            }
        }
    }

    private func suggestedID(from name: String) -> String {
        let allowed = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyz0123456789")
        let lowered = name.lowercased()
        var result = ""
        var previousWasDash = false

        for scalar in lowered.unicodeScalars {
            if allowed.contains(scalar) {
                result.unicodeScalars.append(scalar)
                previousWasDash = false
            } else if !previousWasDash {
                result.append("-")
                previousWasDash = true
            }
        }

        return result.trimmingCharacters(in: CharacterSet(charactersIn: "-"))
    }
}

private struct PathPickerField: View {
    let placeholder: String
    @Binding var text: String
    let actionLabel: String
    let onAction: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 8) {
            Image(systemName: "folder")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.secondary)
                .frame(width: 24, alignment: .center)

            TextField(placeholder, text: $text)
                .textFieldStyle(.plain)
                .font(.system(size: 13, weight: .regular))
                .frame(maxWidth: .infinity, minHeight: 20, alignment: .leading)

            Divider()
                .frame(width: 1, height: 18)

            Button(actionLabel, action: onAction)
                .buttonStyle(.plain)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Color.accentColor)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.primary.opacity(0.1), lineWidth: 1)
        )
    }
}

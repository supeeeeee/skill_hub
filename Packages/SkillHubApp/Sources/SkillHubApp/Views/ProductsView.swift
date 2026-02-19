import SwiftUI
import SkillHubCore

struct ProductsView: View {
    @EnvironmentObject var viewModel: SkillHubViewModel
    @State private var showingAddProductSheet = false
    @State private var productPendingRemoval: Product?
    
    var body: some View {
        ZStack {
            if viewModel.isLoading {
                VStack {
                    Spacer()
                    ProgressView("Loading...")
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
                    VStack(spacing: 12) {
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
                    .padding()
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
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var id = ""
    @State private var skillsPath = ""
    @State private var executableNames = ""
    @State private var iconName = ""
    @State private var showAdvanced = false
    @State private var idWasManuallyEdited = false

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

    private var idError: String? {
        if effectiveID.isEmpty {
            return "ID is required"
        }
        let allowed = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyz0123456789-_")
        if effectiveID.rangeOfCharacter(from: allowed.inverted) != nil {
            return "Use lowercase letters, digits, '-' or '_'"
        }
        return nil
    }

    private var pathError: String? {
        if normalizedPath.isEmpty {
            return "Skills directory is required"
        }
        if !normalizedPath.hasPrefix("/") {
            return "Please use an absolute path"
        }
        return nil
    }

    private var canSave: Bool {
        !normalizedName.isEmpty && idError == nil && pathError == nil
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Add a custom product")
                            .font(.title2.weight(.semibold))
                        Text("Only 3 things are required: name, ID, and skills folder.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 10) {
                            Image(systemName: normalizedIcon.isEmpty ? "shippingbox.fill" : normalizedIcon)
                                .font(.system(size: 18, weight: .semibold))
                                .frame(width: 34, height: 34)
                                .background(Color.accentColor.opacity(0.12))
                                .foregroundColor(.accentColor)
                                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

                            VStack(alignment: .leading, spacing: 2) {
                                Text(normalizedName.isEmpty ? "Product Name" : normalizedName)
                                    .font(.headline)
                                Text(effectiveID.isEmpty ? "product-id" : effectiveID)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }

                            Spacer()

                            Text("CUSTOM")
                                .font(.caption2.bold())
                                .padding(.horizontal, 6)
                                .padding(.vertical, 3)
                                .background(Color.accentColor.opacity(0.12))
                                .foregroundColor(.accentColor)
                                .cornerRadius(4)
                        }

                        Text(normalizedPath.isEmpty ? "Skills directory not set" : normalizedPath)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                    .padding(14)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color(nsColor: .controlBackgroundColor))
                    )
                    .shadow(color: Color.black.opacity(0.04), radius: 2, x: 0, y: 1)

                    Group {
                        labeledField(title: "Product Name", placeholder: "My Editor", text: $name)

                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text("Product ID")
                                    .font(.subheadline.weight(.medium))
                                Spacer()
                                if !normalizedName.isEmpty {
                                    Button("Use Suggested") {
                                        id = suggestedID(from: normalizedName)
                                        idWasManuallyEdited = false
                                    }
                                    .buttonStyle(.plain)
                                    .font(.caption)
                                    .foregroundColor(.accentColor)
                                }
                            }
                            TextField("my-editor", text: $id)
                                .textFieldStyle(.roundedBorder)
                                .autocorrectionDisabled()
                            validationText(idError ?? "Used in bindings and config keys", isError: idError != nil)
                        }

                        VStack(alignment: .leading, spacing: 6) {
                            Text("Skills Directory")
                                .font(.subheadline.weight(.medium))
                            TextField("/absolute/path/to/skills", text: $skillsPath)
                                .textFieldStyle(.roundedBorder)
                            validationText(pathError ?? "SkillHub copies enabled skills into this folder", isError: pathError != nil)
                        }

                        DisclosureGroup("Advanced options (optional)", isExpanded: $showAdvanced) {
                            VStack(alignment: .leading, spacing: 12) {
                                labeledField(title: "Executable Names", placeholder: "editor, my-editor-cli", text: $executableNames, helper: "Comma-separated names used for installation detection")
                                labeledField(title: "SF Symbol Icon", placeholder: "terminal", text: $iconName, helper: "Any valid SF Symbol name")
                            }
                            .padding(.top, 8)
                        }
                    }
                }
                .padding(18)
            }
            .navigationTitle("Add Custom Product")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        onSave(normalizedName, effectiveID, normalizedPath, executableNames, normalizedIcon.isEmpty ? nil : normalizedIcon)
                        dismiss()
                    }
                    .disabled(!canSave)
                }
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
        .frame(minWidth: 560, minHeight: 500)
    }

    private func labeledField(title: String, placeholder: String, text: Binding<String>, helper: String? = nil) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.subheadline.weight(.medium))
            TextField(placeholder, text: text)
                .textFieldStyle(.roundedBorder)
            if let helper {
                Text(helper)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }

    private func validationText(_ text: String, isError: Bool) -> some View {
        Text(text)
            .font(.caption)
            .foregroundColor(isError ? .red : .secondary)
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

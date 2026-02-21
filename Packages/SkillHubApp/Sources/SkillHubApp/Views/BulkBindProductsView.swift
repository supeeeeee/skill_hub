import SwiftUI
import SkillHubCore

struct BatchManagementView: View {
    let skill: InstalledSkillRecord
    @ObservedObject var detailViewModel: SkillDetailViewModel
    @EnvironmentObject var hubViewModel: SkillHubViewModel
    @Environment(\.dismiss) var dismiss
    
    @State private var selectedProductIDs = Set<String>()
    @State private var isProcessing = false
    @State private var searchText = ""
    
    // Derived properties for filtering
    private var filteredProducts: [Product] {
        if searchText.isEmpty {
            return hubViewModel.products
        } else {
            return hubViewModel.products.filter { product in
                product.name.localizedCaseInsensitiveContains(searchText) ||
                product.id.localizedCaseInsensitiveContains(searchText)
            }
        }
    }

    private func isSelectable(_ product: Product) -> Bool {
        product.status == .active
    }

    private var selectableFilteredProductIDs: [String] {
        filteredProducts.filter(isSelectable).map(\.id)
    }
    
    private var allFilteredSelected: Bool {
        !selectableFilteredProductIDs.isEmpty && selectedProductIDs.isSuperset(of: selectableFilteredProductIDs)
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if hubViewModel.products.isEmpty {
                    emptyStateView
                } else {
                    // Selection Header
                    selectionHeader
                    
                    Divider()
                    
                    // Main List
                    if filteredProducts.isEmpty {
                        noSearchResultsView
                    } else {
                        productsList
                    }
                }
                
                // Action Bar Footer
                if !hubViewModel.products.isEmpty {
                    actionBar
                }
            }
            .navigationTitle("Enable on Products")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .searchable(text: $searchText, placement: .toolbar, prompt: "Search by name or ID")
            .disabled(isProcessing)
            .overlay {
                if isProcessing {
                    processingOverlay
                }
            }
        }
        .frame(minWidth: 500, minHeight: 400)
    }
    
    // MARK: - Views
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "cube.box")
                .font(.system(size: 48))
                .foregroundColor(.secondary.opacity(0.5))
            
            VStack(spacing: 8) {
                Text("No Products Available")
                    .font(.title2)
                    .fontWeight(.medium)
                Text("There are no products available to manage.")
                    .font(.body)
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .textBackgroundColor))
    }
    
    private var noSearchResultsView: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "magnifyingglass")
                .font(.largeTitle)
                .foregroundColor(.secondary)
            Text("No matching products found")
                .font(.body)
                .foregroundColor(.secondary)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .textBackgroundColor))
    }
    
    private var selectionHeader: some View {
        HStack(spacing: 12) {
            // Select All Toggle
            Button(action: toggleSelectAll) {
                Image(systemName: allFilteredSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(allFilteredSelected ? .accentColor : .secondary)
                    .font(.title3)
            }
            .buttonStyle(.plain)
            .help("Select all filtered products")
            
            Text("Product")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.secondary)
            
            Spacer()
            
            Text("Status")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.secondary)
                .frame(width: 100, alignment: .trailing)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(nsColor: .controlBackgroundColor))
    }
    
    private var productsList: some View {
        List {
            ForEach(filteredProducts) { product in
                BatchProductRow(
                    product: product,
                    isSelected: selectedProductIDs.contains(product.id),
                    isBound: skill.isBound(to: product.id),
                    isEnabled: skill.enabledProducts.contains(product.id),
                    isSelectable: isSelectable(product)
                )
                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                .contentShape(Rectangle())
                .onTapGesture {
                    guard isSelectable(product) else { return }
                    toggleSelection(for: product)
                }
            }
        }
        .listStyle(.plain)
    }
    
    private var actionBar: some View {
        VStack(spacing: 0) {
            Divider()
            
            HStack {
                // Selection count
                if !selectedProductIDs.isEmpty {
                    Text("\(selectedProductIDs.count)")
                        .fontWeight(.bold) +
                    Text(" selected")
                } else {
                    Text("Select products to manage")
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                HStack(spacing: 12) {
                    Button(role: .destructive) {
                        performBatchAction(isInstall: false)
                    } label: {
                        Text("Disable Selected")
                            .frame(minWidth: 100)
                    }
                    .controlSize(.large)
                    .disabled(selectedProductIDs.isEmpty)
                    
                    Button {
                        performBatchAction(isInstall: true)
                    } label: {
                        Text("Enable Selected")
                            .frame(minWidth: 100)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .disabled(selectedProductIDs.isEmpty)
                }
            }
            .padding(16)
            .background(Color(nsColor: .windowBackgroundColor))
        }
    }
    
    private var processingOverlay: some View {
        ZStack {
            Color.black.opacity(0.1)
                .ignoresSafeArea()
            
            VStack(spacing: 16) {
                ProgressView()
                    .controlSize(.large)
                Text("Processing changes...")
                    .font(.headline)
            }
            .padding(24)
            .background(.ultraThinMaterial)
            .cornerRadius(12)
            .shadow(radius: 20)
        }
    }
    
    // MARK: - Actions
    
    private func toggleSelection(for product: Product) {
        guard isSelectable(product) else { return }
        if selectedProductIDs.contains(product.id) {
            selectedProductIDs.remove(product.id)
        } else {
            selectedProductIDs.insert(product.id)
        }
    }
    
    private func toggleSelectAll() {
        if allFilteredSelected {
            selectedProductIDs.subtract(selectableFilteredProductIDs)
        } else {
            selectedProductIDs.formUnion(selectableFilteredProductIDs)
        }
    }
    
    private func performBatchAction(isInstall: Bool) {
        isProcessing = true
        let productsToProcess = Array(selectedProductIDs)
        
        Task {
            if isInstall {
                await detailViewModel.bulkBindProducts(to: productsToProcess)
            } else {
                await detailViewModel.bulkUninstallProducts(productIDs: productsToProcess)
            }
            
            // UI Feedback and cleanup
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5s delay for visual feedback
            await MainActor.run {
                isProcessing = false
                selectedProductIDs.removeAll()
            }
        }
    }
}

struct BatchProductRow: View {
    let product: Product
    let isSelected: Bool
    let isBound: Bool
    let isEnabled: Bool
    let isSelectable: Bool
    
    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            // Checkbox
            Image(systemName: isSelectable ? (isSelected ? "checkmark.square.fill" : "square") : "minus.square")
                .font(.title2)
                .foregroundColor(isSelectable ? (isSelected ? .accentColor : .secondary.opacity(0.4)) : .secondary.opacity(0.35))
                .frame(width: 24)
            
            // Product Info
            VStack(alignment: .leading, spacing: 2) {
                Text(product.name)
                    .font(.body)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                
                Text(product.id)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .monospaced()
            }
            
            Spacer()
            
            // Status Badge
            statusBadge
        }
        .padding(.vertical, 4)
        .opacity(isSelectable ? 1.0 : 0.55)
    }
    
    @ViewBuilder
    var statusBadge: some View {
        if !isSelectable {
            Text("Not Detected")
                .font(.caption)
                .fontWeight(.medium)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    Capsule()
                        .fill(Color.secondary.opacity(0.1))
                )
                .foregroundColor(.secondary)
        } else if isBound {
            HStack(spacing: 6) {
                Circle()
                    .fill(isEnabled ? Color.green : Color.orange)
                    .frame(width: 6, height: 6)
                Text(isEnabled ? "Enabled" : "Disabled")
                    .fontWeight(.medium)
            }
            .font(.caption)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                Capsule()
                    .fill(isEnabled ? Color.green.opacity(0.1) : Color.orange.opacity(0.1))
            )
            .overlay(
                Capsule()
                    .stroke(isEnabled ? Color.green.opacity(0.2) : Color.orange.opacity(0.2), lineWidth: 1)
            )
            .foregroundColor(isEnabled ? .green : .orange)
        } else {
            Text("Not Enabled")
                .font(.caption)
                .fontWeight(.medium)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    Capsule()
                        .fill(Color.secondary.opacity(0.1))
                )
                .foregroundColor(.secondary)
        }
    }
}

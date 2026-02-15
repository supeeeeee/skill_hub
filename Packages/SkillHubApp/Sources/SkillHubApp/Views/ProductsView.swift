import SwiftUI
import SkillHubCore

struct ProductsView: View {
    @EnvironmentObject var viewModel: SkillHubViewModel
    
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
                        }
                    }
                    .padding()
                }
            }
        }
        .navigationTitle("Products")
        .background(Color(nsColor: .windowBackgroundColor))
        .onAppear {
            viewModel.loadData()
        }
    }
    
    private func installedSkillsCount(for productID: String) -> Int {
        viewModel.skills.filter { $0.installedProducts.contains(productID) }.count
    }
    
    private func enabledSkillsCount(for productID: String) -> Int {
        viewModel.skills.filter { $0.enabledProducts.contains(productID) }.count
    }
}

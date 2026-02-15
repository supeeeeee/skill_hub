import SwiftUI
import SkillHubCore

struct ProductsView: View {
    @EnvironmentObject var viewModel: SkillHubViewModel
    
    var body: some View {
        Group {
            if viewModel.products.isEmpty {
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
                                ProductCardView(product: product)
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
}

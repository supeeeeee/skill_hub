import SwiftUI
import SkillHubCore

struct DiscoverView: View {
    @EnvironmentObject private var viewModel: SkillHubViewModel

    var body: some View {
        Group {
            if viewModel.discoverySkills.isEmpty {
                EmptyStateView(
                    title: "No Discover Items",
                    message: "No recommendations are available right now.",
                    iconName: "safari"
                )
            } else {
                List(viewModel.discoverySkills) { item in
                    HStack(alignment: .top, spacing: 12) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(item.name)
                                .font(.headline)
                            Text(item.summary)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            Text(item.sourceURL)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                                .truncationMode(.middle)
                        }

                        Spacer()

                        Button("Add") {
                            viewModel.registerSkill(from: item.sourceURL)
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .padding(.vertical, 4)
                }
                .listStyle(.inset)
            }
        }
        .navigationTitle("Discover")
        .toolbar {
            ToolbarItem(placement: .automatic) {
                Button {
                    viewModel.loadDiscoveryCatalog()
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
            }
        }
    }
}

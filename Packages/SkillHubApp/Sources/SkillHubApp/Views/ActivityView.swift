import SwiftUI

struct ActivityView: View {
    @EnvironmentObject private var viewModel: SkillHubViewModel

    var body: some View {
        Group {
            if viewModel.logs.isEmpty {
                EmptyStateView(
                    title: "No Activity Yet",
                    message: "Operations and events will show up here.",
                    iconName: "clock.arrow.circlepath"
                )
            } else {
                ScrollView {
                    LazyVStack(spacing: 10) {
                        ForEach(viewModel.logs) { log in
                            InlineLogView(log: log)
                                .padding(.horizontal)
                        }
                    }
                    .padding(.vertical)
                }
            }
        }
        .navigationTitle("Activity")
        .background(Color(nsColor: .windowBackgroundColor))
    }
}

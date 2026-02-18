import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var preferences: UserPreferences
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Settings")
                .font(.title2)
                .fontWeight(.semibold)

            Toggle("Pro Mode", isOn: $preferences.isAdvancedMode)

            Text(preferences.isAdvancedMode ? "Pro mode shows advanced deployment options." : "Simple mode hides advanced deployment options.")
                .font(.caption)
                .foregroundStyle(.secondary)

            Spacer()

            HStack {
                Spacer()
                Button("Done") {
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(width: 360, height: 180)
    }
}

import SwiftUI
import SkillHubCore

struct BindingRowView: View {
    let productID: String
    let installMode: InstallMode
    let status: ProductSkillStatus
    
    var body: some View {
        HStack {
            Image(systemName: "app.connected.to.app.below.fill")
                .foregroundColor(.secondary)
            Text(productID)
                .font(.headline)
            Spacer()
            if status.isInstalled {
                VStack(alignment: .trailing) {
                    Text("INSTALLED (\(installMode.rawValue))")
                        .font(.caption)
                        .foregroundColor(.green)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.green.opacity(0.1))
                        .cornerRadius(8)
                    if status.isEnabled {
                        Text("ENABLED")
                            .font(.caption2)
                            .foregroundColor(.blue)
                    }
                    Text(status.detail)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            } else {
                VStack(alignment: .trailing) {
                    Text("NOT INSTALLED")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(status.detail)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
        )
    }
}

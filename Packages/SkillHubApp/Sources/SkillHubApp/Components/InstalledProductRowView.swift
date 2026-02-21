import SwiftUI
import SkillHubCore

struct InstalledProductRowView: View {
    let product: Product
    let status: ProductSkillStatus
    var onInstall: (() -> Void)? = nil
    var onToggle: (() -> Void)? = nil
    
    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(Color.secondary.opacity(0.1))
                    .frame(width: 40, height: 40)
                
                Image(systemName: product.iconName)
                    .font(.system(size: 20))
                    .foregroundColor(.accentColor)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(product.name)
                    .font(.headline)
                    .foregroundColor(.primary)
                
                if !product.description.isEmpty {
                    Text(product.description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }
            
            Spacer()
            
            HStack(spacing: 8) {
                if status.isInstalled {
                    StatusBadge(
                        text: status.isEnabled ? "Enabled" : "Disabled",
                        color: status.isEnabled ? .green : .orange,
                        icon: status.isEnabled ? "checkmark.circle.fill" : "pause.circle.fill"
                    )
                    .onTapGesture {
                        onToggle?()
                    }
                    
                    Button(action: { onToggle?() }) {
                        Image(systemName: status.isEnabled ? "power" : "power")
                            .foregroundColor(status.isEnabled ? .red : .green)
                    }
                    .buttonStyle(.plain)
                } else {
                    Button(action: { onInstall?() }) {
                        Text("Enable")
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.accentColor)
                            .foregroundColor(.white)
                            .cornerRadius(6)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(12)
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.secondary.opacity(0.1), lineWidth: 1)
        )
    }
    
}

struct StatusBadge: View {
    let text: String
    let color: Color
    var icon: String? = nil
    
    var body: some View {
        HStack(spacing: 4) {
            if let icon = icon {
                Image(systemName: icon)
                    .font(.caption2)
            }
            Text(text)
                .font(.caption2)
                .fontWeight(.medium)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .foregroundColor(color)
        .background(color.opacity(0.1))
        .cornerRadius(6)
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(color.opacity(0.2), lineWidth: 1)
        )
    }
}

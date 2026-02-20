import SwiftUI
import SkillHubCore

struct ProductCardView: View {
    let product: Product
    var installedSkillsCount: Int = 0
    var enabledSkillsCount: Int = 0
    
    @State private var isHovered = false
    
    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.secondary.opacity(0.1))
                    .frame(width: 48, height: 48)
                
                Image(systemName: product.iconName)
                    .font(.system(size: 24))
                    .foregroundColor(.secondary)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(product.name)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    if product.isCustom {
                        Text("CUSTOM")
                            .font(.system(size: 10, weight: .bold))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.accentColor.opacity(0.1))
                            .foregroundColor(.accentColor)
                            .clipShape(Capsule())
                    }
                }
                
                Text(product.description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                
                if installedSkillsCount > 0 {
                    HStack(spacing: 12) {
                        Label("\(enabledSkillsCount) enabled", systemImage: "checkmark.circle.fill")
                            .font(.caption)
                            .foregroundColor(.green)
                        
                        Label("\(installedSkillsCount - enabledSkillsCount) installed", systemImage: "arrow.down.circle")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            Spacer()
            
            StatusBadgeView(status: product.status)
        }
        .padding(16)
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.primary.opacity(isHovered ? 0.1 : 0.05), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(isHovered ? 0.08 : 0.02), radius: isHovered ? 8 : 2, x: 0, y: isHovered ? 2 : 1)
        .scaleEffect(isHovered ? 1.005 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isHovered)
        .onHover { hover in
            isHovered = hover
        }
    }
}

struct StatusBadgeView: View {
    let status: ProductStatus
    
    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(statusColor)
                .frame(width: 6, height: 6)
            
            Text(statusText)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(statusColor)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(statusColor.opacity(0.1))
        .clipShape(Capsule())
    }
    
    var statusText: String {
        switch status {
        case .active: return "Active"
        case .notInstalled: return "Not Installed"
        case .error: return "Error"
        }
    }
    
    var statusColor: Color {
        switch status {
        case .active: return .green
        case .notInstalled: return .gray
        case .error: return .red
        }
    }
}

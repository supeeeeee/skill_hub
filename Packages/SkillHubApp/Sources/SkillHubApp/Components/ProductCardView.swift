import SwiftUI
import SkillHubCore

struct ProductCardView: View {
    @EnvironmentObject var preferences: UserPreferences
    let product: Product
    var installedSkillsCount: Int = 0
    var enabledSkillsCount: Int = 0
    
    var body: some View {
        HStack {
            Image(systemName: product.iconName)
                .font(.system(size: 24))
                .foregroundColor(.secondary)
                .frame(width: 48, height: 48)
                .background(Color.gray.opacity(0.1))
                .cornerRadius(8)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(product.name)
                    .font(.headline)
                Text(product.description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                if installedSkillsCount > 0 {
                    HStack(spacing: 8) {
                        Label("\(enabledSkillsCount) enabled", systemImage: "checkmark.circle.fill")
                            .font(.caption2)
                            .foregroundColor(.green)
                        Label("\(installedSkillsCount - enabledSkillsCount) deployed", systemImage: "arrow.down.circle")
                            .font(.caption2)
                            .foregroundColor(.blue)
                    }
                }
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                StatusBadgeView(status: product.status)
                
                HStack(spacing: 4) {
                    ForEach(product.supportedModes.filter { preferences.isAdvancedMode || $0 != .configPatch }, id: \.self) { mode in
                        ModePillView(mode: mode)
                    }
                }
            }
        }
        .padding()
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
    }
}

struct StatusBadgeView: View {
    let status: ProductStatus
    
    var body: some View {
        Text(statusText)
            .font(.caption2.bold())
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(statusColor.opacity(0.1))
            .foregroundColor(statusColor)
            .cornerRadius(4)
    }
    
    var statusText: String {
        switch status {
        case .active: return "ACTIVE"
        case .notInstalled: return "NOT INSTALLED"
        case .error: return "ERROR"
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

struct ModePillView: View {
    let mode: InstallMode
    
    var body: some View {
        Text(mode.rawValue.uppercased())
            .font(.system(size: 8, weight: .bold))
            .padding(.horizontal, 4)
            .padding(.vertical, 2)
            .background(Color.blue.opacity(0.1))
            .foregroundColor(.blue)
            .cornerRadius(4)
    }
}

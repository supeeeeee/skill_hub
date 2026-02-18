import SwiftUI
import SkillHubCore

enum SkillProductStatus {
    case enabled
    case installed
    case notInstalled
    
    var color: Color {
        switch self {
        case .enabled: return .green
        case .installed: return .blue
        case .notInstalled: return .gray
        }
    }
    
    var icon: String {
        switch self {
        case .enabled: return "✅"
        case .installed: return "⚪"
        case .notInstalled: return "🟡"
        }
    }
}

struct ProductStatusView: View {
    let productID: String
    let productName: String
    let status: SkillProductStatus
    let onToggle: () -> Void
    var onNavigateToProduct: (() -> Void)? = nil
    
    var body: some View {
        HStack {
            Button(action: { onNavigateToProduct?() }) {
                HStack(spacing: 4) {
                    Text(productName)
                        .font(.caption)
                        .foregroundColor(.primary)
                    Image(systemName: "chevron.right")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            .buttonStyle(.plain)
            .frame(width: 100, alignment: .leading)
            
            Text(status.icon)
                .font(.caption)
            
            Spacer()
            
            if status == .installed {
                Button("Enable") {
                    onToggle()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            } else if status == .enabled {
                Button("Disable") {
                    onToggle()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 8)
        .background(status.color.opacity(0.1))
        .cornerRadius(6)
    }
}

struct SkillCardView: View {
    let skill: InstalledSkillRecord
    
    private let productIcons: [String: String] = [
        "openclaw": "terminal.fill",
        "opencode": "hammer.fill",
        "codex": "book.closed.fill",
        "cursor": "cursorarrow.rays",
        "claude-code": "brain.head.profile"
    ]
    
    private let productColors: [String: Color] = [
        "openclaw": .orange,
        "opencode": .blue,
        "codex": .purple,
        "cursor": .cyan,
        "claude-code": .indigo
    ]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                nameAndVersionView
                
                Spacer()
                
                badgesView
            }
            
            descriptionView
            
            Spacer(minLength: 0)
            
            footerView
        }
        .padding(16)
        .frame(height: 160)
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.primary.opacity(0.05), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.03), radius: 4, x: 0, y: 2)
        .contentShape(Rectangle()) // Improves hover/click area
    }
    
    private var nameAndVersionView: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(skill.manifest.name)
                .font(.headline)
                .foregroundColor(.primary)
                .lineLimit(1)
            
            Text("v\(skill.manifest.version)")
                .font(.caption2)
                .fontDesign(.monospaced)
                .foregroundColor(.secondary)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.secondary.opacity(0.1))
                .cornerRadius(4)
        }
    }
    
    private var badgesView: some View {
        HStack(spacing: 6) {
            if skill.hasUpdate {
                HStack(spacing: 2) {
                    Image(systemName: "arrow.triangle.2.circlepath")
                    Text("Update")
                }
                .font(.caption2)
                .fontWeight(.bold)
                .foregroundColor(.white)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.blue)
                .cornerRadius(4)
                .help("Update available")
            }

            HStack(spacing: -4) {
                ForEach(skill.installedProducts.sorted(), id: \.self) { productID in
                    if let icon = productIcons[productID] {
                        productBadge(productID: productID, icon: icon)
                    }
                }

                if skill.installedProducts.isEmpty {
                    Text("Not installed")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        }
    }
    
    private func productBadge(productID: String, icon: String) -> some View {
        ZStack {
            Circle()
                .fill(Color(nsColor: .controlBackgroundColor))
                .frame(width: 26, height: 26)
            
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundColor(skill.enabledProducts.contains(productID) ? (productColors[productID] ?? .primary) : .gray)
                .frame(width: 22, height: 22)
                .background(skill.enabledProducts.contains(productID) ? (productColors[productID] ?? .primary).opacity(0.15) : Color.gray.opacity(0.1))
                .clipShape(Circle())
                .overlay(
                    Circle()
                        .stroke(Color.secondary.opacity(0.1), lineWidth: 1)
                )
        }
        .help("\(productID): \(skill.enabledProducts.contains(productID) ? "Enabled" : "Disabled")")
    }
    
    private var descriptionView: some View {
        Text(skill.manifest.summary)
            .font(.subheadline)
            .foregroundColor(.secondary)
            .lineLimit(3)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    @ViewBuilder
    private var footerView: some View {
        if !skill.manifest.tags.isEmpty {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(skill.manifest.tags.prefix(3), id: \.self) { tag in
                        Text("#\(tag)")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.secondary.opacity(0.05))
                            .cornerRadius(4)
                    }
                }
            }
        }
    }
}

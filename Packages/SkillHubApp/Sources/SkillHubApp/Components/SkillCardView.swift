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
    let onSetup: () -> Void
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
            } else {
                Button("Install") {
                    onSetup()
                }
                .buttonStyle(.borderedProminent)
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
    var onSetup: (() -> Void)? = nil
    var onNavigateToProduct: ((String) -> Void)? = nil
    @State private var isExpanded = false
    
    private let allProducts = ["openclaw", "opencode", "codex"]
    private let productNames = ["openclaw": "OpenClaw", "opencode": "OpenCode", "codex": "Codex"]
    
    private func getStatus(for productID: String) -> SkillProductStatus {
        if skill.enabledProducts.contains(productID) {
            return .enabled
        } else if skill.installedProducts.contains(productID) {
            return .installed
        } else {
            return .notInstalled
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading) {
                    Text(skill.manifest.name)
                        .font(.headline)
                    Text("v\(skill.manifest.version)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 2)
                        .background(Color.secondary.opacity(0.1))
                        .cornerRadius(4)
                }
                Spacer()
                
                Button(action: { withAnimation { isExpanded.toggle() }}) {
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            
            Text(skill.manifest.summary)
                .font(.caption)
                .foregroundColor(.secondary)
                .lineLimit(2)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            HStack {
                ForEach(skill.manifest.tags.prefix(3), id: \.self) { tag in
                    Text("#\(tag)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                Spacer()
            }
            
            HStack(spacing: 8) {
                ForEach(allProducts, id: \.self) { productID in
                    let status = getStatus(for: productID)
                    Text("\(productNames[productID] ?? productID): \(status.icon)")
                        .font(.caption)
                        .foregroundColor(status.color)
                }
                Spacer()
            }
            
            if isExpanded {
                Divider()
                
                VStack(spacing: 8) {
                    ForEach(allProducts, id: \.self) { productID in
                        let status = getStatus(for: productID)
                        ProductStatusView(
                            productID: productID,
                            productName: productNames[productID] ?? productID,
                            status: status,
                            onToggle: {},
                            onSetup: {},
                            onNavigateToProduct: { onNavigateToProduct?(productID) }
                        )
                    }
                }
            }
            
            Divider()
            
            HStack {
                Text("\(skill.installedProducts.count) installs")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Button("Setup") {
                    onSetup?()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, minHeight: isExpanded ? 320 : 220, alignment: .topLeading)
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
    }
}

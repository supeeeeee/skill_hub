import SwiftUI
import SkillHubCore

struct SkillCardView: View {
    let skill: InstalledSkillRecord
    var onSetup: (() -> Void)? = nil
    
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
                
                if !skill.installedProducts.isEmpty {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                }
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
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
    }
}

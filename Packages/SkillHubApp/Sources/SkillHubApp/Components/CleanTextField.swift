import SwiftUI

public struct CleanTextField: View {
    let icon: String
    let placeholder: String
    @Binding var text: String
    var isMonospaced: Bool
    var trailingIcon: String?
    public init(icon: String, placeholder: String, text: Binding<String>, isMonospaced: Bool = false, trailingIcon: String? = nil) {
        self.icon = icon
        self.placeholder = placeholder
        self._text = text
        self.isMonospaced = isMonospaced
        self.trailingIcon = trailingIcon
    }
    
    public var body: some View {
        HStack(alignment: .center, spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.secondary)
                .frame(width: 24, alignment: .center)
            
            TextField(placeholder, text: $text)
                .textFieldStyle(.plain)
                .font(isMonospaced ? .system(size: 13, weight: .regular, design: .monospaced) : .system(size: 13, weight: .regular))
                .frame(maxWidth: .infinity, minHeight: 20, alignment: .leading)
            
            if let trailingIcon {
                Image(systemName: trailingIcon)
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.primary.opacity(0.1), lineWidth: 1)
        )
        .contentShape(RoundedRectangle(cornerRadius: 8))
    }
}

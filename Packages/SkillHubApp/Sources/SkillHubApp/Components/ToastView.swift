import SwiftUI

enum ToastType {
    case success
    case error
    case info
    
    var color: Color {
        switch self {
        case .success: return .green
        case .error: return .red
        case .info: return .blue
        }
    }
    
    var icon: String {
        switch self {
        case .success: return "checkmark.circle.fill"
        case .error: return "xmark.circle.fill"
        case .info: return "info.circle.fill"
        }
    }
}

struct Toast: Identifiable {
    let id = UUID()
    let message: String
    let type: ToastType
}

struct ToastView: View {
    let toast: Toast
    let onDismiss: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: toast.type.icon)
                .foregroundColor(toast.type.color)
            
            Text(toast.message)
                .font(.subheadline)
                .foregroundColor(.primary)
            
            Spacer()
            
            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(8)
        .shadow(color: Color.black.opacity(0.15), radius: 8, x: 0, y: 4)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(toast.type.color.opacity(0.3), lineWidth: 1)
        )
    }
}

struct ToastModifier: ViewModifier {
    @Binding var toasts: [Toast]
    
    func body(content: Content) -> some View {
        ZStack(alignment: .bottom) {
            content
            
            VStack(spacing: 8) {
                ForEach(toasts) { toast in
                    ToastView(toast: toast) {
                        dismissToast(id: toast.id)
                    }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .padding()
        }
    }
    
    private func dismissToast(id: UUID) {
        withAnimation {
            toasts.removeAll { $0.id == id }
        }
    }
}

extension View {
    func toast(_ toasts: Binding<[Toast]>) -> some View {
        modifier(ToastModifier(toasts: toasts))
    }
}

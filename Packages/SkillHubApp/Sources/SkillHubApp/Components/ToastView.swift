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

struct Toast: Identifiable, Equatable {
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
                .font(.system(size: 14, weight: .semibold))
                .frame(width: 20, height: 20)
            
            Text(toast.message)
                .font(.subheadline.weight(.medium))
                .foregroundColor(.primary)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
            
            Spacer()
            
            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .frame(maxWidth: 340, alignment: .leading)
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(10)
        .shadow(color: Color.black.opacity(0.12), radius: 10, x: 0, y: 4)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(toast.type.color.opacity(0.22), lineWidth: 1)
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

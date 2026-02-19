import SwiftUI

struct ToastHostView: View {
    @Binding var toasts: [Toast]

    var body: some View {
        VStack(alignment: .trailing, spacing: 8) {
            ForEach(Array(toasts.suffix(3))) { toast in
                ToastView(toast: toast) {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        toasts.removeAll { $0.id == toast.id }
                    }
                }
                .transition(.move(edge: .trailing).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.2), value: toasts)
    }
}

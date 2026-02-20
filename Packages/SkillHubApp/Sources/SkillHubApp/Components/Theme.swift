import SwiftUI

struct Theme {
    struct Colors {
        static let background = Color("AppBackground")
        static let surface = Color(nsColor: .controlBackgroundColor)
        static let secondarySurface = Color(nsColor: .controlBackgroundColor).opacity(0.5)
        static let accent = Color.accentColor
        static let textPrimary = Color.primary
        static let textSecondary = Color.secondary
        static let border = Color.gray.opacity(0.2)
        
        static func status(_ status: ProductStatus) -> Color {
            switch status {
            case .active: return .green
            case .notInstalled: return .gray
            case .error: return .red
            }
        }
    }
    
    struct Layout {
        static let cardPadding: CGFloat = 16
        static let cornerRadius: CGFloat = 12
        static let smallCornerRadius: CGFloat = 8
        static let shadowRadius: CGFloat = 4
        static let gridSpacing: CGFloat = 20
    }
}

struct CardStyle: ViewModifier {
    @State private var isHovered = false
    
    func body(content: Content) -> some View {
        content
            .padding(Theme.Layout.cardPadding)
            .background(
                RoundedRectangle(cornerRadius: Theme.Layout.cornerRadius)
                    .fill(Theme.Colors.surface)
                    .shadow(
                        color: Color.black.opacity(isHovered ? 0.08 : 0.04),
                        radius: isHovered ? 8 : 4,
                        x: 0,
                        y: isHovered ? 4 : 2
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Layout.cornerRadius)
                    .stroke(Theme.Colors.border.opacity(isHovered ? 0.4 : 0.2), lineWidth: 1)
            )
            .scaleEffect(isHovered ? 1.005 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isHovered)
            .onHover { hover in
                isHovered = hover
            }
    }
}

extension View {
    func cardStyle() -> some View {
        modifier(CardStyle())
    }
}

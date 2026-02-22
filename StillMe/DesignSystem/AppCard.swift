import SwiftUI

struct AppCard<Content: View>: View {
    var padding: CGFloat = Spacing.md
    var cornerRadius: CGFloat = Radius.lg
    var backgroundColor: Color = .dsCard
    var borderColor: Color = .dsBorder
    var showGlow: Bool = true
    var content: () -> Content
    
    init(padding: CGFloat = Spacing.md, cornerRadius: CGFloat = Radius.lg, backgroundColor: Color = .dsCard, borderColor: Color = .dsBorder, showGlow: Bool = true, @ViewBuilder content: @escaping () -> Content) {
        self.padding = padding
        self.cornerRadius = cornerRadius
        self.backgroundColor = backgroundColor
        self.borderColor = borderColor
        self.showGlow = showGlow
        self.content = content
    }
    
    var body: some View {
        content()
            .padding(padding)
            .background(backgroundColor)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(
                        borderColor,
                        lineWidth: 1
                    )
            )
            .background(
                Group {
                    if showGlow {
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .fill(Color.white.opacity(0.08))
                            .blur(radius: 12)
                            .padding(-2)
                    }
                }
            )
    }
}

// Physics-based interactive card (optional, can just wrap AppCard for now)
struct PhysicsAppCard<Content: View>: View {
    var padding: CGFloat = Spacing.md
    var content: () -> Content
    
    init(padding: CGFloat = Spacing.md, @ViewBuilder content: @escaping () -> Content) {
        self.padding = padding
        self.content = content
    }
    
    var body: some View {
        AppCard(padding: padding, content: content)
            // Future: Add drag gestures or spring animations here
    }
}

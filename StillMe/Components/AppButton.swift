import SwiftUI

struct AppButton: View {
    enum Variant {
        case primary
        case secondary
        case ghost
        case icon
    }
    
    let label: String
    let icon: String?
    let variant: Variant
    let action: () -> Void
    
    init(
        _ label: String = "",
        icon: String? = nil,
        variant: Variant = .primary,
        action: @escaping () -> Void
    ) {
        self.label = label
        self.icon = icon
        self.variant = variant
        self.action = action
    }
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: Spacing.md) {
                if let icon = icon {
                    Image(systemName: icon)
                }
                if !label.isEmpty {
                    Text(LocalizedStringKey(label))
                        .font(Typography.small)
                }
            }
            .padding(.horizontal, variant == .icon ? 0 : Spacing.xl)
            .padding(.vertical, variant == .icon ? 0 : Spacing.lg)
            .frame(maxWidth: variant == .icon ? nil : .infinity)
            .background(backgroundView)
            .foregroundColor(.white)
            .clipShape(RoundedRectangle(cornerRadius: Radius.lg, style: .continuous))
            .contentShape(Rectangle())
        }
        .buttonStyle(AppButtonStyle())
    }
    
    @ViewBuilder
    private var backgroundView: some View {
        switch variant {
        case .primary:
            Color.white.opacity(0.1)
                .background(.ultraThinMaterial)
        case .secondary:
            Color.white.opacity(0.05)
        case .ghost:
            Color.clear
        case .icon:
            Color.white.opacity(0.1)
                .frame(width: 36, height: 36)
                .clipShape(Circle())
        }
    }
}

struct AppButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .opacity(configuration.isPressed ? 0.8 : 1.0)
            .animation(.easeOut(duration: 0.1), value: configuration.isPressed)
    }
}

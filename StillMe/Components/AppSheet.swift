import SwiftUI

struct AppSheet<Content: View>: View {
    @Binding var isPresented: Bool
    let direction: Edge
    let content: Content
    
    init(
        isPresented: Binding<Bool>,
        direction: Edge = .bottom,
        @ViewBuilder content: () -> Content
    ) {
        self._isPresented = isPresented
        self.direction = direction
        self.content = content()
    }
    
    var body: some View {
        ZStack {
            if isPresented {
                // Overlay
                Color.black.opacity(0.5)
                    .ignoresSafeArea()
                    .onTapGesture {
                        withAnimation(Motion.standard) {
                            isPresented = false
                        }
                    }
                    .transition(.opacity)
                
                // Content Area
                VStack(spacing: 0) {
                    if direction == .bottom {
                        // Handle bar
                        Capsule()
                            .fill(Color.white.opacity(0.1))
                            .frame(width: 40, height: 4)
                            .padding(.top, 12)
                            .padding(.bottom, 8)
                    }
                    
                    content
                        .padding(Spacing.xxl)
                    
                    if direction == .bottom {
                        Spacer(minLength: 0)
                    }
                }
                .frame(maxWidth: .infinity)
                .background(Color.dsBackground)
                .cornerRadius(Radius.lg, corners: cornerRadiusForDirection)
                .transition(.move(edge: direction))
                .zIndex(1)
                // Position logic
                .frame(maxHeight: .infinity, alignment: alignmentForDirection)
            }
        }
    }
    
    private var alignmentForDirection: Alignment {
        switch direction {
        case .top: return .top
        case .bottom: return .bottom
        case .leading: return .leading
        case .trailing: return .trailing
        }
    }
    
    private var cornerRadiusForDirection: UIRectCorner {
        switch direction {
        case .top: return [.bottomLeft, .bottomRight]
        case .bottom: return [.topLeft, .topRight]
        case .leading: return [.topRight, .bottomRight]
        case .trailing: return [.topLeft, .bottomLeft]
        }
    }
}

// SwiftUI Helper for specific corners
struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(roundedRect: rect, byRoundingCorners: corners, cornerRadii: CGSize(width: radius, height: radius))
        return Path(path.cgPath)
    }
}

extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
}

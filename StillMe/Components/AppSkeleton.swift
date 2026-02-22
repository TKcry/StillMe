import SwiftUI

struct AppSkeleton: View {
    @State private var opacity: Double = 0.3
    
    var body: some View {
        RoundedRectangle(cornerRadius: Radius.md)
            .fill(Color.white.opacity(0.1))
            .opacity(opacity)
            .onAppear {
                withAnimation(Animation.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
                    opacity = 0.6
                }
            }
    }
}

extension View {
    func skeleton(isVisible: Bool) -> some View {
        self.overlay(
            Group {
                if isVisible {
                    AppSkeleton()
                }
            }
        )
    }
}

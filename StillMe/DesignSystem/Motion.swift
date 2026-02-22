import SwiftUI

struct Motion {
    static let standard = Animation.easeInOut(duration: 0.2)
    static let flash = Animation.easeInOut(duration: 0.3)
    static let slow = Animation.easeInOut(duration: 1.0) // Transition-all duration-1000
    
    // Custom View Modifier for Flash
    struct FlashEffect: ViewModifier {
        @State private var isVisible = true
        let duration: Double
        
        func body(content: Content) -> some View {
            content
                .opacity(isVisible ? 1.0 : 0.5)
                .onAppear {
                    withAnimation(Animation.easeInOut(duration: duration).repeatForever(autoreverses: true)) {
                        isVisible.toggle()
                    }
                }
        }
    }
}

extension View {
    func dsFlash(duration: Double = 0.3) -> some View {
        self.modifier(Motion.FlashEffect(duration: duration))
    }
}

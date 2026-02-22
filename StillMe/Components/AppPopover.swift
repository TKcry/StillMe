import SwiftUI

struct AppPopover<Content: View>: View {
    @Binding var isPresented: Bool
    let content: Content
    
    init(isPresented: Binding<Bool>, @ViewBuilder content: () -> Content) {
        self._isPresented = isPresented
        self.content = content()
    }
    
    var body: some View {
        ZStack {
            if isPresented {
                // Clear overlay to detect taps outside
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture {
                        withAnimation(Motion.standard) {
                            isPresented = false
                        }
                    }
                    .ignoresSafeArea()
                
                content
                    .padding(Spacing.lg)
                    .background(Color.dsBackground)
                    .cornerRadius(Radius.md)
                    .overlay(
                        RoundedRectangle(cornerRadius: Radius.md)
                            .stroke(Color.white.opacity(0.1), lineWidth: 1)
                    )
                    .shadow(color: Color.black.opacity(0.3), radius: 10, x: 0, y: 5)
                    .transition(.asymmetric(
                        insertion: .scale(scale: 0.95, anchor: .top).combined(with: .opacity),
                        removal: .scale(scale: 0.95, anchor: .top).combined(with: .opacity)
                    ))
            }
        }
    }
}

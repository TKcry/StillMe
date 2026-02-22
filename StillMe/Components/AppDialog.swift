import SwiftUI

struct AppDialog<Content: View>: View {
    @Binding var isPresented: Bool
    let title: String
    let description: String?
    let content: Content
    
    init(
        isPresented: Binding<Bool>,
        title: String,
        description: String? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self._isPresented = isPresented
        self.title = title
        self.description = description
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
                
                // Content
                VStack(alignment: .leading, spacing: Spacing.xl) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(title)
                                .font(Typography.h2)
                                .foregroundColor(.dsForeground)
                            if let desc = description {
                                Text(desc)
                                    .font(Typography.small)
                                    .foregroundColor(.dsMuted)
                            }
                        }
                        Spacer()
                        Button {
                            withAnimation(Motion.standard) {
                                isPresented = false
                            }
                        } label: {
                            Image(systemName: "xmark")
                                .foregroundColor(.dsMutedDeep)
                        }
                    }
                    
                    content
                }
                .padding(Spacing.xxl)
                .background(Color.dsBackground)
                .cornerRadius(Radius.lg)
                .overlay(
                    RoundedRectangle(cornerRadius: Radius.lg)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )
                .padding(Spacing.xxl)
                .transition(.asymmetric(
                    insertion: .scale(scale: 0.95).combined(with: .opacity),
                    removal: .scale(scale: 0.95).combined(with: .opacity)
                ))
                .zIndex(1)
            }
        }
    }
}

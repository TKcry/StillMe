import SwiftUI

struct OnboardingWelcomeView: View {
    var onNext: () -> Void
    
    var body: some View {
        ZStack {
            Color.dsBackground.ignoresSafeArea()
            
            VStack(spacing: 40) {
                Spacer()
                
                ZStack {
                    Circle()
                        .fill(Color.dsSuccess.opacity(0.1))
                        .frame(width: 120, height: 120)
                    Image(systemName: "face.smiling")
                        .font(.system(size: 60))
                        .foregroundColor(.dsSuccess)
                }
                
                VStack(spacing: 16) {
                    Text("welcome_title")
                        .font(Typography.h1)
                        .foregroundColor(.dsForeground)
                    
                    Text("welcome_subtitle")
                        .font(Typography.bodyMedium)
                        .foregroundColor(.dsMuted)
                        .multilineTextAlignment(.center)
                        .lineSpacing(6)
                }
                .padding(.horizontal, 40)
                
                Spacer()
                
                AppButton("button_get_started", icon: "arrow.right") {
                    onNext()
                }
                .padding(.horizontal, Spacing.xxl)
                .padding(.bottom, 60)
            }
        }
        .navigationBarBackButtonHidden(true)
        .navigationBarHidden(true)
    }
}

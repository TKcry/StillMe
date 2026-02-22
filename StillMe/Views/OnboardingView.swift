import SwiftUI

struct OnboardingView: View {
    @EnvironmentObject var viewModel: AppViewModel
    
    var body: some View {
        ZStack {
            Color.dsBackground.ignoresSafeArea()
            
            VStack(spacing: 40) {
                Spacer()
                
                // Welcome Icon
                ZStack {
                    Circle()
                        .fill(Color.dsSuccess.opacity(0.1))
                        .frame(width: 120, height: 120)
                    Image(systemName: "face.smiling")
                        .font(.system(size: 60))
                        .foregroundColor(.dsSuccess)
                }
                
                VStack(spacing: 16) {
                    Text("onboarding_title")
                        .font(Typography.h1)
                        .foregroundColor(.dsForeground)
                    
                    Text("onboarding_subtitle")
                        .font(Typography.bodyMedium)
                        .foregroundColor(.dsMuted)
                        .multilineTextAlignment(.center)
                        .lineSpacing(6)
                }
                .padding(.horizontal, 40)
                
                VStack(alignment: .leading, spacing: 20) {
                    FeatureRow(icon: "camera.fill", title: NSLocalizedString("feature_logging_title", comment: ""), detail: NSLocalizedString("feature_logging_detail", comment: ""))
                    FeatureRow(icon: "person.2.fill", title: NSLocalizedString("feature_sharing_title", comment: ""), detail: NSLocalizedString("feature_sharing_detail", comment: ""))
                    FeatureRow(icon: "chart.line.uptrend.xyaxis", title: NSLocalizedString("feature_tracking_title", comment: ""), detail: NSLocalizedString("feature_tracking_detail", comment: ""))
                }
                .padding(.horizontal, 32)
                
                Spacer()
                
                AppButton("button_get_started", icon: "arrow.right") {
                    withAnimation(.spring()) {
                        viewModel.hasCompletedOnboarding = true
                        viewModel.showForceOnboarding = false
                    }
                }
                .padding(.horizontal, Spacing.xxl)
                .padding(.bottom, 40)
            }
        }
    }
}

struct FeatureRow: View {
    let icon: String
    let title: String
    let detail: String
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(.dsSuccess.opacity(0.8))
                .frame(width: 32)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(Typography.small)
                    .fontWeight(.bold)
                    .foregroundColor(.dsForeground)
                Text(detail)
                    .font(Typography.extraSmall)
                    .foregroundColor(.dsMuted)
            }
        }
    }
}

#Preview {
    OnboardingView()
        .environmentObject(AppViewModel())
}

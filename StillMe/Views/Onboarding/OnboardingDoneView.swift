import SwiftUI

struct OnboardingDoneView: View {
    @EnvironmentObject var viewModel: AppViewModel
    @EnvironmentObject var draft: OnboardingDraft
    @State private var isLoading = false
    @State private var errorMessage: String? = nil
    
    var body: some View {
        ZStack {
            Color.dsBackground.ignoresSafeArea()
            
            VStack(spacing: 32) {
                Spacer()
                
                ZStack {
                    Circle()
                        .fill(Color.dsSuccess.opacity(0.1))
                        .frame(width: 120, height: 120)
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.dsSuccess)
                }
                
                VStack(spacing: 16) {
                    Text("onboarding_done_title")
                        .font(Typography.h1)
                        .foregroundColor(.dsForeground)
                    
                    Text("onboarding_done_subtitle")
                        .font(Typography.bodyMedium)
                        .foregroundColor(.dsMuted)
                        .multilineTextAlignment(.center)
                        .lineSpacing(6)
                }
                .padding(.horizontal, 40)
                
                if let error = errorMessage {
                    Text(error)
                        .font(Typography.extraSmall)
                        .foregroundColor(.red.opacity(0.8))
                        .padding(.top, 10)
                }
                
                Spacer()
                
                Button {
                    finish()
                } label: {
                    HStack {
                        if isLoading {
                            ProgressView().tint(.black)
                        } else {
                            Text("button_go_home")
                                .font(Typography.small.bold())
                            Image(systemName: "house.fill")
                        }
                    }
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Spacing.lg)
                    .background(isLoading ? Color.white.opacity(0.5) : Color.white)
                    .cornerRadius(Radius.lg)
                }
                .disabled(isLoading)
                .buttonStyle(AppButtonStyle())
                .padding(.horizontal, Spacing.xxl)
                .padding(.bottom, 60)
            }
        }
        .navigationBarHidden(true)
    }
    
    private func finish() {
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                try await viewModel.finishOnboarding(draft: draft)
            } catch {
                await MainActor.run {
                    isLoading = false
                    errorMessage = error.localizedDescription
                }
            }
        }
    }
}

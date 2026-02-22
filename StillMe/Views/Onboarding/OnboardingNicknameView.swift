import SwiftUI

struct OnboardingNicknameView: View {
    @EnvironmentObject var viewModel: AppViewModel
    @EnvironmentObject var draft: OnboardingDraft
    @State private var nickname: String = ""
    @State private var isLoading = false
    @State private var errorMessage: String? = nil
    var onNext: () -> Void
    
    var body: some View {
        ZStack {
            Color.dsBackground.ignoresSafeArea()
            
            VStack(spacing: 0) {
                Spacer()
                
                VStack(spacing: 0) {
                    // Centered Header
                    VStack(spacing: 8) {
                        Text("nickname_title")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(.dsForeground)
                        
                        Text("nickname_hint")
                            .font(.callout)
                            .foregroundColor(.dsMuted.opacity(0.6))
                            .lineSpacing(2)
                    }
                    .multilineTextAlignment(.center)
                    .padding(.bottom, 40)
                    
                    // Centered Minimalist Input
                    GeometryReader { geo in
                        VStack(spacing: 8) {
                            TextField("", text: $nickname, prompt: Text("enter_name_placeholder").foregroundColor(.dsMutedDeep))
                                .font(.system(size: 17, weight: .medium))
                                .multilineTextAlignment(.center)
                                .foregroundColor(.dsForeground)
                                .tint(.white)
                            
                            // Thin Underline
                            Rectangle()
                                .fill(Color.white.opacity(nickname.isEmpty ? 0.2 : 0.4))
                                .frame(height: 1)
                                .animation(.easeInOut, value: nickname.isEmpty)
                            
                            if nickname.count > 0 {
                                Text("\(nickname.count) / 20")
                                    .font(Typography.extraSmall)
                                    .foregroundColor(.dsMuted)
                                    .frame(maxWidth: .infinity, alignment: .center)
                                    .padding(.top, 4)
                            }
                        }
                        .frame(width: geo.size.width * 0.75)
                        .position(x: geo.size.width / 2, y: 30) // Manual offset for height of input block
                    }
                    .frame(height: 60)
                }
                
                if let error = errorMessage {
                    Text(error)
                        .font(Typography.extraSmall)
                        .foregroundColor(.red.opacity(0.8))
                        .padding(.top, 20)
                }
                
                Spacer()
                Spacer()
                
                // CTA Button (High Contrast)
                Button {
                    submit()
                } label: {
                    HStack {
                        if isLoading {
                            ProgressView().tint(.black)
                        } else {
                            Text("next_label")
                                .font(Typography.small.bold())
                            Image(systemName: "arrow.right")
                        }
                    }
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Spacing.lg)
                    .background(nickname.trimmingCharacters(in: .whitespaces).isEmpty || nickname.count > 20 || isLoading ? Color.white.opacity(0.2) : Color.white)
                    .cornerRadius(Radius.lg)
                }
                .disabled(nickname.trimmingCharacters(in: .whitespaces).isEmpty || nickname.count > 20 || isLoading)
                .buttonStyle(AppButtonStyle())
                .padding(.horizontal, 40)
                .padding(.bottom, 60)
            }
        }
        .navigationBarHidden(true)
        .onAppear {
            nickname = draft.nickname.isEmpty ? (viewModel.profile.name == "User" ? "" : viewModel.profile.name) : draft.nickname
        }
    }
    
    private func submit() {
        let trimmed = nickname.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        
        draft.nickname = trimmed
        onNext()
    }
}

import SwiftUI
import FirebaseAuth

struct OnboardingEmailView: View {
    @EnvironmentObject var viewModel: AppViewModel
    @Environment(\.dismiss) var dismiss
    
    @State private var email = ""
    @State private var isLoading = false
    @State private var isLinkSent = false
    @State private var errorMessage: String? = nil
    
    var onNext: () -> Void
    
    var body: some View {
        ZStack {
            Color.dsBackground.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Back Button
                HStack {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.dsForeground)
                    }
                    Spacer()
                }
                .padding(.horizontal, 24)
                .padding(.top, 16)
                
                Spacer()
                
                VStack(spacing: 48) {
                    VStack(spacing: 12) {
                        Text(isLinkSent ? "メールを確認してください" : "メールアドレスでログイン")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(.dsForeground)
                        
                        Text(isLinkSent ? "\(email) 宛にログインリンクを送信しました。メール内のリンクをタップして戻ってください。" : "パスワードなしでログインできるリンクを送信します。")
                            .font(.subheadline)
                            .foregroundColor(.dsMuted)
                            .padding(.horizontal, 40)
                    }
                    .multilineTextAlignment(.center)
                    
                    if !isLinkSent {
                        VStack(spacing: 24) {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("メールアドレス")
                                    .font(.caption)
                                    .foregroundColor(.dsMuted)
                                
                                TextField("", text: $email)
                                    .textFieldStyle(.plain)
                                    .keyboardType(.emailAddress)
                                    .autocapitalization(.none)
                                    .foregroundColor(.dsForeground)
                                    .tint(.white)
                                
                                Rectangle()
                                    .fill(Color.white.opacity(0.1))
                                    .frame(height: 1)
                            }
                        }
                        .padding(.horizontal, 40)
                    } else {
                        Image(systemName: "paperplane.fill")
                            .font(.system(size: 60))
                            .foregroundColor(.dsMuted.opacity(0.3))
                            .padding(.top, 20)
                    }
                }
                
                if let error = errorMessage {
                    Text(error)
                        .font(.system(size: 12))
                        .foregroundColor(.red.opacity(0.8))
                        .padding(.top, 24)
                        .padding(.horizontal, 40)
                        .multilineTextAlignment(.center)
                }
                
                Spacer()
                Spacer()
                
                if !isLinkSent {
                    Button {
                        handleSendLink()
                    } label: {
                        HStack {
                            if isLoading {
                                ProgressView().tint(.black)
                            } else {
                                Text("ログインリンクを送信")
                                    .font(.system(size: 16, weight: .bold))
                                Image(systemName: "paperplane.fill")
                            }
                        }
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(canSubmit ? Color.white : Color.white.opacity(0.1))
                        .cornerRadius(28)
                    }
                    .disabled(!canSubmit || isLoading)
                    .padding(.horizontal, 40)
                    .padding(.bottom, 60)
                } else {
                    Button {
                        isLinkSent = false
                        errorMessage = nil
                    } label: {
                        Text("メールアドレスを入力し直す")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.dsMuted)
                            .underline()
                    }
                    .padding(.bottom, 60)
                }
            }
        }
        .navigationBarHidden(true)
    }
    
    private var canSubmit: Bool {
        !email.isEmpty && email.contains("@")
    }
    
    private func handleSendLink() {
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                try await viewModel.sessionStore.sendSignInLink(to: email)
                isLoading = false
                withAnimation {
                    isLinkSent = true
                }
            } catch {
                isLoading = false
                errorMessage = error.localizedDescription
            }
        }
    }
}

#Preview {
    OnboardingEmailView(onNext: {})
        .environmentObject(AppViewModel())
}

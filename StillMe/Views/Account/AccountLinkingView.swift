import SwiftUI
import FirebaseAuth
import Combine

struct AccountLinkingView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var appViewModel: AppViewModel
    
    var body: some View {
        ZStack {
            Color.dsBackground.ignoresSafeArea()
            
            VStack(spacing: Spacing.xl) {
                Text("login_step_subtitle")
                    .font(Typography.bodyBold)
                    .foregroundColor(.dsForeground)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                    .padding(.top, 24)
                
                VStack(spacing: 16) {
                    // Apple Linking Button
                    let isAppleLinked = isProviderLinked("apple.com")
                    Button {
                        if !isAppleLinked {
                            Task {
                                try? await appViewModel.sessionStore.linkWithApple()
                                self.appViewModel.objectWillChange.send()
                            }
                        }
                    } label: {
                        HStack(spacing: 8) {
                            if isAppleLinked {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.dsSuccess)
                                Text("Apple \("linked_label")")
                                    .font(.system(size: 18, weight: .medium))
                                    .foregroundColor(.dsMuted)
                            } else {
                                Image(systemName: "apple.logo")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 18, height: 18)
                                    .foregroundColor(.black)
                                    .offset(y: -1)
                                
                                Text("Appleで連携")
                                    .font(.system(size: 18, weight: .medium))
                                    .foregroundColor(.black)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(isAppleLinked ? Color.white.opacity(0.1) : Color.white)
                        .cornerRadius(28)
                    }
                    .disabled(isAppleLinked)
                    
                    // Google Linking Button
                    let isGoogleLinked = isProviderLinked("google.com")
                    Button {
                        if !isGoogleLinked {
                            Task {
                                try? await appViewModel.sessionStore.linkWithGoogle()
                                self.appViewModel.objectWillChange.send()
                            }
                        }
                    } label: {
                        HStack(spacing: 8) {
                            if isGoogleLinked {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.dsSuccess)
                                Text("Google \("linked_label")")
                                    .font(.system(size: 18, weight: .medium))
                                    .foregroundColor(.dsMuted)
                            } else {
                                Image("Google_logo")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 18, height: 18)
                                    .padding(1)
                                
                                Text("Google で連携")
                                    .font(.system(size: 18, weight: .medium))
                                    .foregroundColor(Color(red: 31/255, green: 31/255, blue: 31/255))
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(isGoogleLinked ? Color.white.opacity(0.1) : Color.white)
                        .overlay(
                            RoundedRectangle(cornerRadius: 28)
                                .stroke(isGoogleLinked ? Color.clear : Color(red: 116/255, green: 119/255, blue: 117/255), lineWidth: 1)
                        )
                        .cornerRadius(28)
                    }
                    .disabled(isGoogleLinked)
                    
                    // Email Linking Button
                    let isEmailLinked = isProviderLinked("password") || isProviderLinked("emailLink")
                    NavigationLink(destination: AccountEmailLinkingView().environmentObject(appViewModel)) {
                        HStack(spacing: 8) {
                            if isEmailLinked {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.dsSuccess)
                                Text("メールアドレス \("linked_label")")
                                    .font(.system(size: 18, weight: .medium))
                                    .foregroundColor(.dsMuted)
                            } else {
                                Image(systemName: "envelope.fill")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 18, height: 18)
                                    .foregroundColor(.dsMuted)
                                
                                Text("メールアドレス入力")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(.dsMuted)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(Color.white.opacity(0.1))
                        .cornerRadius(28)
                    }
                    .disabled(isEmailLinked)
                }
                .padding(.horizontal, 24)
                
                Spacer()
            }
        }
        .navigationTitle("account_section_linking")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    private func isProviderLinked(_ providerId: String) -> Bool {
        return Auth.auth().currentUser?.providerData.contains(where: { $0.providerID == providerId }) ?? false
    }
}

import SwiftUI
import AuthenticationServices
import Firebase
import FirebaseAuth

struct OnboardingLoginView: View {
    @EnvironmentObject var viewModel: AppViewModel
    var onNext: () -> Void
    var onEmailLogin: () -> Void
    
    @State private var isProcessing = false
    @State private var errorMessage: String?
    
    var body: some View {
        ZStack {
            Color.dsBackground.ignoresSafeArea()
            
            VStack(spacing: 32) {
                Spacer()
                
                // Header
                VStack(spacing: 12) {
                    Text("login_step_title")
                        .font(Typography.h1)
                        .foregroundColor(.dsForeground)
                }
                .padding(.horizontal, 40)
                
                // Login Buttons
                VStack(spacing: 16) {
                    // Apple Sign In (Custom Button matching Google style & adhering to guidelines)
                    Button {
                        handleAppleSignIn()
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "apple.logo")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 18, height: 18) // Guideline-aware size
                                .foregroundColor(.black) // Force black color
                                .offset(y: -1)
                            
                            Text("Appleでサインイン")
                                .font(.system(size: 18, weight: .medium)) // Slightly larger for 56pt button
                                .foregroundColor(.black)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(Color.white)
                        .cornerRadius(28)
                    }
                    
                    // Google Sign In (Custom Button matching Apple style & adhering to guidelines)
                    Button {
                        handleGoogleSignIn()
                    } label: {
                        HStack(spacing: 8) {
                            Image("Google_logo")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 18, height: 18) // Standard 18x18 size
                            
                            Text("Google でサインイン")
                                .font(.system(size: 18, weight: .medium))
                                .foregroundColor(Color(red: 31/255, green: 31/255, blue: 31/255))
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(Color.white)
                        .overlay(
                            RoundedRectangle(cornerRadius: 28)
                                .stroke(Color(red: 116/255, green: 119/255, blue: 117/255), lineWidth: 1)
                        )
                        .cornerRadius(28)
                    }
                    
                    // Email Sign In (Secondary Style)
                    Button {
                        onEmailLogin()
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "envelope.fill")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 16, height: 16)
                                .foregroundColor(.dsMuted)
                            
                            Text("メールアドレスでサインイン")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.dsMuted)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(Color.white.opacity(0.1))
                        .cornerRadius(28)
                    }
                }
                .padding(.horizontal, 40)
                
                if let error = errorMessage {
                    Text(error)
                        .font(Typography.extraSmall)
                        .foregroundColor(.dsError)
                        .padding(.horizontal, 40)
                        .multilineTextAlignment(.center)
                }
                
                Spacer()
                
                // Footer
                Text("login_footer")
                    .font(Typography.extraSmall)
                    .foregroundColor(.dsMuted.opacity(0.6))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
                    .padding(.bottom, 20)
            }
            
            if isProcessing {
                Color.black.opacity(0.4)
                    .ignoresSafeArea()
                ProgressView()
                    .tint(.white)
            }
        }
    }
    
    private func handleAppleSignIn() {
        let nonce = viewModel.sessionStore.randomNonceString()
        viewModel.sessionStore.currentNonce = nonce
        
        let appleIDProvider = ASAuthorizationAppleIDProvider()
        let request = appleIDProvider.createRequest()
        request.requestedScopes = [.fullName, .email]
        request.nonce = viewModel.sessionStore.sha256(nonce)
        
        let controller = ASAuthorizationController(authorizationRequests: [request])
        
        // We can reuse the delegate logic or implement it here
        // For simplicity and to ensure onNext() is called, we'll handle it here
        isProcessing = true
        errorMessage = nil
        
        let delegate = AppleSignInDelegate(nonce: nonce) { credential in
            Task {
                do {
                    try await Auth.auth().signIn(with: credential)
                    DispatchQueue.main.async {
                        self.isProcessing = false
                        self.onNext()
                    }
                } catch {
                    DispatchQueue.main.async {
                        self.isProcessing = false
                        self.errorMessage = error.localizedDescription
                    }
                }
            }
        }
        
        // Hold a reference to the delegate so it doesn't get deallocated
        // We'll use a temporary property or a coordination pattern
        // In this case, SessionStore can hold it
        viewModel.sessionStore.setAppleSignInDelegate(delegate)
        
        controller.delegate = delegate
        controller.performRequests()
    }
    
    // Internal delegate class to handle the results
    private class AppleSignInDelegate: NSObject, ASAuthorizationControllerDelegate {
        private let nonce: String
        private let onCredential: (AuthCredential) -> Void
        
        init(nonce: String, onCredential: @escaping (AuthCredential) -> Void) {
            self.nonce = nonce
            self.onCredential = onCredential
        }
        
        func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
            if let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential {
                guard let appleIDToken = appleIDCredential.identityToken else { return }
                guard let idTokenString = String(data: appleIDToken, encoding: .utf8) else { return }
                
                let credential = OAuthProvider.appleCredential(withIDToken: idTokenString,
                                                          rawNonce: nonce,
                                                          fullName: appleIDCredential.fullName)
                onCredential(credential)
            }
        }
        
        func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
            print("🟥 [AppleSignInDelegate] Error: \(error.localizedDescription)")
            // Notification or callback could be added here if needed
        }
    }
    
    private func handleGoogleSignIn() {
        isProcessing = true
        errorMessage = nil
        Task {
            do {
                try await viewModel.sessionStore.signInWithGoogle()
                isProcessing = false
                onNext()
            } catch {
                isProcessing = false
                errorMessage = error.localizedDescription
            }
        }
    }
}

#Preview {
    OnboardingLoginView(onNext: {}, onEmailLogin: {})
        .environmentObject(AppViewModel())
}

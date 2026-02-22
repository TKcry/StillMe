import Foundation
import Combine
import FirebaseAuth
import FirebaseFirestore
import AuthenticationServices
import CryptoKit
import GoogleSignIn

@MainActor
final class SessionStore: ObservableObject {
    @Published var uid: String? = nil
    @Published var isSignedIn: Bool = false

    private var authListener: AuthStateDidChangeListenerHandle? = nil
    private var didStartSync: Bool = false
    private var lastSyncedUid: String? = nil

    init() {
        startAuthListenerIfNeeded()
    }

    private func startAuthListenerIfNeeded() {
        guard authListener == nil else { return }
        authListener = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            guard let self = self else { return }
            let newUid = user?.uid
//            let providers = user?.providerData.map { $0.providerID } ?? []
//            print("[SessionStore] providers=\(providers) isSignedIn=\(user != nil)")
            if let uid = newUid {
                print("[SessionStore] uid changed -> \(uid)")
            } else {
                print("[SessionStore] uid changed -> nil")
            }
            self.uid = newUid
            Task { await self.handleAuthStateChange(uid: newUid) }
        }
    }

    private func handleAuthStateChange(uid: String?) async {
        // Only start sync if we have a real user (No more anonymous fallback)
        guard let user = Auth.auth().currentUser, !user.isAnonymous else { 
            print("[SessionStore] No valid user or anonymous user detected. Treating as signed out.")
            self.isSignedIn = false
            self.uid = nil
            self.didStartSync = false // Phase 270: Reset sync flag on sign-out
            self.lastSyncedUid = nil
            
            // Clean up legacy anonymous session if found
            if Auth.auth().currentUser?.isAnonymous == true {
                print("[SessionStore] 🧹 Auto signing out legacy anonymous session.")
                try? Auth.auth().signOut()
            }
            return 
        }

        // --- Phase: Account Deletion Grace Period Check ---
        let db = Firestore.firestore()
        let userRef = db.collection("users").document(user.uid)
        
        do {
            let snap = try await userRef.getDocument()
            if let data = snap.data(), let requestedAt = (data["deletionRequestedAt"] as? Timestamp)?.dateValue() {
                let gracePeriodSeconds: TimeInterval = 30 * 24 * 60 * 60 // 30 days
                let now = Date()
                
                if now.timeIntervalSince(requestedAt) < gracePeriodSeconds {
                    // RESTORE: Cancel deletion request
                    print("[SessionStore] ♻️ Deletion requested less than 30 days ago. RESTORING account.")
                    try await userRef.updateData([
                        "deletionRequestedAt": FieldValue.delete(),
                        "expireAt": FieldValue.delete()
                    ])
                    // Optional: Show restoration success message via NotificationCenter or similar
                    // For now, it just proceeds to sign in.
                } else {
                    // PURGE: 30 days have passed. Wipe data and Auth user.
                    print("[SessionStore] 💀 Grace period expired. PURGING user data.")
                    
                    // 1. Wipe Firestore document (Root only for now, subcollections remain but unlinked)
                    try await userRef.delete()
                    
                    // 2. Wipe Firebase Auth User
                    try await user.delete()
                    
                    // 3. Sign out local state
                    print("[SessionStore] Purge complete. Signing out.")
                    try? Auth.auth().signOut()
                    self.isSignedIn = false
                    self.uid = nil
                    return
                }
            }
        } catch {
            print("[SessionStore][GraceCheck] Error checking deletion status: \(error.localizedDescription)")
            // If it's a permission error or something, we might still proceed, 
            // but if the user doc is gone, it just proceeds as a new user.
        }
        
        self.isSignedIn = true
        self.uid = user.uid
        await startSyncIfNeeded(with: user.uid)
    }

    @MainActor
    private func startSyncIfNeeded(with uid: String) async {
        // Guard to run only once per unique uid and only once overall
        if didStartSync, lastSyncedUid == uid { return }
        didStartSync = true
        lastSyncedUid = uid
        print("[DEBUG] startFirebaseSync called with uid=\(uid)")
        print("[SessionStore] startFirebaseSync once with uid=\(uid)")
        do { try await PairStore.shared.startFirebaseSync(authUid: uid) }
        catch { print("[SessionStore] startFirebaseSync error: \(error)") }
    }

    @MainActor
    func ensureSignedIn() async {
        print("🟦 [SessionStore] ensureSignedIn ENTER @\(#fileID):\(#line)")
        if let user = Auth.auth().currentUser, !user.isAnonymous {
            self.uid = user.uid
            self.isSignedIn = true
            print("[SessionStore] session check uid=\(user.uid) isAnonymous=false")
            return
        }
        self.uid = nil
        self.isSignedIn = false
    }

    // MARK: - Apple Sign In
    
    internal var currentNonce: String?
    private var appleSignInControllerDelegate: ASAuthorizationControllerDelegate?

    func setAppleSignInDelegate(_ delegate: ASAuthorizationControllerDelegate) {
        self.appleSignInControllerDelegate = delegate
    }

    func startAppleSignIn() async throws {
        let nonce = randomNonceString()
        currentNonce = nonce
        
        let appleIDProvider = ASAuthorizationAppleIDProvider()
        let request = appleIDProvider.createRequest()
        request.requestedScopes = [.fullName, .email]
        request.nonce = sha256(nonce)
        
        let controller = ASAuthorizationController(authorizationRequests: [request])
        let delegate = AppleSignInDelegate(nonce: nonce) { credential in
            Task {
                do {
                    let result = try await Auth.auth().signIn(with: credential)
                    print("🟩 [SessionStore] Apple Sign In Success: \(result.user.uid)")
                } catch {
                    print("🟥 [SessionStore] Apple Firebase Auth failed: \(error)")
                }
            }
        }
        self.appleSignInControllerDelegate = delegate
        controller.delegate = delegate
        controller.performRequests()
    }
    
    // MARK: - Google Sign In
    
    func signInWithGoogle() async throws {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootViewController = windowScene.windows.first?.rootViewController else {
            return
        }
        
        let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: rootViewController)
        let user = result.user
        
        guard let idToken = user.idToken?.tokenString else {
            throw NSError(domain: "SessionStore", code: -1, userInfo: [NSLocalizedDescriptionKey: "No Google ID Token found."])
        }
        
        let credential = GoogleAuthProvider.credential(withIDToken: idToken,
                                                       accessToken: user.accessToken.tokenString)
        
        let authResult = try await Auth.auth().signIn(with: credential)
        print("🟩 [SessionStore] Google Sign In Success: \(authResult.user.uid)")
    }

    // MARK: - Account Linking
    
    func linkWithApple() async throws {
        let nonce = randomNonceString()
        currentNonce = nonce
        
        let appleIDProvider = ASAuthorizationAppleIDProvider()
        let request = appleIDProvider.createRequest()
        request.requestedScopes = [.fullName, .email]
        request.nonce = sha256(nonce)
        
        let controller = ASAuthorizationController(authorizationRequests: [request])
        let delegate = AppleSignInDelegate(nonce: nonce) { credential in
            Task {
                do {
                    guard let user = Auth.auth().currentUser else { return }
                    let result = try await user.link(with: credential)
                    print("🟩 [SessionStore] Apple Account Linked: \(result.user.uid)")
                } catch {
                    print("🟥 [SessionStore] Apple Account Linking failed: \(error)")
                }
            }
        }
        self.appleSignInControllerDelegate = delegate
        controller.delegate = delegate
        controller.performRequests()
    }
    
    func linkWithGoogle() async throws {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootViewController = windowScene.windows.first?.rootViewController else {
            return
        }
        
        let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: rootViewController)
        let googleUser = result.user
        
        guard let idToken = googleUser.idToken?.tokenString else {
            throw NSError(domain: "SessionStore", code: -1, userInfo: [NSLocalizedDescriptionKey: "No Google ID Token found."])
        }
        
        let credential = GoogleAuthProvider.credential(withIDToken: idToken,
                                                       accessToken: googleUser.accessToken.tokenString)
        
        guard let user = Auth.auth().currentUser else { return }
        let authResult = try await user.link(with: credential)
        print("🟩 [SessionStore] Google Account Linked: \(authResult.user.uid)")
    }
    
    // MARK: - Email Sign In (Passwordless)
    
    func sendSignInLink(to email: String) async throws {
        let actionCodeSettings = ActionCodeSettings()
        actionCodeSettings.url = URL(string: "https://stillme.page.link/login") // This should be configured in Firebase console
        actionCodeSettings.handleCodeInApp = true
        actionCodeSettings.setIOSBundleID(Bundle.main.bundleIdentifier!)
        
        try await Auth.auth().sendSignInLink(toEmail: email, actionCodeSettings: actionCodeSettings)
        
        // Save email locally to complete sign-in when link is clicked
        UserDefaults.standard.set(email, forKey: "pendingEmail")
        print("🟩 [SessionStore] Sign-in link sent to \(email)")
    }

    func handleSignInLink(_ url: URL) async throws -> Bool {
        let link = url.absoluteString
        if Auth.auth().isSignIn(withEmailLink: link) {
            guard let email = UserDefaults.standard.string(forKey: "pendingEmail") else {
                throw NSError(domain: "SessionStore", code: -1, userInfo: [NSLocalizedDescriptionKey: "No pending email found."])
            }
            
            if let user = Auth.auth().currentUser {
                // If user is already signed in (presumably anonymous), link the account
                let credential = EmailAuthProvider.credential(withEmail: email, link: link)
                try await user.link(with: credential)
                print("🟩 [SessionStore] Account linked with email link for \(email)")
            } else {
                // If no user is signed in, perform a normal sign-in
                try await Auth.auth().signIn(withEmail: email, link: link)
                print("🟩 [SessionStore] Signed in with email link for \(email)")
            }
            
            UserDefaults.standard.removeObject(forKey: "pendingEmail")
            return true
        }
        return false
    }

    // MARK: - Helpers
    
    internal func sha256(_ input: String) -> String {
        let inputData = Data(input.utf8)
        let hashedData = SHA256.hash(data: inputData)
        let hashString = hashedData.compactMap { String(format: "%02x", $0) }.joined()
        return hashString
    }

    internal func randomNonceString(length: Int = 32) -> String {
        precondition(length > 0)
        let charset: [Character] = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        var result = ""
        var remainingLength = length
        
        while remainingLength > 0 {
            let randoms: [UInt8] = (0..<16).map { _ in UInt8.random(in: 0...255) }
            randoms.forEach { random in
                if remainingLength == 0 { return }
                if random < charset.count {
                    result.append(charset[Int(random)])
                    remainingLength -= 1
                }
            }
        }
        return result
    }
}

// Helper Delegate for Apple Sign In
class AppleSignInDelegate: NSObject, ASAuthorizationControllerDelegate {
    private let nonce: String
    private let completion: (AuthCredential) -> Void
    
    init(nonce: String, completion: @escaping (AuthCredential) -> Void) {
        self.nonce = nonce
        self.completion = completion
    }
    
    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        if let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential {
            guard let appleIDToken = appleIDCredential.identityToken else { return }
            guard let idTokenString = String(data: appleIDToken, encoding: .utf8) else { return }
            
            let credential = OAuthProvider.appleCredential(withIDToken: idTokenString,
                                                      rawNonce: nonce,
                                                      fullName: appleIDCredential.fullName)
            completion(credential)
        }
    }
    
    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        print("🟥 [AppleSignIn] Error: \(error)")
    }
}


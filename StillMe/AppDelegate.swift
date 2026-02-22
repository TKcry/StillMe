import UIKit
import FirebaseCore
import GoogleSignIn

final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil
    ) -> Bool {
        FirebaseApp.configure()

        // Check if Firebase initialized correctly
        if let app = FirebaseApp.app() {
            print("[AppDelegate] StillMe Firebase configured name=\(app.name)")
        } else {
            print("[AppDelegate] StillMe Firebase NOT configured (plist missing or invalid)")
        }
        return true
    }
    
    // Phase 271: Handle URL for Google Sign-In and Email Link Auth
    func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey : Any] = [:]) -> Bool {
        if GIDSignIn.sharedInstance.handle(url) {
            return true
        }
        
        // Handle Email Link Auth
        Task {
            let sessionStore = SessionStore()
            _ = try? await sessionStore.handleSignInLink(url)
        }
        
        return true
    }
}

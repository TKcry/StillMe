import SwiftUI
import FirebaseAuth

struct OnboardingFlowView: View {
    @EnvironmentObject var viewModel: AppViewModel
    @StateObject private var draft = OnboardingDraft()
    @State private var path = NavigationPath()
    
    enum OnboardingStep: Hashable {
        case login
        case email
        case welcome
        case nickname
        case icon
        case handle
        case done
    }
    
    var body: some View {
        NavigationStack(path: $path) {
            OnboardingLoginView(onNext: {
                path.append(OnboardingStep.welcome)
            }, onEmailLogin: {
                path.append(OnboardingStep.email)
            })
            .navigationDestination(for: OnboardingStep.self) { step in
                switch step {
                case .login:
                    OnboardingLoginView(onNext: { path.append(OnboardingStep.welcome) }, onEmailLogin: { path.append(OnboardingStep.email) })
                case .email:
                    OnboardingEmailView(onNext: {
                        path.append(OnboardingStep.welcome)
                    })
                case .welcome:
                    OnboardingWelcomeView(onNext: { path.append(OnboardingStep.nickname) })
                case .nickname:
                    OnboardingNicknameView(onNext: {
                        path.append(OnboardingStep.icon)
                    })
                case .icon:
                    OnboardingIconView(onNext: {
                        path.append(OnboardingStep.handle)
                    }, onBack: {
                        path.removeLast()
                    })
                case .handle:
                    OnboardingHandleView(onNext: {
                        path.append(OnboardingStep.done)
                    }, onBack: {
                        path.removeLast()
                    })
                case .done:
                    OnboardingDoneView()
                }
            }
        }
        .environmentObject(viewModel)
        .environmentObject(draft)
        .onAppear {
            // FirebaseAuthで既にサインイン済みの場合は、ログイン画面を飛ばして「ようこそ」から開始
            if let user = Auth.auth().currentUser, !user.isAnonymous {
                if path.isEmpty {
                    path.append(OnboardingStep.welcome)
                }
            }
        }
    }
}

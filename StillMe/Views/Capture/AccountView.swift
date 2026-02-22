import SwiftUI
import FirebaseAuth

struct AccountView: View {
    @EnvironmentObject var store: PairStore
    @State private var handleInput: String = ""
    @State private var showingAlert: Bool = false
    @State private var alertMessage: String = ""
    @State private var isLoading: Bool = false

    @State private var nickname: String = ""
    @State private var isSavingNickname: Bool = false
    @State private var nicknameError: String? = nil

    var body: some View {
        NavigationStack {
            Form {
                Section("section_register_handle") {
                    HStack {
                        Text("@")
                        TextField("your_handle_placeholder", text: $handleInput)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled(true)
                    }
                    Button("button_register") {
                        isLoading = true
                        Task {
                            defer { isLoading = false }
                            let h = handleInput.trimmingCharacters(in: .whitespacesAndNewlines)
                            guard !h.isEmpty else {
                                isLoading = false
                                return
                            }
                            do {
                                try await store.registerHandle(h)
                                alertMessage = NSLocalizedString("handle_registered_success", comment: "")
                                showingAlert = true
                                handleInput = ""
                            } catch {
                                if let pe = error as? PairStore.PairError {
                                    alertMessage = message(for: pe)
                                } else {
                                    alertMessage = String(format: NSLocalizedString("auth_failed_format", comment: ""), error.localizedDescription)
                                }
                                showingAlert = true
                            }
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(handleInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isLoading)
                }

                Section("section_nickname") {
                    TextField("nickname_placeholder", text: $nickname)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled(true)
                    Button(action: {
                        guard !isSavingNickname else { return }
                        isSavingNickname = true
                        nicknameError = nil
                        Task {
                            do {
                                try await store.updateNickname(nickname)
                                nickname = ""
                            } catch {
                                nicknameError = error.localizedDescription
                            }
                            isSavingNickname = false
                        }
                    }) {
                        if isSavingNickname {
                            ProgressView()
                        } else {
                            Text("button_save")
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isSavingNickname || nickname.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                    if let nicknameError = nicknameError {
                        Text(nicknameError)
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }
                }

                Section("section_status") {
                    Text(String(format: NSLocalizedString("pair_status_label", comment: ""), store.profile.status.rawValue))
                    if let uid = store.authUid {
                        Text("uid: \(uid)").font(.caption).foregroundStyle(.secondary)
                    } else {
                        Text("uid: (nil)").font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("account_title")
            .alert(alertMessage, isPresented: $showingAlert) {
                Button("OK", role: .cancel) { }
            }
        }
        .onAppear { 
            store.startAuthListener()
        }
    }

    private func message(for error: PairStore.PairError) -> String {
        switch error {
        case .alreadyHasHandle: return "Handle is already registered"
        case .handleTaken: return "This handle is already taken"
        case .authUnavailable: return "Could not verify authentication state"
        default: return "Process failed (\(String(describing: error)))"
        }
    }
}

#Preview {
    AccountView()
        .environmentObject(PairStore.shared)
}

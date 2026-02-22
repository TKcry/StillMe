import SwiftUI
import FirebaseAuth

struct AddPairView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var viewModel: AppViewModel
    @EnvironmentObject var store: PairStore
    
    @State private var handleInput: String = ""
    @State private var searchResult: PairStore.UserSummary? = nil
    @State private var isSearching = false
    @State private var isSending = false
    @State private var errorMessage: String? = nil
    @State private var successMessage: String? = nil
    
    @State private var processingInvites: Set<String> = []
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.dsBackground.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: Spacing.xl) {
                        searchSection
                        searchResultSection
                        invitesSection
                    }
                    .padding(Spacing.xxl)
                }
            }
            .navigationTitle("add_pair_title")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.dsForeground)
                    }
                }
            }
            .alert("error_pair_limit_title", isPresented: Binding(
                get: { errorMessage?.contains("limit") ?? false },
                set: { _ in errorMessage = nil }
            )) {
                Button("ok_label") { }
                Button("button_view_subscription") {
                    // Subscription path logic here if any
                }
            } message: {
                Text("error_pair_limit_message")
            }
        }
    }
    
    // MARK: - Subviews
    
    @ViewBuilder
    private var searchSection: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Text("search_handle_title")
                .font(Typography.small.bold())
                .foregroundColor(.dsForeground)
                .padding(.leading, 4)
            
            HStack(spacing: Spacing.md) {
                HStack {
                    Text("@")
                        .foregroundColor(.dsMuted)
                    TextField("username_placeholder", text: $handleInput)
                        .keyboardType(.asciiCapable)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                        .submitLabel(.search)
                        .onSubmit {
                            searchUser()
                        }
                        .onChange(of: handleInput) { _, newValue in
                            let filtered = newValue.replacingOccurrences(of: "@", with: "")
                                .lowercased()
                                .filter { "abcdefghijklmnopqrstuvwxyz0123456789_".contains($0) }
                                .prefix(20)
                            
                            if String(filtered) != newValue {
                                handleInput = String(filtered)
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            }
                        }
                }
                .font(Typography.bodyMedium)
                .padding()
                .background(Color.white.opacity(0.05))
                .cornerRadius(12)
                
                Button {
                    searchUser()
                } label: {
                    Group {
                        if isSearching {
                            ProgressView()
                                .tint(.dsForeground)
                        } else {
                            Text("button_search")
                                .font(Typography.small.bold())
                        }
                    }
                    .padding(.horizontal, 20)
                    .frame(height: 52)
                    .background(handleInput.isEmpty || isSearching ? Color.white.opacity(0.1) : Color.white)
                    .foregroundColor(handleInput.isEmpty || isSearching ? .dsMuted : .black)
                    .cornerRadius(12)
                    .contentShape(Rectangle())
                }
                .disabled(handleInput.isEmpty || isSearching)
            }
        }
    }
    
    @ViewBuilder
    private var searchResultSection: some View {
        if let user = searchResult {
            VStack(spacing: Spacing.lg) {
                AppCard(padding: Spacing.xl) {
                    VStack(spacing: Spacing.lg) {
                        // User Info
                        VStack(spacing: Spacing.md) {
                            ZStack {
                                if let avatarPath = user.avatarPath {
                                    CloudImageView(
                                        path: avatarPath,
                                        showSpinner: true,
                                        version: user.avatarUpdatedAt?.description
                                    )
                                    .frame(width: 80, height: 80)
                                    .clipShape(Circle())
                                } else {
                                    Circle()
                                        .fill(Color.white.opacity(0.1))
                                        .frame(width: 80, height: 80)
                                    
                                    Image(systemName: "person.fill")
                                        .font(.system(size: 32))
                                        .foregroundColor(.dsMutedDeep)
                                }
                            }
                            
                            VStack(spacing: 4) {
                                Text(user.nickname)
                                    .font(Typography.h2)
                                    .foregroundColor(.dsForeground)
                                
                                Text("@\(user.handle)")
                                    .font(Typography.small)
                                    .foregroundColor(.dsMuted)
                                
                                if store.pairRefs.contains(where: { $0.partnerUid == user.id }) {
                                    Text("status_paired") // Assuming this key or similar
                                        .font(Typography.extraSmall.bold())
                                        .foregroundColor(.green.opacity(0.8))
                                        .padding(.top, 2)
                                } else if store.outbox.contains(where: { $0.toUid == user.id }) {
                                    Text("status_invited")
                                        .font(Typography.extraSmall.bold())
                                        .foregroundColor(.dsMutedDeep)
                                        .padding(.top, 2)
                                }
                            }
                        }
                        
                        // Send Invite Button
                        let isSelf = user.id == Auth.auth().currentUser?.uid
                        let isPaired = store.pairRefs.contains(where: { $0.partnerUid == user.id })
                        Button {
                            sendInvite(to: user.id)
                        } label: {
                            Group {
                                if isSending {
                                    ProgressView().tint(.black)
                                } else {
                                    Text(isSelf ? "this_is_you" : (isPaired ? "status_paired" : "button_send_invite"))
                                        .font(Typography.bodyMedium.bold())
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 52)
                            .background((isSelf || isPaired) ? Color.white.opacity(0.1) : Color.white)
                            .foregroundColor((isSelf || isPaired) ? .dsMuted : .black)
                            .cornerRadius(12)
                            .contentShape(Rectangle())
                        }
                        .disabled(isSending || isSelf || isPaired)
                    }
                }
            }
            .transition(.move(edge: .top).combined(with: .opacity))
        } 
        
        if let error = errorMessage, !handleInput.isEmpty {
            VStack(spacing: 8) {
                Text(error)
                    .font(Typography.bodyMedium)
                    .foregroundColor(.dsForeground)
                
                if error == NSLocalizedString("error_no_user_found", comment: "") {
                    Text("error_check_handle_hint")
                        .font(Typography.extraSmall)
                        .foregroundColor(.dsMuted)
                }
            }
            .padding(.top, 20)
        }
        
        if let success = successMessage {
            Text(success)
                .font(Typography.small)
                .foregroundColor(.green.opacity(0.8))
                .padding(.top, 12)
        }
    }
    
    @ViewBuilder
    private var invitesSection: some View {
        if !store.inbox.isEmpty {
            VStack(alignment: .leading, spacing: Spacing.md) {
                Text("invites_section_title")
                    .font(Typography.small.bold())
                    .foregroundColor(.dsForeground)
                    .padding(.leading, 4)
                    .padding(.top, 20)
                
                VStack(spacing: Spacing.md) {
                    let sorted = store.inbox.sorted { ($0.createdAt ?? .distantPast) > ($1.createdAt ?? .distantPast) }
                    ForEach(sorted) { inv in
                        ReceivedInviteRow(invite: inv, processingIds: $processingInvites) { inviteId in
                            acceptInvite(inviteId)
                        } onDecline: { inviteId in
                            declineInvite(inviteId)
                        }
                    }
                }
            }
        }
    }
    
    private func searchUser() {
        errorMessage = nil
        searchResult = nil
        successMessage = nil
        store.resetSearchPaging() // Reset previous search photos
        
        guard !handleInput.isEmpty else { return }
        
        isSearching = true
        Task {
            do {
                let startTime = Date()
                let user = try await store.searchUser(byHandle: handleInput)
                let elapsed = Int(Date().timeIntervalSince(startTime) * 1000)
                print("[PERF][Search] Metadata fetched in \(elapsed)ms")
                
                await MainActor.run {
                    self.searchResult = user
                    self.isSearching = false
                }
                
                // Prefetch Avatar only
                if let path = user.avatarPath {
                    Task {
                        await viewModel.ensureAvatarCached(uid: user.id, path: path, updatedAt: user.avatarUpdatedAt)
                    }
                }
            } catch let error as PairStore.PairError {
                await MainActor.run {
                    self.isSearching = false
                    if error == .handleNotFound {
                        self.errorMessage = NSLocalizedString("error_no_user_found", comment: "")
                    } else if error == .forbidden {
                        self.errorMessage = NSLocalizedString("error_invite_self", comment: "")
                    } else {
                        self.errorMessage = NSLocalizedString("error_generic", comment: "")
                    }
                }
            } catch {
                await MainActor.run {
                    self.isSearching = false
                    self.errorMessage = error.localizedDescription
                }
            }
        }
    }
    
    private func sendInvite(to uid: String) {
        successMessage = nil
        errorMessage = nil
        isSending = true
        
        Task {
            print("[AddPairView][sendInvite] START for uid=\(uid)")
            do {
                try await store.sendInvite(toUid: uid)
                print("[AddPairView][sendInvite] store.sendInvite FINISHED successfully")
                await MainActor.run {
                    print("[AddPairView][sendInvite] Updating UI for SUCCESS")
                    self.isSending = false
                    self.successMessage = NSLocalizedString("success_invite_sent", comment: "")
                    self.searchResult = nil
                    self.handleInput = ""
                }
            } catch let error as PairStore.PairError {
                print("[AddPairView][sendInvite] CAUGHT PairError: \(error)")
                await MainActor.run {
                    self.isSending = false
                    if error == .alreadyHasInvite {
                        self.errorMessage = NSLocalizedString("error_invite_already_sent", comment: "")
                    } else if error == .alreadyPaired {
                        self.errorMessage = NSLocalizedString("error_already_paired", comment: "")
                    } else if error == .maxPairsReached {
                        self.errorMessage = NSLocalizedString("error_pair_limit_reached", comment: "")
                    } else {
                        self.errorMessage = NSLocalizedString("error_failed_send_invite", comment: "")
                    }
                }
            } catch {
                print("[AddPairView][sendInvite] CAUGHT Unknown Error: \(error.localizedDescription)")
                await MainActor.run {
                    self.isSending = false
                    self.errorMessage = error.localizedDescription
                    // Do NOT clear searchResult if it's just a regular error (like auth) 
                    // unless it's a specific logic error.
                }
            }
        }
    }
    
    private func acceptInvite(_ inviteId: String) {
        processingInvites.insert(inviteId)
        Task {
            do {
                try await store.acceptInvite(inviteId)
                _ = await MainActor.run {
                    processingInvites.remove(inviteId)
                }
            } catch let error as NSError where error.code == 422 {
                await MainActor.run {
                    processingInvites.remove(inviteId)
                    self.errorMessage = NSLocalizedString("error_pair_limit_reached", comment: "")
                }
            } catch {
                await MainActor.run {
                    processingInvites.remove(inviteId)
                    self.errorMessage = error.localizedDescription
                }
            }
        }
    }
    
    private func declineInvite(_ inviteId: String) {
        processingInvites.insert(inviteId)
        Task {
            try? await store.declineInvite(inviteId)
            _ = await MainActor.run {
                processingInvites.remove(inviteId)
            }
        }
    }
}

struct ReceivedInviteRow: View {
    @EnvironmentObject var store: PairStore
    @EnvironmentObject var viewModel: AppViewModel
    let invite: PairStore.InviteItem
    @Binding var processingIds: Set<String>
    let onAccept: (String) -> Void
    let onDecline: (String) -> Void
    
    @State private var inviterProfile: PairStore.PartnerProfileInfo? = nil
    
    var body: some View {
        AppCard(padding: Spacing.lg) {
            HStack(spacing: Spacing.md) {
                // Inviter Avatar
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.1))
                        .frame(width: 44, height: 44)
                    
                    if let profile = inviterProfile,
                       let image = viewModel.loadAvatar(uid: invite.fromUid, updatedAt: profile.avatarUpdatedAt) {
                        Image(uiImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 44, height: 44)
                            .clipShape(Circle())
                    } else {
                        Image(systemName: "person.fill")
                            .foregroundColor(.dsMutedDeep)
                            .font(.system(size: 18))
                    }
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    if let profile = inviterProfile {
                        Text(profile.name)
                            .font(Typography.small.bold())
                            .foregroundColor(.dsForeground)
                        
                        Text("@\(profile.handle)")
                            .font(Typography.extraSmall)
                            .foregroundColor(.dsMuted)
                    } else {
                        Text(String(format: NSLocalizedString("invite_from_format", comment: ""), String(invite.fromUid.prefix(6))))
                            .font(Typography.small.bold())
                            .foregroundColor(.dsForeground)
                    }
                    
                    if let date = invite.createdAt {
                        Text(date, style: .date)
                            .font(Typography.extraSmall)
                            .foregroundColor(.dsMuted.opacity(0.6))
                    }
                }
                
                Spacer()
                
                HStack(spacing: 8) {
                    Button {
                        onDecline(invite.id)
                    } label: {
                        Text("button_decline")
                            .font(Typography.extraSmall.bold())
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Color.white.opacity(0.1))
                            .foregroundColor(.dsForeground)
                            .cornerRadius(8)
                            .contentShape(Rectangle())
                    }
                    .disabled(processingIds.contains(invite.id))
                    
                    Button {
                        onAccept(invite.id)
                    } label: {
                        Group {
                            if processingIds.contains(invite.id) {
                                ProgressView().tint(.black)
                            } else {
                                Text("button_accept")
                                    .font(Typography.extraSmall.bold())
                            }
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.white)
                        .foregroundColor(.black)
                        .cornerRadius(8)
                        .contentShape(Rectangle())
                    }
                    .disabled(processingIds.contains(invite.id))
                }
            }
        }
        .task {
            inviterProfile = try? await store.getPartnerProfile(uid: invite.fromUid)
        }
    }
}

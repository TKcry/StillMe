import SwiftUI

struct BlockedUsersView: View {
    @EnvironmentObject var appViewModel: AppViewModel
    @EnvironmentObject var store: PairStore
    @State private var blockedProfiles: [String: PairStore.PartnerProfileInfo] = [:] // uid: PartnerProfileInfo
    
    var body: some View {
        ZStack {
            Color.dsBackground.ignoresSafeArea()
            
            if store.blockedUids.isEmpty {
                VStack {
                    Text("no_blocked_users")
                        .font(Typography.bodyMedium)
                        .foregroundColor(.dsMuted)
                }
            } else {
                ScrollView {
                    VStack(spacing: Spacing.md) {
                        ForEach(store.blockedUids, id: \.self) { uid in
                            AppCard(padding: 16, cornerRadius: Radius.lg) {
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        if let profile = blockedProfiles[uid] {
                                            Text(profile.name)
                                                .font(Typography.bodyBold)
                                                .foregroundColor(.dsForeground)
                                            Text("@\(profile.handle)")
                                                .font(Typography.extraSmall)
                                                .foregroundColor(.dsMuted)
                                        } else {
                                            Text("Loading...")
                                                .font(Typography.bodyBold)
                                                .foregroundColor(.dsForeground)
                                            Text(uid.prefix(8) + "...")
                                                .font(Typography.extraSmall)
                                                .foregroundColor(.dsMuted)
                                        }
                                    }
                                    
                                    Spacer()
                                    
                                    Button(action: {
                                        Task {
                                            do {
                                                try await appViewModel.pairStore.unblockUser(uid: uid)
                                                // No need to manually refresh, blockedUids is @Published
                                            } catch {
                                                print("Failed to unblock: \(error)")
                                            }
                                        }
                                    }) {
                                        Text("unblock")
                                            .font(Typography.small.bold())
                                            .foregroundColor(.white)
                                            .padding(.horizontal, 16)
                                            .padding(.vertical, 8)
                                            .background(Color.white.opacity(0.1))
                                            .cornerRadius(Radius.md)
                                    }
                                }
                            }
                        }
                    }
                    .padding(24)
                }
            }
        }
        .navigationTitle("account_privacy_blocked_users")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            loadProfiles()
        }
        .onChange(of: store.blockedUids) { _ in
            loadProfiles()
        }
    }
    
    private func loadProfiles() {
        for uid in store.blockedUids {
            if blockedProfiles[uid] != nil { continue }
            Task {
                if let profile = try? await store.getPartnerProfile(uid: uid) {
                    await MainActor.run {
                        blockedProfiles[uid] = profile
                    }
                }
            }
        }
    }
}

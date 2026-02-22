import SwiftUI

struct HiddenPairsView: View {
    @EnvironmentObject var appViewModel: AppViewModel
    @EnvironmentObject var store: PairStore
    
    var body: some View {
        ZStack {
            Color.dsBackground.ignoresSafeArea()
            
            let hiddenPairs = appViewModel.pairs.filter { store.hiddenPairIds.contains($0.id) }
            
            if hiddenPairs.isEmpty {
                VStack {
                    Text("no_hidden_pairs")
                        .font(Typography.bodyMedium)
                        .foregroundColor(.dsMuted)
                }
            } else {
                ScrollView {
                    VStack(spacing: Spacing.md) {
                        ForEach(hiddenPairs) { pair in
                            AppCard(padding: 16, cornerRadius: Radius.lg) {
                                HStack(spacing: Spacing.md) {
                                    // Avatar
                                    ZStack {
                                        Circle()
                                            .fill(Color.white.opacity(0.1))
                                            .frame(width: 40, height: 40)
                                        
                                        if let image = appViewModel.loadAvatar(uid: pair.partnerUid, updatedAt: pair.avatarUpdatedAt) {
                                            Image(uiImage: image)
                                                .resizable()
                                                .aspectRatio(contentMode: .fill)
                                                .frame(width: 40, height: 40)
                                                .clipShape(Circle())
                                        } else {
                                            Image(systemName: "person.fill")
                                                .foregroundColor(.dsMutedDeep)
                                        }
                                    }
                                    
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(pair.name)
                                            .font(Typography.bodyBold)
                                            .foregroundColor(.dsForeground)
                                        
                                        if let handle = pair.partnerHandle {
                                            Text("@\(handle)")
                                                .font(Typography.extraSmall)
                                                .foregroundColor(.dsMuted)
                                        }
                                    }
                                    
                                    Spacer()
                                    
                                    Button(action: {
                                        Task {
                                            try? await appViewModel.pairStore.unhidePair(pairId: pair.id)
                                        }
                                    }) {
                                        Text("unhide")
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
        .navigationTitle("account_privacy_hidden_pairs")
        .navigationBarTitleDisplayMode(.inline)
    }
}

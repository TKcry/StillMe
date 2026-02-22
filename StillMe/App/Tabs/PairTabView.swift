import SwiftUI

struct PairTabView: View {
    @EnvironmentObject var viewModel: AppViewModel
    @EnvironmentObject var store: PairStore
    @State private var showingAddPair = false
    @State private var pairToRemove: PairEntry? = nil
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Pairs List
                ScrollView {
                    VStack(spacing: Spacing.md) {
                        if viewModel.pairs.isEmpty {
                            VStack(spacing: Spacing.lg) {
                                Text("no_pair_joined")
                                    .font(Typography.small)
                                    .foregroundColor(.white)
                                
                                AppButton("add_pair", icon: "plus") {
                                    showingAddPair = true
                                }
                            }
                            .padding(.vertical, 60)
                        } else {
                            // Status text moved inside scroll
                            Text(String(format: NSLocalizedString("pair_count_connected", comment: ""), viewModel.pairs.count))
                                .font(Typography.extraSmall)
                                .foregroundColor(.dsMutedDeep)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, Spacing.lg)
                                .padding(.top, Spacing.md)
                            
                            ForEach(viewModel.pairs.filter { !store.hiddenPairIds.contains($0.id) && !store.blockedUids.contains($0.partnerUid) }) { pair in
                                SwipeablePairRow(pair: pair) {
                                    pairToRemove = pair
                                }
                            }
                        }
                    }
                    .padding(.bottom, 100)
                }
            }
            .navigationTitle(NSLocalizedString("pair_tab_title", comment: ""))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showingAddPair = true
                    } label: {
                        ZStack(alignment: .topTrailing) {
                            Image(systemName: "plus")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.white)
                            
                            if viewModel.pendingInviteCount > 0 {
                                Circle()
                                    .fill(Color.dsError)
                                    .frame(width: 8, height: 8)
                                    .offset(x: 2, y: -2)
                            }
                        }
                    }
                }
            }
            .background(Color.dsBackground.ignoresSafeArea())
            .sheet(isPresented: $showingAddPair) {
                AddPairView()
                    .environmentObject(viewModel)
                    .environmentObject(viewModel.pairStore)
            }
            .alert("remove_pair_alert_title", isPresented: Binding(
                get: { pairToRemove != nil },
                set: { if !$0 { pairToRemove = nil } }
            )) {
                Button("cancel", role: .cancel) { }
                Button("remove", role: .destructive) {
                    if let pair = pairToRemove {
                        Task {
                            do {
                                try await viewModel.pairStore.unpair(pairId: pair.id)
                                viewModel.pairStore.postNotice(String(format: NSLocalizedString("remove_pair_success", comment: ""), pair.name))
                            } catch {
                                viewModel.pairStore.postNotice(NSLocalizedString("remove_pair_failed", comment: ""))
                            }
                        }
                    }
                }
            } message: {
                if let pair = pairToRemove {
                    Text(String(format: NSLocalizedString("remove_pair_alert_message", comment: ""), pair.partnerHandle ?? ""))
                }
            }
        }
    }
}

struct PairRow: View {
    @EnvironmentObject var viewModel: AppViewModel
    let pair: PairEntry
    
    var body: some View {
        AppCard(padding: Spacing.lg, cornerRadius: 0, backgroundColor: .dsCard) {
            HStack(spacing: Spacing.lg) {
                // Avatar
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.1))
                        .frame(width: 56, height: 56)
                    
                    if let image = viewModel.loadAvatar(uid: pair.partnerUid, updatedAt: pair.avatarUpdatedAt) {
                        Image(uiImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 56, height: 56)
                            .clipShape(Circle())
                    } else {
                        Image(systemName: "person.fill")
                            .foregroundColor(.dsMutedDeep)
                    }
                }
                
                // Info
                VStack(alignment: .leading, spacing: 2) {
                    HStack(alignment: .center, spacing: 6) {
                        Text(pair.name)
                            .font(Typography.bodyBold)
                            .foregroundColor(.white)
                    }
                    
                    if let handle = pair.partnerHandle, !handle.isEmpty {
                        Text("@\(handle)")
                            .font(Typography.extraSmall)
                            .foregroundColor(.dsMutedDeep)
                    }
                }
                
                Spacer()
                
                // Summary/Status indicator instead of just a chevron
                Image(systemName: "chart.bar.fill")
                    .font(.system(size: 14))
                    .foregroundColor(.blue.opacity(0.6))
            }
        }
    }
}

struct SwipeablePairRow: View {
    let pair: PairEntry
    let onRemove: () -> Void
    
    @State private var offset: CGFloat = 0
    @State private var isSwiped = false
    @State private var cardHeight: CGFloat = 0
    
    private let removeWidth: CGFloat = 90
    
    var body: some View {
        ZStack(alignment: .trailing) {
            if offset < 0 {
                Button {
                    withAnimation { offset = 0 }
                    onRemove()
                } label: {
                    ZStack {
                        Rectangle()
                            .fill(Color(hex: "FF3B30"))
                        
                        VStack(spacing: 4) {
                            Image(systemName: "person.badge.minus")
                                .font(.system(size: 20))
                            Text(NSLocalizedString("remove", comment: ""))
                                .font(.system(size: 10, weight: .bold))
                        }
                        .foregroundColor(.white)
                    }
                }
                .frame(width: abs(offset), height: cardHeight)
            }
            
            NavigationLink(destination: PairDetailView(pairId: pair.id)) {
                PairRow(pair: pair)
                    .overlay(
                        GeometryReader { geo in
                            Color.clear
                                .onAppear {
                                    self.cardHeight = geo.size.height
                                }
                                .onChange(of: geo.size) { newSize in
                                    self.cardHeight = newSize.height
                                }
                        }
                    )
                    .contentShape(Rectangle())
            }
            .buttonStyle(PlainButtonStyle())
            .offset(x: offset)
            .simultaneousGesture(
                DragGesture(minimumDistance: 10)
                    .onChanged { value in
                        if value.translation.width < 0 {
                            offset = value.translation.width
                        }
                    }
                    .onEnded { value in
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            if value.translation.width < -removeWidth {
                                offset = -removeWidth
                                isSwiped = true
                            } else {
                                offset = 0
                                isSwiped = false
                            }
                        }
                    }
            )
        }
    }
}

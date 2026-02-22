import SwiftUI
import AVFoundation

struct TodayView: View {
    @EnvironmentObject var viewModel: AppViewModel
    @State private var isFlipped = false
    @State private var momentRefresher = UUID() // Trigger to re-check moment file existence
    @Environment(\.scenePhase) var scenePhase
    
    // Inline Camera State
    @ObservedObject private var camera = CameraService.shared
    
    var body: some View {
        ZStack {
            Color.dsBackground.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // 1. Title Area
                headerView
                
                Spacer(minLength: 20) // Flexible top spacing
                
                // 2. Control Area (Mode Switcher or Partner Info) - Fixed Height to prevent jump
                Group {
                    if let pairId = viewModel.targetedPairId {
                        partnerHeader(pairId: pairId)
                    } else {
                        modeSelectorView
                    }
                }
                .frame(height: 44, alignment: .center)
                .padding(.bottom, 12)
                
                // 3. Main Content Area - Fixed Height based on Card Aspect Ratio
                ZStack {
                    if viewModel.todayViewCategory == .publicMode {
                        publicContentView
                            .transition(.asymmetric(insertion: .move(edge: .leading), removal: .move(edge: .leading)))
                    } else {
                        pairsContentView
                            .transition(.asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .trailing)))
                    }
                }
                .frame(maxWidth: 500) // Phase 280: Limit content width for iPad
                .frame(height: cardHeight) // Phase 280: Explicitly fix height to prevent bar jump
                .frame(maxWidth: .infinity) // Center the limited width container
                .animation(.spring(response: 0.4, dampingFraction: 0.85), value: viewModel.todayViewCategory)
                
                Spacer(minLength: 20) // Flexible bottom spacing
                
                // 4. Shutter / Bottom Area
                bottomAreaView
            }
        }
        .ignoresSafeArea(.keyboard)
        .onAppear {
            setupCameraCallbacks()
        }
    }

    // MARK: - Header & Mode Selector
    
    private var headerView: some View {
        VStack(spacing: 4) {
            Text("StillMe")
                .font(.system(size: 22, weight: .black))
                .foregroundColor(.white)
                .tracking(1.2)
                .padding(.top, 4)
        }
        .padding(.bottom, 4)
    }

    private var modeSelectorView: some View {
        HStack(spacing: 0) {
            modeButton(title: "みんなに公開", mode: .publicMode)
            modeButton(title: "フレンド別", mode: .targetedMode)
        }
        .background(Capsule().fill(Color.white.opacity(0.1)))
        .padding(.horizontal, 64)
    }
    
    private func modeButton(title: String, mode: TodayViewCategory) -> some View {
        let isSelected = viewModel.todayViewCategory == mode
        return Button(action: {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                viewModel.todayViewCategory = mode
                // Reset state when switching modes
                if mode == .publicMode {
                    viewModel.targetedPairId = nil
                }
                
                if viewModel.todayMode != .idle {
                    viewModel.todayMode = .idle
                    camera.stopAndTeardown(source: "ModeSwitch")
                }
                isFlipped = false
            }
        }) {
            Text(title)
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(isSelected ? .black : .white.opacity(0.6))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill(isSelected ? Color.white : Color.clear)
                )
        }
    }

    // MARK: - Public Mode Content
    
    private var publicContentView: some View {
        TodayFlipCardView(
            isFlipped: $isFlipped,
            type: .publicPhoto,
            mode: viewModel.todayMode,
            camera: camera,
            capturedImage: viewModel.capturedImage,
            momentRefresher: momentRefresher
        )
        .padding(.horizontal, 24)
        .onAppear {
        }
    }

    // MARK: - Pairs Mode Content
    
    private var pairsContentView: some View {
        ZStack {
            if let pairId = viewModel.targetedPairId {
                // Partner Specific Card View
                TodayFlipCardView(
                    isFlipped: $isFlipped,
                    type: .targeted(pairId: pairId),
                    mode: viewModel.todayMode,
                    camera: camera,
                    capturedImage: viewModel.capturedImage,
                    momentRefresher: momentRefresher
                )
                .padding(.horizontal, 24)
                .transition(.opacity.combined(with: .move(edge: .bottom)))
            } else {
                // Partner Selection Grid
                partnerGridView
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: viewModel.targetedPairId)
    }
    
    private func partnerHeader(pairId: String) -> some View {
        let pair = viewModel.pairs.first(where: { $0.id == pairId })
        return HStack {
            Button(action: {
                withAnimation {
                    viewModel.targetedPairId = nil
                    isFlipped = false
                    if viewModel.todayMode != .idle {
                        viewModel.todayMode = .idle
                        camera.stopAndTeardown(source: "PairsBack")
                    }
                }
            }) {
                HStack(spacing: 2) {
                    Image(systemName: "chevron.left")
                    Text("戻る")
                }
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(.white.opacity(0.6))
            }
            
            Spacer()
            
            Text(pair?.name ?? "パートナー")
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(.white)
            
            Spacer()
            
            // Empty placeholder for balance
            Text("戻る")
                .font(.system(size: 13))
                .foregroundColor(.clear)
        }
        .padding(.horizontal, 32) // Slightly more padding to avoid edges
        .frame(height: 32) // Fixed height to prevent jitter
    }
    
    private var partnerGridView: some View {
        VStack(spacing: 16) {
            Text("誰に共有しますか？")
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(.white.opacity(0.5))
                .padding(.top, 20)
            
            ScrollView {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 20) {
                    ForEach(viewModel.pairs) { pair in
                        partnerGridItem(pair: pair)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 10)
            }
        }
    }
    
    private func partnerGridItem(pair: PairEntry) -> some View {
        Button(action: {
            withAnimation {
                viewModel.targetedPairId = pair.id
            }
        }) {
            VStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.05))
                        .frame(width: 80, height: 80)
                    
                    if let image = viewModel.loadAvatar(uid: pair.partnerUid, updatedAt: pair.avatarUpdatedAt) {
                        Image(uiImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 80, height: 80)
                            .clipShape(Circle())
                    } else {
                        Image(systemName: "person.fill")
                            .font(.system(size: 32))
                            .foregroundColor(.white.opacity(0.2))
                    }
                }
                .overlay(Circle().stroke(Color.white.opacity(0.1), lineWidth: 1))
                
                Text(pair.name)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(.white)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.white.opacity(0.03))
                    .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.white.opacity(0.05), lineWidth: 1))
            )
        }
    }

    // MARK: - Components
    
    private var bottomAreaView: some View {
        VStack(spacing: 0) {
            // Phase 280: Increased height to ensure shutter clearance
            // We use 84 for idle and up to 120 for camera mode to push card up
            Spacer().frame(height: viewModel.todayMode == .idle ? 84 : 120)
        }
        .padding(.bottom, 16)
    }

    // MARK: - Camera Logic
    
    private func setupCameraCallbacks() {
        camera.onMomentCaptured = { url, context in
            var meta: [String: Any] = [
                "sessionInstanceId": context.sessionInstanceId.uuidString,
                "framesSinceSessionStart": camera.framesSinceSessionStart,
                "freshnessAgeMs": camera.lastFrameTimestamp.timeIntervalSinceNow * -1000,
                "cameraPosition": context.position == .front ? "front" : "back",
                "captureId": context.activeCaptureId
            ]
            
            // Phase 284: Ensure targeted info is bundled if active
            if let tId = viewModel.targetedPairId {
                meta["targetedPairId"] = tId
            }
            
            viewModel.saveMoment(url: url, date: context.date, metadata: meta)
            momentRefresher = UUID()
        }
    }

    // MARK: - Helpers
    
    private var cardHeight: CGFloat {
        let screenWidth = UIScreen.main.bounds.width
        let availableWidth = min(screenWidth - 48, 480) // Limit to a reasonable width (iPhone Max size-ish)
        // Card is defined as .aspectRatio(0.75, contentMode: .fit)
        // Ratio 0.75 means Height = Width / 0.75
        return availableWidth / 0.75
    }
}

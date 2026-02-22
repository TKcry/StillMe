import SwiftUI
import UserNotifications

struct RootView: View {
    @StateObject private var viewModel = AppViewModel()
    
    // ✅ 各タブ의 NavigationStack をリセットするための ID 管理
    @State private var tabResetIDs: [TabType: UUID] = [
        .today: UUID(), .home: UUID(), .gallery: UUID(), .pair: UUID(), .account: UUID()
    ]
    
    var body: some View {
        ZStack {
            // ✅ 全画面背景 (Unified Deep Charcoal Gradient)
            ZStack {
                Color.dsBackground
                
                LinearGradient(
                    colors: [
                        Color.dsBackground.opacity(0.8),
                        Color.dsBackgroundOuter
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
            .ignoresSafeArea()
            
            // ✅ ZStack(alignment: .bottom) によりタブバーを下端に固定
            ZStack(alignment: .bottom) {
                VStack(spacing: 0) {
                    // Content Area
                    Group {
                        switch viewModel.activeTab {
                        case .today:
                            TodayTabView()
                                .id(tabResetIDs[.today])
                        case .home:
                            HomeTabView()
                                .id(tabResetIDs[.home])
                        case .gallery:
                            GalleryTabView()
                                .id(tabResetIDs[.gallery])
                        case .pair:
                            PairTabView()
                                .id(tabResetIDs[.pair])
                        case .account:
                            AccountTabView()
                                .id(tabResetIDs[.account])
                        default:
                            EmptyView()
                        }
                    }
                    .environmentObject(viewModel)
                    .environmentObject(viewModel.pairStore)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .transition(.asymmetric(insertion: .opacity, removal: .identity)) // Phase 250: Animate in, instant out
                    
                    // 下部の余白（タブバーと重ならないように確保）
                    Spacer(minLength: 54)
                }
                
                if viewModel.activeTab == .today && viewModel.todayMode == .idle && !viewModel.isCurrentTargetCaptured {
                    CaptureNudgeView()
                        .environmentObject(viewModel)
                        .padding(.bottom, 84) // Keep nudge at reasonable height
                        .allowsHitTesting(false) // Phase 280: Let taps pass through to card or tab bar
                }
                
                // Bottom Tab Navigation
                CustomTabBar(
                    activeTab: $viewModel.activeTab,
                    pendingInviteCount: viewModel.pendingInviteCount,
                    isCurrentTargetCaptured: viewModel.isCurrentTargetCaptured,
                    todayMode: viewModel.todayMode
                ) { tappedTab in
                    // Only reset/top-scroll if tapping the tab we are ALREADY on (Phase 243)
                    if tappedTab == viewModel.activeTab {
                        tabResetIDs[tappedTab] = UUID()
                    }
                    viewModel.handleTabTap(tappedTab, isExplicitTap: true)
                }
                .environmentObject(viewModel)
            }
            .ignoresSafeArea(.keyboard, edges: .bottom)
            .fullScreenCover(isPresented: Binding(
                get: { !viewModel.hasCompletedOnboarding || viewModel.showForceOnboarding },
                set: { _ in } 
            )) {
                OnboardingFlowView()
                    .environmentObject(viewModel)
            }
        }
        .preferredColorScheme(.dark)
        .onChange(of: viewModel.hasCompletedOnboarding) { _, newValue in
            if newValue && !viewModel.didAskNotificationPermission {
                requestNotificationPermission()
            }
            if !newValue {
                // Phase 270: Reset all navigation stacks on sign-out
                print("[RootView] Sign-out detected. Resetting all tab navigation IDs.")
                for tab in TabType.allCases {
                    tabResetIDs[tab] = UUID()
                }
            }
        }
        .onAppear {
            if viewModel.hasCompletedOnboarding && !viewModel.didAskNotificationPermission {
                requestNotificationPermission()
            }
            viewModel.onRootViewAppear()
        }
    }
    
    private func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            print("[Notifications] Permission granted=\(granted) error=\(String(describing: error))")
            DispatchQueue.main.async {
                viewModel.didAskNotificationPermission = true
            }
        }
    }
}

// MARK: - Subviews

struct StatusBarSpacer: View {
    var body: some View {
        HStack {
            Spacer()
            // Dynamic Island-ish / Spacer Capsule
            Capsule()
                .fill(Color.white.opacity(0.2))
                .frame(width: 128, height: 4)
            Spacer()
        }
        .frame(height: 48)
        .background(Color.dsBackground.ignoresSafeArea())
    }
}

struct CustomTabBar: View {
    @EnvironmentObject var viewModel: AppViewModel
    @Binding var activeTab: TabType
    let pendingInviteCount: Int
    let isCurrentTargetCaptured: Bool
    let todayMode: TodayCardMode
    var onTap: (TabType) -> Void
    
    var body: some View {
        ZStack(alignment: .bottom) {
            // Background bar (Only at the bottom)
            VStack(spacing: 0) {
                Divider()
                    .background(Color.dsSeparator)
                Color.dsBackground
                    .frame(height: 54)
                    .background(Color.dsBackground.ignoresSafeArea())
            }
            
            // Buttons - Tall container to allow offset shutter taps
            HStack(alignment: .bottom, spacing: 0) {
                let screenWidth = UIScreen.main.bounds.width
                let tabCount = CGFloat(TabType.visibleTabs.count)
                let tabWidth = min(screenWidth / tabCount, 120) // Phase 280: Limit tab width for iPad
                
                ForEach(TabType.visibleTabs, id: \.self) { tab in
                    let badge = (tab == .pair) ? pendingInviteCount : 0
                    TabItemView(
                        tab: tab,
                        activeTab: activeTab,
                        width: tabWidth,
                        badgeCount: badge,
                        isCurrentTargetCaptured: isCurrentTargetCaptured,
                        todayMode: todayMode,
                        onTap: onTap
                    )
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 200, alignment: .bottom)
            
            // Phase 246: Global Accessory Layer (Flip / Retake)
            // Positioned above ALL tabs to ensure hit-testing isn't stolen by narrow tab bounds
            let isShutter = activeTab == .today && todayMode == .camera && !isCurrentTargetCaptured
            let isRetake = activeTab == .today && todayMode == .preview && !isCurrentTargetCaptured
            
            if isShutter || isRetake {
                Button {
                    if isShutter {
                        viewModel.switchCamera()
                    } else {
                        viewModel.retakePhoto()
                    }
                } label: {
                    ZStack {
                        Circle()
                            .fill(isRetake ? Color(hex: "8E2424") : Color(hex: "1C1C1E").opacity(0.85))
                            .frame(width: 44, height: 44)
                            .overlay(Circle().stroke(Color.white.opacity(0.1), lineWidth: 0.5))
                            .shadow(color: .black.opacity(0.3), radius: 5)
                        
                        Image(systemName: isShutter ? "camera.rotate.fill" : "xmark")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(.white)
                    }
                }
                .buttonStyle(.plain)
                .offset(x: 100, y: isRetake ? -104 : -104)
                .transition(.asymmetric(
                    insertion: .scale(scale: 0.5).combined(with: .opacity),
                    removal: .scale(scale: 0.8).combined(with: .opacity)
                ))
            }
        }
        .frame(height: 200, alignment: .bottom)
        .zIndex(1)
    }
}

// MARK: - Helper UI for Tab Item
struct TabItemView: View {
    @EnvironmentObject var viewModel: AppViewModel
    let tab: TabType
    let activeTab: TabType
    let width: CGFloat
    let badgeCount: Int
    let isCurrentTargetCaptured: Bool
    let todayMode: TodayCardMode
    var onTap: (TabType) -> Void
    
    @State private var tapRingScale: CGFloat = 1.0
    @State private var tapRingOpacity: Double = 0.0
    
    var body: some View {
        let isShutter = tab == .today && activeTab == .today && todayMode == .camera && !isCurrentTargetCaptured
        let isRetake = tab == .today && activeTab == .today && todayMode == .preview && !isCurrentTargetCaptured
        let isActionable = isShutter || isRetake
        
        let buttonSize: CGFloat = isActionable ? 80 : 58
        let visualOffset: CGFloat = isActionable ? -80 : -8
        
        ZStack(alignment: .bottom) {
            Button {
                if tab == .today {
                    if isShutter {
                        takePhoto()
                    } else if isRetake {
                        viewModel.usePhoto()
                    } else {
                        onTap(tab)
                    }
                    
                    tapRingScale = 1.0
                    tapRingOpacity = 0.4
                    withAnimation(.easeOut(duration: 0.5)) {
                        tapRingScale = 1.5
                        tapRingOpacity = 0.0
                    }
                } else {
                    onTap(tab)
                }
            } label: {
                ZStack(alignment: .bottom) {
                    // Invisible base to ensure the button occupies full slot width
                    Color.clear.frame(width: width)
                    
                    VStack(spacing: 0) {
                        if tab == .today {
                            centerButton
                        } else {
                            normalButton
                        }
                        // This spacer positions the button visually
                        Spacer().frame(height: max(0, abs(visualOffset) - 10))
                    }
                    .padding(.bottom, 10) // Small safety margin
                }
                .frame(width: width, height: 200)
            }
            .buttonStyle(.plain)
        }
        .animation(nil, value: activeTab) // Phase 250: No animation when tab changes
        .animation(activeTab == .today ? .interpolatingSpring(stiffness: 120, damping: 15) : nil, value: isActionable)
        .scaleEffect(isActionable ? 1.05 : 1.0) // Subtle pop when active
    }


    
    // Custom shape for hit testing that follows the offset circle if needed, 
    // but SwiftUI's .offset on Button SHOULD work if the content isn't clipped.
    // The main issue was likely the VStack frame clipping the 80pt circle.

    
    private var normalButton: some View {
        VStack(spacing: 4) {
            ZStack {
                Image(systemName: tab.iconName)
                    .font(.system(size: 22, weight: activeTab == tab ? .bold : .medium))
                    .foregroundColor(activeTab == tab ? Color.dsForeground : Color.dsMuted)
                
                if badgeCount > 0 {
                    Text("\(badgeCount)")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.white)
                        .frame(width: 16, height: 16)
                        .background(Color.dsError)
                        .clipShape(Circle())
                        .offset(x: 12, y: -10)
                }
            }
            
            Text(tab.displayName)
                .font(Typography.caption)
                .foregroundColor(activeTab == tab ? Color.dsForeground.opacity(0.9) : Color.dsMuted)
        }
    }
    
    private var centerButton: some View {
        let isShutter = activeTab == .today && todayMode == .camera && !isCurrentTargetCaptured
        let isRetake = activeTab == .today && todayMode == .preview && !isCurrentTargetCaptured
        let isActionable = isShutter || isRetake
        let buttonSize: CGFloat = isActionable ? 80 : 58
        
        return ZStack {
            // Tap feedback expansion ring
            Circle()
                .stroke(Color.white.opacity(tapRingOpacity), lineWidth: 1.5)
                .frame(width: buttonSize, height: buttonSize)
                .scaleEffect(tapRingScale)

            // Static Ring (only if not captured)
            if !isCurrentTargetCaptured {
                Circle()
                    .stroke(Color.white.opacity(0.25), lineWidth: 2.0)
                    .frame(width: buttonSize + 12, height: buttonSize + 12)
            }
            
            // Main Circle (iOSダーク/ガラス風)
            Circle()
                .fill(Color(hex: "1C1C1E").opacity(0.92))
                .frame(width: buttonSize, height: buttonSize)
                .shadow(color: .black.opacity(0.4), radius: isActionable ? 20 : 10, x: 0, y: isActionable ? 8 : 5)
                .overlay(
                    Circle()
                        .stroke(Color.white.opacity(0.12), lineWidth: 0.5)
                )
            
            if isShutter {
                // Shutter UI - Larger and more prominent
                Circle()
                    .strokeBorder(Color.white, lineWidth: 4)
                    .frame(width: 66, height: 66)
                
                Circle()
                    .fill(Color.white)
                    .frame(width: 58, height: 58)
                    .transition(.identity) // Phase 251: Instant
            } else if isRetake {
                // Save/Use UI (Repurposed from center retake)
                VStack(spacing: 2) {
                    Image(systemName: "checkmark")
                        .font(.system(size: 26, weight: .black))
                        .foregroundColor(.white)
                    Text(NSLocalizedString("use_photo_label", comment: "Use Photo"))
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.white)
                }
                .transition(.identity) // Phase 251: Instant
            } else {
                Image(systemName: tab.iconName)
                    .font(.system(size: 26, weight: .bold))
                    .foregroundColor(activeTab == tab ? .white : (isCurrentTargetCaptured ? .white.opacity(0.5) : .white.opacity(0.8)))
                    .shadow(color: activeTab == tab ? .white.opacity(0.3) : .clear, radius: 4)
                    .transition(.identity) // Phase 251: Instant
            }
        }
    }
    
    // MARK: - Handlers
    
    private func takePhoto() {
        viewModel.takePhoto()
    }
    
    private func retakePhoto() {
        viewModel.retakePhoto()
    }
}

struct CaptureNudgeView: View {
    @State private var floatingOffset: CGFloat = 0
    
    var body: some View {
        VStack(spacing: 8) {
            Text(NSLocalizedString("capture_nudge_label", comment: ""))
                .font(.system(size: 15, weight: .bold)) // Bolder and slightly larger
                .foregroundColor(.white)
                .shadow(color: .black.opacity(0.5), radius: 4, x: 0, y: 2)
            
            Image(systemName: "chevron.down")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(.white.opacity(0.8))
                .shadow(color: .black.opacity(0.5), radius: 4, x: 0, y: 2)
        }
        .offset(y: floatingOffset)
        .onAppear {
            withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
                floatingOffset = -8
            }
        }
    }
}

// MARK: - Helpers

extension View {
    func overflowHidden() -> some View {
        self.clipped()
    }
}

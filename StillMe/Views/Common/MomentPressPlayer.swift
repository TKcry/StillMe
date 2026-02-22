import SwiftUI
import AVKit

struct MomentPressPlayer: View {
    @EnvironmentObject var viewModel: AppViewModel
    let date: Date 
    let image: UIImage?
    let cloudImagePath: String?
    let momentPath: String?
    let cornerRadius: CGFloat
    var refreshTrigger: UUID? = nil
    var overrideCaptureId: String? = nil
    @ObservedObject var exportState: MomentExportState
    
    init(date: Date,
         image: UIImage? = nil, 
         cloudImagePath: String? = nil, 
         momentPath: String?, 
         cornerRadius: CGFloat, 
         refreshTrigger: UUID? = nil, 
         overrideCaptureId: String? = nil, 
         exportState: MomentExportState) {
        self.date = date
        self.image = image
        self.cloudImagePath = cloudImagePath
        self.momentPath = momentPath
        self.cornerRadius = cornerRadius
        self.refreshTrigger = refreshTrigger
        self.overrideCaptureId = overrideCaptureId
        self.exportState = exportState
    }
    
    
    
    @State private var player: AVPlayer?
    @State private var hasValidMoment = false
    @State private var pendingReload = false // Phase 212.0: Defer reload if blocked
    @State private var pendingReloadCaptureId: String? = nil // Phase 213.1: Specific target for deferred setup
    
    // Phase 213.0: Reload Debounce State
    @State private var lastLoadedURL: URL? = nil
    @State private var lastLoadedAt: Date = Date(timeIntervalSince1970: 0)
    
    // Phase 403: Concurrency Guard
    @State private var isGeneratingPlayer = false

    // Phase 213.3: Precise Authoritative Gate
    private func isPlaybackBlocked() -> Bool {
        guard exportState.isExporting else { return false }
        
        // Resolve target ID for this instance
        var targetId: String? = overrideCaptureId
        if targetId == nil { targetId = viewModel.selectedCaptureId } // Phase 213.4: Favor confirmed
        if targetId == nil { targetId = viewModel.previewCaptureId }
        
        // Only block if we are actually looking at the ID currently being exported
        if let activeId = exportState.activeCaptureId, let target = targetId {
            return target == activeId
        }
        
        // Default to not blocking if we can't confirm a match, 
        // as global blocking is what destroyed the UI.
        return false
    }
    
    // Unified State
    @State private var timeObserver: Any?
    
    // Haptics
    private let impactLight = UIImpactFeedbackGenerator(style: .light)
    
    var body: some View {
        GeometryReader { geo in
            // Unified UIKit Container (Image + Video + Gesture)
            UIMomentPlaybackContainer(
                date: date,
                image: image,
                cloudImagePath: cloudImagePath,
                player: player,
                cornerRadius: cornerRadius,
                momentPath: momentPath,
                overrideCaptureId: overrideCaptureId,
                previewCaptureId: viewModel.previewCaptureId,
                draftCaptureId: viewModel.draftCaptureId,
                isExporting: exportState.isExporting,
                isPlaybackBlocked: isPlaybackBlocked(),
                hasValidMoment: hasValidMoment
            )
            .aspectRatio(3/4, contentMode: .fit)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
        }
        .onAppear {
            updatePlayerIfNeeded()
        }
        .onDisappear {
            cleanUpObserver()
        }
        .onChange(of: viewModel.selectedCaptureId) { _ in
            print("[Playback] selectedCaptureId changed -> Re-validating")
            updatePlayerIfNeeded()
        }
        .onChange(of: overrideCaptureId) { _ in
            // Phase 401: overrideCaptureId is local to stacks. Still needed.
            print("[Playback] overrideCaptureId changed -> Re-validating")
            updatePlayerIfNeeded()
        }
        .onChange(of: exportState.isExporting) { exporting in
            if exporting {
                print("[Playback] 🚧 Entered Export State. Playback BLOCKED.")
            } else if pendingReload {
                let targetId = pendingReloadCaptureId ?? viewModel.selectedCaptureId
                print("[Playback] 🟢 Export finished && pendingReload=true. deferredSetup target=\(targetId ?? "nil") selected=\(viewModel.selectedCaptureId ?? "nil")")
                // Phase 213.2: DO NOT clear flags here. Let updatePlayerIfNeeded clear them ONLY if load succeeds.
                updatePlayerIfNeeded(overrideId: targetId)
            }
        }
    }
    
    private func updatePlayerIfNeeded(overrideId: String? = nil) { // Phase 402/403
        // Phase 403: Concurrency Guard
        if isGeneratingPlayer {
            print("[Playback] ⏳ Generation already in progress. Skipping trigger.")
            return
        }

        // Phase 401: Forbid any re-creation during video writing
        if exportState.isExporting {
            print("[Playback] 🚫 EXPORTING in progress. Blocking updatePlayerIfNeeded.")
            pendingReload = true
            return
        }
        
        // Resolve target ID for this validation run (Phase 213.2: Prioritize draft for export blocks)
        var selectedCid: String? = overrideId ?? overrideCaptureId
        
        // Phase 213.4: Try to extract from momentPath if still nil
        if selectedCid == nil, let path = momentPath {
            let components = path.split(separator: "/")
            if components.count >= 2 {
                let extracted = String(components[1])
                // Only use if it looks like a capture ID (not "draft" or "moment.mov")
                if extracted.contains("_") {
                    selectedCid = extracted
                }
            }
        }
        
        // Phase 257.2: ONLY fallback to global selectedCaptureId if the record being displayed is TODAY.
        // Falling back for historical records with missing CID results in playing today's video for past days.
        let todayKey = Date().yyyyMMdd
        let isToday = (Calendar.current.isDateInToday(date) || date.yyyyMMdd == todayKey)
        
        if selectedCid == nil && isToday {
            selectedCid = viewModel.selectedCaptureId 
        }
        
        if selectedCid == nil && isToday {
            selectedCid = viewModel.previewCaptureId
        }

        // Phase 257.3: Prevent showing old video while loading new one.
        // If the date or CID changed, the old player is no longer valid.
        if lastLoadedURL?.path.contains(date.yyyyMMdd) == false || (selectedCid != nil && lastLoadedURL?.path.contains(selectedCid!) == false) {
             print("[Playback] Resetting player due to date/ID change.")
             if let old = self.player {
                 cleanUpObserver()
                 old.replaceCurrentItem(with: nil)
             }
             self.player = nil
             self.hasValidMoment = false
             self.lastLoadedURL = nil
        }

        print("[Playback] gateCheck exporting=\(exportState.isExporting) targetId=\(selectedCid ?? "nil") activeExportId=\(exportState.activeCaptureId ?? "nil")")

        if isPlaybackBlocked() {
            pendingReload = true
            pendingReloadCaptureId = selectedCid
            print("[Playback] 🚫 BLOCKED (active export match). captureId=\(selectedCid ?? "nil") queued for defer. return")
            return
        }
        
        let fm = FileManager.default
        let appSupport = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let baseDir = appSupport.appendingPathComponent("StillMe/records", isDirectory: true)
        let dateKey = date.yyyyMMdd // Phase 257.1: Trust authoritative date
        let dayDir = baseDir.appendingPathComponent(dateKey)

        // Selected ID resolution already done above for Phase 213.1 logic
        
        if selectedCid == nil {
            let selectedFileURL = dayDir.appendingPathComponent("selected.json")
            if let data = try? Data(contentsOf: selectedFileURL),
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let cid = json["selectedCaptureId"] as? String {
                selectedCid = cid
            }
        }
        
        // Final Resolve
        var resolvedURL = FileUtils.resolveMomentURL(for: date, captureId: selectedCid)
        
        // Phase 257: Trust momentPath if it points to an existing local file
        if let relPath = momentPath, !relPath.hasPrefix("http") {
             let potentialURL = baseDir.appendingPathComponent(relPath)
             if fm.fileExists(atPath: potentialURL.path) {
                 resolvedURL = potentialURL
             }
        }
        
        let exists = resolvedURL.map { fm.fileExists(atPath: $0.path) } ?? false
        
        // Phase 213.0/402: Reload policy (STRICT Path-based ONLY)
        if let currentURL = lastLoadedURL, currentURL.path == resolvedURL?.path {
            if player != nil && player?.currentItem != nil {
                // print("[Playback] Same path, player exists. Skipping.")
                return
            }
        }

        // Log requirements
        var size: Int64 = 0
        var modDate = Date(timeIntervalSince1970: 0)
        if let url = resolvedURL, exists {
            let attrs = try? fm.attributesOfItem(atPath: url.path)
            size = attrs?[FileAttributeKey.size] as? Int64 ?? 0
            modDate = attrs?[FileAttributeKey.modificationDate] as? Date ?? modDate
        }
        print("[Playback] dateKey=\(dateKey) selectedCaptureId=\(selectedCid ?? "N/A") resolvedURL=\(resolvedURL?.lastPathComponent ?? "N/A") exists=\(exists) size=\(size) modifiedAt=\(modDate)")

        // Update tracking state for debounce (Path only)
        lastLoadedURL = resolvedURL
        // lastLoadedAt = Date() // Phase 401: Stop tracking modDate

        if !exists {
            hasValidMoment = false // Phase 257: Mark as invalid if file is missing
            // Phase 257: Proactive download if missing (e.g. on new device)
            viewModel.ensureMomentDownloaded(for: date)
        }

        if let movieURL = resolvedURL, exists {
            // Phase 213.2: Only clear pending reload if we actually FOUND and LOADED the file
            if pendingReload {
                print("[Playback] ✅ deferredSetup SUCCESS for \(selectedCid ?? "nil"). Clearing flags.")
                pendingReload = false
                pendingReloadCaptureId = nil
            }

            // Phase 403: Lock generation
            isGeneratingPlayer = true
            
            // Phase 257: Async validation of asset to avoid Hang detected
            Task {
                defer { 
                    Task { @MainActor in
                        self.isGeneratingPlayer = false
                    }
                }
                
                let asset = AVAsset(url: movieURL)
                let duration: Double
                do {
                    // Modern async duration fetch
                    if #available(iOS 15.0, *) {
                        duration = try await asset.load(.duration).seconds
                    } else {
                        duration = asset.duration.seconds
                    }
                } catch {
                    print("[Playback] ❌ Failed to load asset duration: \(error)")
                    return
                }
                
                // Phase 269: Guard - Require at least 1.5s for LIVE playback
                if duration < 1.5 {
                    print("[Playback] ⚠️ Moment too short (\(duration)s < 1.5s). LIVE blocked.")
                    await MainActor.run {
                        if let old = self.player {
                            cleanUpObserver()
                            old.replaceCurrentItem(with: nil)
                        }
                        self.hasValidMoment = false
                        self.player = nil
                    }
                    return
                }

                await MainActor.run {
                    self.hasValidMoment = true
                }
                
                // Phase 401/402: OFF-LOAD AVPlayer creation to background thread
                let newItem = AVPlayerItem(url: movieURL)
                let p = AVPlayer(playerItem: newItem)
                p.isMuted = true
                p.automaticallyWaitsToMinimizeStalling = false 
                p.actionAtItemEnd = .pause
                
                await MainActor.run {
                    // Check logic again before committing to MainThread
                    if self.isPlaybackBlocked() {
                        self.pendingReload = true
                        print("[Playback] 🚫 BLOCKED (export active) at commit point")
                        return
                    }

                    // 1. Clean up OLD player & observer
                    if let oldPlayer = self.player {
                        self.cleanUpObserver() // Uses self.player to remove
                        oldPlayer.replaceCurrentItem(with: nil) // Explicitly detach to prevent reuse crash
                    }

                    // 2. Assign NEW player
                    print("[Playback] Applying NEW player in background for \(movieURL.lastPathComponent)")
                    let interval = CMTime(seconds: 0.1, preferredTimescale: 600)
                    self.timeObserver = p.addPeriodicTimeObserver(forInterval: interval, queue: .main) { _ in }
                    self.player = p
                }
            }
            return
        }

        if let old = self.player {
            cleanUpObserver()
            old.replaceCurrentItem(with: nil)
        }
        hasValidMoment = false
        player = nil
    }
    
    private func cleanUpObserver() {
        if let observer = timeObserver {
            player?.removeTimeObserver(observer)
            timeObserver = nil
        }
    }
}

// Ultimate UIKit-based Moment Container
struct UIMomentPlaybackContainer: UIViewRepresentable {
    let date: Date // Phase 257.1
    let image: UIImage?
    let cloudImagePath: String?
    let player: AVPlayer?
    let cornerRadius: CGFloat
    let momentPath: String?
    let overrideCaptureId: String?
    let previewCaptureId: String?
    let draftCaptureId: String?
    let isExporting: Bool
    let isPlaybackBlocked: Bool
    let hasValidMoment: Bool
    
    func makeUIView(context: Context) -> UIMomentPlaybackView {
        let view = UIMomentPlaybackView()
        view.setupGesture()
        view.setup(date: date, player: player, momentPath: momentPath, image: image, cloudImagePath: cloudImagePath, cornerRadius: cornerRadius, overrideCaptureId: overrideCaptureId, previewCaptureId: previewCaptureId, draftCaptureId: draftCaptureId, isExporting: isExporting, isPlaybackBlocked: isPlaybackBlocked, hasValidMoment: hasValidMoment)
        return view
    }
    
    func updateUIView(_ uiView: UIMomentPlaybackView, context: Context) {
        uiView.update(date: date, player: player, momentPath: momentPath, image: image, cloudImagePath: cloudImagePath, cornerRadius: cornerRadius, overrideCaptureId: overrideCaptureId, previewCaptureId: previewCaptureId, draftCaptureId: draftCaptureId, isExporting: isExporting, isPlaybackBlocked: isPlaybackBlocked, hasValidMoment: hasValidMoment)
    }
}

class UIMomentPlaybackView: UIView {
    private var date: Date = Date() // Phase 257.1
    private let imageView = UIImageView()
    private let bridgeImageView = UIImageView() // Phase 204: Bridge frame for seamless transition
    private let playerHostView = UIView()
    private let playerLayer = AVPlayerLayer()
    private let liveIndicator = UILabel()
    private let longPress = UILongPressGestureRecognizer()
    private let impact = UIImpactFeedbackGenerator(style: .light)
    
    private let contentContainer = UIView() // Phase 207.0: Mirror container
    private var isBridgeCreated = false // Multi-generation preventative
    private var momentPath: String? // Phase 205.2
    private var overrideCaptureId: String? // Phase 211.4
    private var previewCaptureId: String? // Phase 211.7
    private var draftCaptureId: String?   // Phase 211.7
    private var isExporting: Bool = false // Phase 212.0
    private var isPlaybackBlocked: Bool = false // Phase 213.3
    private var hasValidMoment: Bool = false // Phase 269
    
    // Phase 192.1: Lifecycle States
    private enum PlaybackState {
        case idle
        case seeking
        case playing
        case bridging // Phase 204: Temporary bridge frame display
        case atGoalHolding
    }
    
    private var playbackState: PlaybackState = .idle
    private var wantsToPlay = false
    private var didStartPlayback = false // Phase 205.3
    private var timeObserver: Any?
    private var endObserver: Any? // Item finish notification
    private var pressStartTime: Date? // Phase 205.4
    private var progressCheckTimer: Timer? // Phase 206.8: Stall detection
    private var releaseDelayTimer: Timer?  // Phase 206.8: Visual continuity
    private var lastRecordedProgressTime: Double = 0
    private let minHoldPlaybackMs: Double = 0.4 // Phase 210.0: Ensure minimum playback duration
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        // Phase 207.1: Kill implicit animations on playerLayer
        playerLayer.actions = [
            "bounds": NSNull(),
            "position": NSNull(),
            "frame": NSNull(),
            "transform": NSNull(),
            "contents": NSNull()
        ]
        
        // Phase 197: Anti-accidental touch
        self.isMultipleTouchEnabled = false
        
        // Rule 4: Consolidated clipping at container level
        self.clipsToBounds = true
        self.layer.masksToBounds = true
        
        backgroundColor = UIColor(red: 31/255, green: 31/255, blue: 31/255, alpha: 1.0)
        
        // Root setup: ImageView, Bridge, Player are children of container
        contentContainer.clipsToBounds = true
        contentContainer.layer.masksToBounds = true
        addSubview(contentContainer)
        
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        imageView.isUserInteractionEnabled = false
        imageView.isMultipleTouchEnabled = false
        contentContainer.addSubview(imageView)
        
        bridgeImageView.contentMode = .scaleAspectFill
        bridgeImageView.clipsToBounds = true
        bridgeImageView.isHidden = true
        bridgeImageView.isUserInteractionEnabled = false
        bridgeImageView.isMultipleTouchEnabled = false
        contentContainer.addSubview(bridgeImageView)
        
        playerHostView.backgroundColor = .clear
        playerHostView.isHidden = true
        playerHostView.isUserInteractionEnabled = false
        playerHostView.isMultipleTouchEnabled = false
        playerLayer.videoGravity = .resizeAspectFill
        playerHostView.layer.addSublayer(playerLayer)
        contentContainer.addSubview(playerHostView)
        
        // 3. Setup LIVE Indicator (Overlay - NOT mirrored)
        liveIndicator.text = "LIVE"
        liveIndicator.font = .systemFont(ofSize: 10, weight: .bold)
        liveIndicator.textColor = .white
        liveIndicator.backgroundColor = UIColor.black.withAlphaComponent(0.5)
        liveIndicator.textAlignment = .center
        liveIndicator.layer.cornerRadius = 4
        liveIndicator.clipsToBounds = true
        liveIndicator.isHidden = true
        liveIndicator.isUserInteractionEnabled = false 
        liveIndicator.isMultipleTouchEnabled = false
        addSubview(liveIndicator)
        
        // 4. Constraints
        [contentContainer, imageView, bridgeImageView, playerHostView].forEach { v in
            v.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                v.topAnchor.constraint(equalTo: topAnchor),
                v.bottomAnchor.constraint(equalTo: bottomAnchor),
                v.leadingAnchor.constraint(equalTo: leadingAnchor),
                v.trailingAnchor.constraint(equalTo: trailingAnchor)
            ])
        }
        
        liveIndicator.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            liveIndicator.topAnchor.constraint(equalTo: topAnchor, constant: 8),
            liveIndicator.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
            liveIndicator.widthAnchor.constraint(equalToConstant: 30),
            liveIndicator.heightAnchor.constraint(equalToConstant: 16)
        ])
    }
    
    func setupGesture() {
        longPress.minimumPressDuration = 0.25 // Phase 205.3: Avoid accidental tap
        longPress.allowableMovement = 20     // Phase 205.3: Tighten allowable movement
        longPress.cancelsTouchesInView = false // Phase 285: Allow SwiftUI gestures (swiping) to receive touches
        longPress.addTarget(self, action: #selector(handleLongPress(_:)))
        addGestureRecognizer(longPress)
    }
    
    required init?(coder: NSCoder) { fatalError() }
    
    private var currentCloudImagePath: String? = nil // Phase 288: Track current path for updates

    // ... (rest of the class)
    
    func setup(date: Date, player: AVPlayer?, momentPath: String?, image: UIImage?, cloudImagePath: String?, cornerRadius: CGFloat, overrideCaptureId: String?, previewCaptureId: String?, draftCaptureId: String?, isExporting: Bool, isPlaybackBlocked: Bool, hasValidMoment: Bool) {
        self.date = date
        playerLayer.player = player
        self.momentPath = momentPath
        self.overrideCaptureId = overrideCaptureId
        self.previewCaptureId = previewCaptureId
        self.draftCaptureId = draftCaptureId
        self.isExporting = isExporting
        self.isPlaybackBlocked = isPlaybackBlocked
        self.hasValidMoment = hasValidMoment
        self.currentCloudImagePath = cloudImagePath
        
        applyCornerRadius(cornerRadius)
        
        if let img = image {
            imageView.image = img
        } else if let path = cloudImagePath {
            loadCloudImage(path: path)
        }
    }
    
    func update(date: Date, player: AVPlayer?, momentPath: String?, image: UIImage?, cloudImagePath: String?, cornerRadius: CGFloat, overrideCaptureId: String?, previewCaptureId: String?, draftCaptureId: String?, isExporting: Bool, isPlaybackBlocked: Bool, hasValidMoment: Bool) {
        self.date = date
        self.momentPath = momentPath
        self.overrideCaptureId = overrideCaptureId
        self.previewCaptureId = previewCaptureId
        self.draftCaptureId = draftCaptureId
        self.isExporting = isExporting
        self.isPlaybackBlocked = isPlaybackBlocked
        self.hasValidMoment = hasValidMoment
        
        if playerLayer.player != player {
            playerLayer.player = player
            playerLayer.videoGravity = .resizeAspectFill
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            playerLayer.frame = playerHostView.bounds
            CATransaction.commit()
            isBridgeCreated = false
        }
        
        // Phase 288/400: Optimized Image Update
        if let img = image {
            if imageView.image !== img {
                imageView.image = img
                self.currentCloudImagePath = nil
            }
        } else if let path = cloudImagePath {
            if path != self.currentCloudImagePath || imageView.image == nil {
                print("[Playback] Path changed from \(self.currentCloudImagePath ?? "nil") to \(path). Reloading image.")
                self.currentCloudImagePath = path
                // Clear old image only if path actually changed to avoid ghosting
                if path != self.currentCloudImagePath {
                    imageView.image = nil 
                }
                loadCloudImage(path: path)
            }
        } else {
            if imageView.image != nil {
                imageView.image = nil
                self.currentCloudImagePath = nil
            }
        }
        
        bridgeImageView.image = nil
        bridgeImageView.isHidden = true
        applyCornerRadius(cornerRadius)
    }
    
    private func loadCloudImage(path: String) {
        // Check cache first
        if let cached = ImageCacheService.shared.getImage(for: path) {
            self.imageView.image = cached
            return
        }
        
        Task { [weak self] in
            do {
                let downloadURL: URL
                if path.hasPrefix("http") {
                    guard let url = URL(string: path) else { return }
                    downloadURL = url
                } else {
                    downloadURL = try await CloudStorageService.shared.getDownloadURL(for: path)
                }
                
                let (data, _) = try await URLSession.shared.data(from: downloadURL)
                if let loaded = UIImage(data: data) {
                    ImageCacheService.shared.saveImage(loaded, for: path)
                    await MainActor.run {
                        self?.imageView.image = loaded
                    }
                }
            } catch {
                print("[Playback] ❌ Failed to load cloud image: \(error)")
            }
        }
    }
    
    private func applyCornerRadius(_ cornerRadius: CGFloat) {
        self.layer.cornerRadius = cornerRadius
        imageView.layer.cornerRadius = cornerRadius
        bridgeImageView.layer.cornerRadius = cornerRadius
        playerHostView.layer.cornerRadius = cornerRadius
        self.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner, .layerMinXMaxYCorner, .layerMaxXMaxYCorner]
    }
    
    @objc private func handleLongPress(_ gesture: UILongPressGestureRecognizer) {
        let now = Date()
        let deltaMs = pressStartTime.map { Int(now.timeIntervalSince($0) * 1000) } ?? 0
        
        if gesture.state == .began {
            playerHostView.transform = .identity
            playerHostView.layer.transform = CATransform3DIdentity
            playerLayer.transform = CATransform3DIdentity
            playerLayer.videoGravity = .resizeAspectFill
        }
        
        switch gesture.state {
        case .began:
            pressStartTime = now
            if isPlaybackBlocked || !hasValidMoment {
                print("[Playback] 🚫 Long-press BLOCKED: active export in progress or invalid moment (valid=\(hasValidMoment)).")
                return 
            }
            
            wantsToPlay = true
            didStartPlayback = false
            isBridgeCreated = false
            setParentScrollEnabled(false)
            
            if let p = playerLayer.player {
                p.pause()
                self.removeTimeObserver()
                
                self.playbackState = .seeking
                p.seek(to: CMTime.zero, toleranceBefore: CMTime.zero, toleranceAfter: CMTime.zero) { [weak self] finished in
                    guard let self = self, finished, self.wantsToPlay else { return }
                    self.finalizePlaybackStart(player: p, startTime: self.pressStartTime ?? now)
                }
            } else {
                // Fallback / legacy display logic if player is unexpectedly nil
                didStartPlayback = true
                playerHostView.isHidden = false
                liveIndicator.isHidden = false
                imageView.isHidden = true
                playbackState = .playing
                setNeedsLayout()
                layoutIfNeeded()
            }
            
        case .changed:
            break
            
        case .ended, .cancelled, .failed:
            setParentScrollEnabled(true)
            let elapsed = Date().timeIntervalSince(pressStartTime ?? now)
            let remaining = minHoldPlaybackMs - elapsed
            
            if remaining > 0 && gesture.state == .ended && didStartPlayback && playbackState == .playing {
                wantsToPlay = false
                DispatchQueue.main.asyncAfter(deadline: .now() + remaining) { [weak self] in
                    guard let self = self else { return }
                    if self.playbackState == .playing || self.playbackState == .seeking {
                        self.resetPlayback()
                    }
                }
                return
            }
            
            let currentPlayTime = playerLayer.player?.currentTime().seconds ?? 0
            if currentPlayTime > 0.02 && didStartPlayback && gesture.state == .ended && playbackState == .playing {
                releaseDelayTimer?.invalidate()
                releaseDelayTimer = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: false) { [weak self] _ in
                    self?.resetPlayback()
                }
            } else {
                resetPlayback()
            }
            
        default:
            break
        }
    }
    
    private func finalizePlaybackStart(player: AVPlayer, startTime: Date) {
        guard wantsToPlay else { return }
        guard self.bounds.width > 1, self.bounds.height > 1 else {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.01) { [weak self] in
                self?.finalizePlaybackStart(player: player, startTime: startTime)
            }
            return
        }
        
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        playerLayer.frame = playerHostView.bounds
        playerHostView.isHidden = false
        liveIndicator.isHidden = !hasValidMoment // Phase 269: Guard
        imageView.isHidden = true
        CATransaction.commit()
        
        player.play()
        self.didStartPlayback = true
        self.lastRecordedProgressTime = 0
        
        self.progressCheckTimer?.invalidate()
        self.progressCheckTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] timer in
            guard let self = self, let p = self.playerLayer.player else { timer.invalidate(); return }
            let current = p.currentTime().seconds
            if current >= 0.05 {
                timer.invalidate()
            } else if Date().timeIntervalSince(startTime) > 0.4 {
                timer.invalidate()
            }
            self.lastRecordedProgressTime = current
        }
        
        self.playbackState = .playing
        self.setupTimeObserver(for: player)
        self.setNeedsLayout()
        self.layoutIfNeeded()
    }
    
    private func setupTimeObserver(for player: AVPlayer) {
        removeTimeObserver()
        guard let item = player.currentItem else { return }
        
        endObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: item,
            queue: .main
        ) { [weak self] _ in
            self?.transitionToGoal()
        }
        
        let interval = CMTime(value: 1, timescale: 60)
        timeObserver = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            guard let self = self, self.playbackState == .playing, self.wantsToPlay else { return }
            guard let currentItem = player.currentItem, currentItem.status == .readyToPlay else { return }
            
            let duration = currentItem.duration.seconds
            let current = time.seconds
            if currentItem.duration.isIndefinite || duration <= 0 { return }
            
            if current > duration + 0.2 {
                player.pause()
                player.seek(to: CMTime.zero, toleranceBefore: CMTime.zero, toleranceAfter: CMTime.zero)
                return
            }
            
            let threshold = duration - (5.0 / 24.0) - (1.0 / 24.0)
            if current > 0 && current >= threshold {
                self.transitionToGoal()
            }
        }
    }
    
    private func removeTimeObserver() {
        if let observer = timeObserver {
            playerLayer.player?.removeTimeObserver(observer)
            timeObserver = nil
        }
        if let observer = endObserver {
            NotificationCenter.default.removeObserver(observer)
            endObserver = nil
        }
    }
    
    private func transitionToGoal() {
        guard playbackState == .playing else { return }
        if isBridgeCreated { return }
        isBridgeCreated = true
        
        playerLayer.player?.pause()
        if let asset = playerLayer.player?.currentItem?.asset {
            let generator = AVAssetImageGenerator(asset: asset)
            generator.appliesPreferredTrackTransform = true
            generator.requestedTimeToleranceBefore = .zero
            generator.requestedTimeToleranceAfter = .zero
            
            let time = playerLayer.player?.currentTime() ?? .zero
            generator.generateCGImageAsynchronously(for: time) { [weak self] cgImage, _, _ in
                guard let self = self, let cgImage = cgImage else { return }
                DispatchQueue.main.async {
                    self.bridgeImageView.image = UIImage(cgImage: cgImage)
                    CATransaction.begin()
                    CATransaction.setDisableActions(true)
                    self.playbackState = .bridging
                    self.playerHostView.isHidden = true
                    self.liveIndicator.isHidden = true
                    self.bridgeImageView.isHidden = false
                    self.imageView.isHidden = true
                    CATransaction.commit()
                    self.finalizeBridgeSequence()
                }
            }
        }
    }
    
    private func finalizeBridgeSequence() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.06) { [weak self] in
            guard let self = self, self.playbackState == .bridging else { return }
            if self.longPress.state == .began || self.longPress.state == .changed {
                CATransaction.begin()
                CATransaction.setDisableActions(true)
                self.playbackState = .atGoalHolding
                self.bridgeImageView.isHidden = true
                self.imageView.isHidden = false
                CATransaction.commit()
            } else {
                self.resetPlayback()
            }
        }
    }
    
    private func resetPlayback() {
        wantsToPlay = false
        didStartPlayback = false
        progressCheckTimer?.invalidate()
        progressCheckTimer = nil
        releaseDelayTimer?.invalidate()
        releaseDelayTimer = nil
        
        if let p = playerLayer.player {
            p.pause()
            p.seek(to: .zero, toleranceBefore: .zero, toleranceAfter: .zero)
        }
        
        playbackState = .idle
        isBridgeCreated = false
        removeTimeObserver()
        
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        playerHostView.isHidden = true
        bridgeImageView.isHidden = true
        bridgeImageView.image = nil
        liveIndicator.isHidden = true
        imageView.isHidden = false
        CATransaction.commit()
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        
        contentContainer.transform = .identity 
        
        playerHostView.transform = .identity
        playerHostView.layer.transform = CATransform3DIdentity
        playerLayer.videoGravity = .resizeAspectFill
        playerLayer.bounds = playerHostView.bounds
        playerLayer.position = CGPoint(x: playerHostView.bounds.midX, y: playerHostView.bounds.midY)
        bridgeImageView.frame = bounds
        
        CATransaction.commit()
        
        if (longPress.state == .began || longPress.state == .changed) && wantsToPlay && playbackState == .playing {
            if playerLayer.isReadyForDisplay, let p = playerLayer.player, p.rate == 0 {
                p.playImmediately(atRate: 1.0)
            }
        }
        liveIndicator.frame = CGRect(x: bounds.width - 45, y: 10, width: 35, height: 18)
    }
    
    private func setParentScrollEnabled(_ enabled: Bool) {
        var current = self.superview
        while current != nil {
            if let scroll = current as? UIScrollView {
                scroll.isScrollEnabled = enabled
                return
            }
            current = current?.superview
        }
    }
}

extension View {
    @ViewBuilder func isHidden(_ hidden: Bool) -> some View {
        if hidden { self.hidden() } else { self }
    }
}

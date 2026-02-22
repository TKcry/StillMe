import SwiftUI
import Combine
import Firebase
import AVFoundation
import FirebaseAuth

enum TodayCardMode {
    case idle
    case camera
    case preview
}

enum TodayViewCategory: String {
    case publicMode
    case targetedMode
}

class AppViewModel: ObservableObject {
    @Published var profile: UserProfile = UserProfile(name: "User", handle: "unassigned")
    @Published var pairs: [PairEntry] = []
    @Published var isCapturedToday: Bool = false
    @Published var isWindowCapturedToday: Bool = false
    @Published var pendingAvatarImage: UIImage? = nil
    @Published var capturedImage: UIImage? = nil
    @Published var capturedThumbnail: UIImage? = nil // Phase 257: Cache for fast gallery
    @Published var targetedPairId: String? = nil // Targeted Pair for capture (nil = All/Public)
    @Published var todayViewCategory: TodayViewCategory = .publicMode
    @Published var todayMode: TodayCardMode = .idle
    @Published var activeTab: TabType = .today {
        didSet {
            // Phase 247: Stop camera immediately and clear state if moving away from Today
            if activeTab != .today {
                if todayMode != .idle {
                    todayMode = .idle
                    capturedImage = nil
                    CameraService.shared.stopSessionAsync()
                }
                targetedPairId = nil
                todayViewCategory = .publicMode
            }
        }
    }
    // Phase 208.0: Draft Capture management
    @Published var draftCaptureId: String? = nil {
        didSet {
            print("[State][AppVM] draftCaptureId \(oldValue ?? "nil") -> \(draftCaptureId ?? "nil")")
        }
    }
    private var _selectedCaptureId: String? = nil
    var selectedCaptureId: String? { // Phase 211.0: Reactive capture identity
        get { _selectedCaptureId }
        set {
            if _selectedCaptureId == newValue { return }
            print("[State][AppVM] selectedCaptureId \(_selectedCaptureId ?? "nil") -> \(newValue ?? "nil")")
            objectWillChange.send()
            _selectedCaptureId = newValue
        }
    }
    @Published var previewCaptureId: String? = nil // Phase 211.7: Stable preview ID
    
    // Phase 212.1: Reference-based Export State (Single instance)
    var exportState: MomentExportState { CameraService.shared.exportState }
    
    // Onboarding
    @AppStorage("hasCompletedOnboarding") var hasCompletedOnboarding: Bool = false
    @AppStorage("didAskNotificationPermission") var didAskNotificationPermission: Bool = false
    @Published var showForceOnboarding: Bool = false
    @Published var pendingInviteCount: Int = 0
    
    // Notifications & Appearance
    @AppStorage("isDailyReminderEnabled") var isDailyReminderEnabled: Bool = false
    @AppStorage("reminderTime") var reminderTime: Double = 28800 // Default to 8:00 AM (8 * 3600)
    
    static let MAX_PAIRS = 999 // ✅ Increased pair limit to allow virtually unlimited friends
    
    // Bridge to K's logic
    let recordsStore = RecordsStore()
    private let imageStore = ImageStore()
    
    // Firebase Social Stores
    let sessionStore = SessionStore()
    let pairStore = PairStore.shared
    
    private var cancellables = Set<AnyCancellable>()
    
    @Published var records: [String: DayRecord] = [:]
    
    // Concurrent sync lock
    private var isSyncing = false
    
    // Phase 280: Sync Hydration Safety
    private var isHydrated = false
    private var isHydrating = false

    // Phase 400: Optimization - Prevention of duplicate syncs
    private var isBackfilling = false
    private var inProgressUploads: Set<String> = [] // pairId_dateId

    init() {
        // Sync records from store
        recordsStore.$records
            .sink { [weak self] newRecords in
                self?.records = newRecords
            }
            .store(in: &cancellables)
            
        // Sync social data from PairStore
        setupSocialSync()
        
        // Sync Capture status
        pairStore.$myDaily
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.updateCaptureStatus()
            }
            .store(in: &cancellables)
        
        updateCaptureStatus()
        
        // Start Firebase logic
        pairStore.initialize()
        
        // Cache management
        PartnerCacheStore.shared.cleanupOldCache()
        
        // Foreground observer for cleanup and backfill
        NotificationCenter.default.addObserver(forName: UIApplication.willEnterForegroundNotification, object: nil, queue: .main) { [weak self] _ in
            PartnerCacheStore.shared.cleanupOldCache()
            self?.checkAndBackfillDailySync()
            self?.updateCaptureStatus() // Refresh status on foreground
        }
        
        // Midnight observer for automatic day switch
        NotificationCenter.default.addObserver(forName: UIApplication.significantTimeChangeNotification, object: nil, queue: .main) { [weak self] _ in
            self?.updateCaptureStatus()
        }
        
        NotificationCenter.default.addObserver(forName: .NSCalendarDayChanged, object: nil, queue: .main) { [weak self] _ in
            self?.updateCaptureStatus()
        }

        // Initial registration of auth listener is handled by setupSocialSync()
    }
    
    func onRootViewAppear() {
        // Auto-start on launch removed as per user request (Phase 239)
    }
    
    // Phase 239/247/250: Handle explicit tab taps for camera start
    func handleTabTap(_ tab: TabType, isExplicitTap: Bool) {
        if tab == .today {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                if activeTab == .today && todayMode == .idle && !isCurrentTargetCaptured && isExplicitTap {
                    // Manual start from tab bar if already on Today tab
                    startCamera()
                }
                self.activeTab = tab
            }
        } else {
            // Phase 250: Force NO animation when leaving Today for others
            var transaction = Transaction()
            transaction.disablesAnimations = true
            withTransaction(transaction) {
                self.activeTab = tab
            }
        }
    }
    
    var isCurrentTargetCaptured: Bool {
        let record = recordsStore.record(for: Date())
        switch todayViewCategory {
        case .publicMode:
            return isCapturedToday
        case .targetedMode:
            if let pid = targetedPairId {
                return record?.targetedStatus(for: pid)?.hasWindow ?? false
            } else {
                return true // Phase 280: Return true to hide nudge on selection grid
            }
        }
    }
    
    /// Returns the partner's status for a given pair (Phase 280)
    func partnerStatus(for pairId: String) -> TodayStatusModel.TodayUserStatus? {
        let pair = pairs.first(where: { $0.id == pairId })
        guard let partnerUid = pair?.partnerUid else { return nil }
        return pairStore.statusByPair[pairId]?.statusByUid[partnerUid]
    }
    
    // MARK: - Camera Actions (Phase 230)
    
    func startCamera() {
        // Phase 251: Called from handleTabTap but also safe as standalone
        DispatchQueue.main.async {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                self.todayMode = .camera
                // Default to back camera for standard photography (Phase 241)
                CameraService.shared.currentPosition = .back
                CameraService.shared.checkPermissions()
            }
        }
    }
    
    func switchCamera() {
        // Phase 251: Force NO animation when flipping camera
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            CameraService.shared.switchCamera()
        }
    }
    
    func takePhoto() {
        prepareCapture(date: Date())
        
        CameraService.shared.capturePhoto(authoritativeId: draftCaptureId) { [weak self] image, thumb, authoritativeId in
            guard let self = self, let image = image else { return }
            
            DispatchQueue.main.async {
                if !authoritativeId.isEmpty {
                    self.draftCaptureId = authoritativeId
                    print("[AppVM] Synced draftCaptureId to authoritativeId: \(authoritativeId)")
                }
                withAnimation {
                    self.capturedImage = image
                    self.capturedThumbnail = thumb // Phase 257
                    self.todayMode = .preview
                }
            }
        }
    }
    
    func retakePhoto() {
        discardDraft(date: Date())
        // Phase 251: Instant switch back to camera
        capturedImage = nil
        todayMode = .camera
        CameraService.shared.checkPermissions()
    }
    
    func usePhoto() {
        guard let image = capturedImage else { return }
        addWindowEntry(image: image, targetedPairId: targetedPairId, camera: CameraService.shared)
        
        // Phase 251: Instant exit from camera/preview to idle
        todayMode = .idle
        capturedImage = nil
        capturedThumbnail = nil
        targetedPairId = nil // Reset target after use
    }

    func loadMoreGallery() async {
        // Phase 188: Local-First Gallery (No more remote paging)
    }
    
    /// Auto-restores if local image files exist but are not registered in RecordsStore
    private func autoRestoreMissingRecords() async {
        let calendar = Calendar.current
        let today = Date()
        let fm = FileManager.default
        let appSupport = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let recordsDir = appSupport.appendingPathComponent("StillMe/records", isDirectory: true)

        for i in 0..<30 {
            guard let date = calendar.date(byAdding: .day, value: -i, to: today) else { continue }
            let dateKey = date.yyyyMMdd
            let dayDir = recordsDir.appendingPathComponent(dateKey)
            
            guard fm.fileExists(atPath: dayDir.path) else { continue }
            
            let current = recordsStore.record(for: date)
            
            // If already has window path, skip basic restoration
            if current?.windowImagePath != nil { continue }

            // Look for capture subdirectories
            if let items = try? fm.contentsOfDirectory(atPath: dayDir.path) {
                let captureIds = items.filter { $0.contains("_") }.sorted(by: >)
                for cid in captureIds {
                    let cDir = dayDir.appendingPathComponent(cid)
                    let p720 = cDir.appendingPathComponent("photo_720.jpg")
                    let wLegacy = cDir.appendingPathComponent("window.jpg")
                    let m720 = cDir.appendingPathComponent("moment_720.mp4")
                    
                    var entry = current ?? DayRecord(id: dateKey)
                    var found = false
                    
                    if fm.fileExists(atPath: p720.path) {
                        entry.windowImagePath = "\(dateKey)/\(cid)/photo_720.jpg"
                        entry.selectedCaptureId = cid
                        found = true
                    } else if fm.fileExists(atPath: wLegacy.path) {
                        entry.windowImagePath = "\(dateKey)/\(cid)/window.jpg"
                        entry.selectedCaptureId = cid
                        found = true
                    }
                    
                    if fm.fileExists(atPath: m720.path) {
                        entry.momentPath = "\(dateKey)/\(cid)/moment_720.mp4"
                        entry.selectedCaptureId = cid
                        found = true
                    }
                    
                    if found {
                        recordsStore.upsertRecord(entry)
                        break
                    }
                }
            }
        }
    }
    
    /// Sync local recordsStore with high-fidelity metadata from Firestore personal logs
    func syncRecordsWithFirestore() async {
        let logs = pairStore.myDaily
        print("[AppVM] syncRecordsWithFirestore: Found \(logs.count) logs in PairStore")
        
        for (dateId, status) in logs {
            let formatter = DateFormatter.yyyyMMdd
            guard let date = formatter.date(from: dateId) else { continue }
            
            var local = recordsStore.record(for: date) ?? DayRecord(id: dateId)
            var changed = false
            
            // Sync Window Metadata
            if let m = status.memo, m != local.memo {
                local.memo = m
                changed = true
            }
            
            if let mp = status.momentPath, !mp.isEmpty {
                // Only update if it's a cloud path or we don't have a local one
                let isCloud = mp.contains("pairs/") || mp.contains("users/")
                if isCloud || local.momentPath == nil {
                    local.momentPath = mp
                    changed = true
                }
            }

            if status.windowDidCapture {
                // Determine best local path (preferring standard records structure)
                let localRel = "\(dateId)/window.jpg"
                let captureIdSearch = local.selectedCaptureId ?? "unknown" // We might need to handle captureId better
                
                if local.windowCapturedAt != status.windowCapturedAt {
                    local.windowCapturedAt = status.windowCapturedAt
                    changed = true
                }
                
                if local.windowPhotoUrl != status.windowPhotoUrl {
                    local.windowPhotoUrl = status.windowPhotoUrl
                    changed = true
                }

                // If local path is missing but we have remote info, try to resolve it
                if local.windowImagePath == nil {
                    if imageStore.fileExists(relativePath: localRel) {
                        local.windowImagePath = localRel
                        changed = true
                    } else if let remoteRelative = status.windowThumbRelativePath {
                        local.windowImagePath = remoteRelative
                        changed = true
                    }
                }
            }
            
            // Sync Rating
            if let r = status.rating, r != local.rating {
                local.rating = r
                changed = true
            }
            
            if changed {
                // Note: Upserting window here might be tricky if captureId is missing.
                // However, for restoration purposes, we primarily care about the windowImagePath and windowPhotoUrl.
                recordsStore.upsertRecord(local)
            }
        }
    }

    /// Background task to restore missing physical images from Cloud Storage
    /// Phase 257: Background task to auto-cache latest 30 thumbnails
    private func autoCacheLatestThumbnails() {
        Task(priority: .background) {
            let entries = records.values
                .filter { $0.hasWindow }
                .sorted { $0.id > $1.id }
                .prefix(30) // REQ: Limit to latest 30 entries
            
            print("[AutoCache] Checking latest \(entries.count) thumbnails...")
            
            for entry in entries {
                let dateId = entry.id
                
                // Only download if we have a thumb URL and no local thumb path yet
                // Or if the thumbPath is a cloud URL
                guard let thumbUrlString = entry.windowThumbPath,
                      thumbUrlString.contains("http") || thumbUrlString.contains("users/") || thumbUrlString.contains("pairs/") else {
                    continue
                }
                
                // Cache check via CloudImageView's logic (indirectly)
                // But for background, we use URLSession to download and save to ImageStore if possible
                // Actually, CloudImageView handles SDWebImage-like caching.
                // To "Pre-cache" for the gallery, we can just trigger a download.
                
                do {
                    let downloadURL: URL
                    if thumbUrlString.hasPrefix("http") {
                        guard let u = URL(string: thumbUrlString) else { continue }
                        downloadURL = u
                    } else {
                        downloadURL = try await CloudStorageService.shared.getDownloadURL(for: thumbUrlString)
                    }
                    
                    let (data, _) = try await URLSession.shared.data(from: downloadURL)
                    if let loaded = UIImage(data: data) {
                        // Phase 257: Save to local ImageCacheService to warm up the cache
                        ImageCacheService.shared.saveImage(loaded, for: thumbUrlString)
                        print("[AutoCache] ✅ Thumbnail cached for \(dateId)")
                    }
                } catch {
                    print("[AutoCache] ❌ Failed to cache thumb for \(dateId): \(error)")
                }
                
                try? await Task.sleep(nanoseconds: 300_000_000) // 0.3s throttle
            }
        }
    }
    
    private func setupSocialSync() {
        // Sync current user's nickname, handle, and avatar
        pairStore.$myNickname
            .receive(on: DispatchQueue.main)
            .sink { [weak self] name in
                self?.profile.name = name.isEmpty ? "User" : name
            }
            .store(in: &cancellables)
            
        pairStore.$myAvatarPath
            .receive(on: DispatchQueue.main)
            .sink { [weak self] path in
                self?.profile.avatarPath = path
            }
            .store(in: &cancellables)
            
        pairStore.$myBirthdate
            .receive(on: DispatchQueue.main)
            .sink { [weak self] date in
                self?.profile.birthdate = date
            }
            .store(in: &cancellables)
            
        pairStore.$myAvatarUpdatedAt
            .receive(on: DispatchQueue.main)
            .sink { [weak self] date in
                self?.profile.avatarUpdatedAt = date
                
                // My own avatar sync logic
                if let uid = Auth.auth().currentUser?.uid, let path = self?.pairStore.myAvatarPath, !path.isEmpty {
                    
                    // If we have a pending image, save it to cache with the official timestamp
                    if let pending = self?.pendingAvatarImage {
                        print("[DEBUG][AvatarSync] Clearing pending. Saving to cache with OFFICIAL timestamp: \(String(describing: date))")
                        if let data = pending.jpegData(compressionQuality: 0.8) {
                            _ = try? AvatarCacheService.shared.saveAvatar(data: data, for: uid, updatedAt: date)
                        }
                        self?.pendingAvatarImage = nil
                    }
                    
                    let cached = AvatarCacheService.shared.loadAvatar(for: uid, updatedAt: date)
                    if cached == nil {
                        print("[DEBUG][AvatarSync] Own avatar cache miss. Downloading from \(path)...")
                        Task {
                            do {
                                let url = try await CloudStorageService.shared.getDownloadURL(for: path)
                                let (data, _) = try await URLSession.shared.data(from: url)
                                _ = try? AvatarCacheService.shared.saveAvatar(data: data, for: uid, updatedAt: date)
                                print("[DEBUG][AvatarSync] Own avatar Download & Cache OK")
                                // Trigger UI update (since it's an ObservableObject)
                                self?.objectWillChange.send()
                            } catch {
                                print("[ERROR][AvatarSync] Failed to download own avatar: \(error)")
                            }
                        }
                    }
                }
            }
            .store(in: &cancellables)
            
        // Sync current user's uid/handle as fallback
        if let uid = Auth.auth().currentUser?.uid {
            self.profile.handle = String(uid.prefix(6))
        }
        pairStore.$myHandle
            .receive(on: DispatchQueue.main)
            .sink { [weak self] handle in
                self?.profile.handle = handle.isEmpty ? self?.profile.handle ?? "" : handle
                
                // If this is an existing user (has handle) but onboarding flag is false, skip it
                if !handle.isEmpty && handle != "unassigned" && self?.hasCompletedOnboarding == false {
                    print("[Onboarding] Existing user detected (handle: \(handle)). Skipping onboarding.")
                    self?.hasCompletedOnboarding = true
                }
            }
            .store(in: &cancellables)
            
        pairStore.$myHandleUpdatedAt
            .receive(on: DispatchQueue.main)
            .sink { [weak self] date in
                self?.profile.handleUpdatedAt = date
            }
            .store(in: &cancellables)
            
        pairStore.$isPrivate
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isPrivate in
                self?.profile.isPrivate = isPrivate
            }
            .store(in: &cancellables)
            
        // Sync pairs from pairRefs (Filtered by blockedUids for robustness)
        Publishers.CombineLatest(pairStore.$pairRefs, pairStore.$blockedUids)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] refs, blockedIds in
                self?.pairs = refs
                    .filter { !blockedIds.contains($0.partnerUid) }
                    .map { ref in
                        PairEntry(
                            id: ref.id,
                            partnerUid: ref.partnerUid,
                            name: ref.partnerDisplayName ?? "User \(String(ref.partnerUid.prefix(4)))",
                            partnerHandle: ref.partnerHandle,
                            avatarUpdatedAt: ref.partnerAvatarUpdatedAt,
                            lastStatus: "Connected", 
                            lastActive: "Recent"
                        )
                    }
                
                // 🔥 Multi-Pair Scoping: Start today's sync for ALL active pairs
                for ref in refs where !blockedIds.contains(ref.partnerUid) {
                    self?.pairStore.startPairSync(pairId: ref.id)
                }
            }
            .store(in: &cancellables)
            
        pairStore.$pendingInviteCount
            .receive(on: DispatchQueue.main)
            .assign(to: \.pendingInviteCount, on: self)
            .store(in: &cancellables)
            
        // Phase 280: Trigger safe hydration only if local is empty or explicitly requested
        pairStore.$authUid
            .removeDuplicates()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] uid in
                guard let uid = uid else { return }
                print("[AppVM] Auth UID confirmed: \(uid). Checking local records...")
                
                // Launch Safe Check: Only auto-hydrate if local records are empty
                // Note: records property is already initialized from scanLocalDirectories in RecordsStore.init
                if self?.records.isEmpty ?? true {
                    print("[AppVM] Local records EMPTY. Triggering safety hydration...")
                    Task {
                        await self?.hydrateFromFirestore()
                    }
                } else {
                    print("[AppVM] Local records PRESENT (\(self?.records.count ?? 0)). Skipping auto-hydration.")
                }
            }
            .store(in: &cancellables)
    }

    func addEntry(image: UIImage, date: Date = Date()) {
        addWindowEntry(image: image, date: date)
    }

    private var momentSaveTask: Task<Void, Never>?
    private var currentCaptureId: String? = nil // Deprecated by draftCaptureId in Phase 208.0

    func prepareCapture(date: Date) {
        let instanceId = ObjectIdentifier(self)
        let id = FileUtils.generateCaptureId(for: date)
        
        // Phase 211.2: Strict assignment on MainActor
        Task { @MainActor in
            print("[State] draftCaptureId set reason=prepareCapture")
            self.draftCaptureId = id
            self.previewCaptureId = id // Phase 211.7: Sync preview ID
            print("[AppVM][Prepare] instanceId=\(instanceId) draftCaptureId=\(id) (Set)")
        }
    }

    func discardDraft(date: Date) {
        let instanceId = ObjectIdentifier(self)
        print("[AppVM][Discard] instanceId=\(instanceId) draftCaptureId=\(self.draftCaptureId ?? "nil")")
        
        guard let id = draftCaptureId else { 
            print("[AppVM][Discard] No draft ID to discard.")
            return 
        }
        let url = FileUtils.captureDirectoryURL(for: date, captureId: id)
        try? FileManager.default.removeItem(at: url)
        print("[Capture] 🗑️ Discarded Draft: \(id)")
        print("[State] draftCaptureId set reason=discardDraft")
        draftCaptureId = nil
    }

    func commitDraft(image: UIImage, date: Date = Date(), targetedPairId: String? = nil, camera: CameraService? = nil) {
        let instanceId = ObjectIdentifier(self)
        print("[AppVM][Commit] instanceId=\(instanceId) draftCaptureId=\(self.draftCaptureId ?? "nil")")
        
        guard let captureId = draftCaptureId else { 
            print("[ERROR][CaptureFlow] No draftCaptureId found to commit. instanceId=\(instanceId)")
            return 
        }
        
        // Phase 211.1: Do NOT clear draftCaptureId at start. 
        // Clearing is moved to the end of successful commit to ensure persistence during the async flow.

        Task(priority: .userInitiated) {
            do {
                print("[CaptureFlow] 1. Committing Draft \(captureId) & Saving Local media...")
                let shouldMirror = (camera?.currentPosition == .front)
                let relativePath = try await imageStore.savePhoto720(image: image, for: date, captureId: captureId)
                
                // Phase 257: Save thumbnail
                var thumbPath: String? = nil
                if let thumb = self.capturedThumbnail {
                    thumbPath = try? await imageStore.saveThumb320(image: thumb, for: date, captureId: captureId)
                }
                
                // [Optimistic Update] Update Store immediately to reflect "Captured" state in UI
                await MainActor.run {
                    if let targetId = targetedPairId {
                        recordsStore.upsertTargetedWindow(for: date, pairId: targetId, imagePath: relativePath, fullPath: relativePath)
                        if let tp = thumbPath {
                            recordsStore.updateTargetedWindowThumbPath(for: date, pairId: targetId, thumbPath: tp)
                        }
                        
                        // Phase 283: Persist targeted attribute in meta.json for local scanning
                        var meta: [String: Any] = [
                            "targetedPairId": targetId,
                            "updatedAt": Date().timeIntervalSince1970
                        ]
                        self.imageStore.saveMeta(json: meta, for: date, captureId: captureId)
                        
                    } else {
                        recordsStore.upsertWindow(for: date, imagePath: relativePath, shouldMirror: shouldMirror)
                        if let tp = thumbPath {
                            recordsStore.updateWindowThumbPath(for: date, thumbPath: tp)
                        }
                    }
                    recordsStore.updateSelectedCaptureId(for: date, captureId: captureId) // Anchor validation
                    
                    if self.selectedCaptureId != captureId {
                        print("[State] selectedCaptureId set reason=commitOptimistic")
                        self.selectedCaptureId = captureId
                    }
                }
                
                // Phase 270: Wait for hardware/moment state to settle
                while let cam = camera, (cam.momentState == .capturingPost || cam.momentState == .exporting) {
                    try? await Task.sleep(nanoseconds: 200_000_000)
                }

                await momentSaveTask?.value
                
                // [Finalize Local] Update local storage state immediately for the current user
                await MainActor.run {
                    let momentPath = "\(date.yyyyMMdd)/\(captureId)/moment_720.mp4"
                    if let targetId = targetedPairId {
                        recordsStore.upsertTargetedMoment(for: date, pairId: targetId, path: momentPath)
                    } else {
                        recordsStore.upsertMoment(for: date, path: momentPath)
                    }
                    imageStore.saveSelectedInfo(date: date, captureId: captureId)
                    
                    // Local UI immediate reflection (lamp on MY screen only)
                    self.updateCaptureStatus()
                    
                    print("[Commit] Local state finalized for \(captureId)")
                }
                
                print("[CaptureFlow] 3. Requesting Teardown (Prioritize Hardware Release)...")
                camera?.stopAndTeardown(source: "CaptureFlow_Commit")
                
                // Requirement 3: Delay sync for 0.8s to lower the load peak
                print("[CaptureFlow] 4. Cooling down before Cloud Sync (0.8s)...")
                try? await Task.sleep(nanoseconds: 800_000_000)
                
                print("[CaptureFlow] 5. Starting Cloud Sync...")
                let currentUid = Auth.auth().currentUser?.uid
                
                if let uid = currentUid {
                    // Phase 257/270: New centralized capture sync (Updates photo AND lamp atomically)
                    await finalizeCaptureSyncToCloud(
                        photo: image,
                        thumb: self.capturedThumbnail,
                        momentURL: FileUtils.resolveMomentURL(for: date, captureId: captureId),
                        date: date,
                        captureId: captureId,
                        targetedPairId: targetedPairId
                    )
                }
                
                print("[CaptureFlow] ✅ COMMIT DONE (Local -> Moment -> Commit -> Cloud)")
                
                // Phase 211.1: Guaranteed ID clear only after COMPLETE success
                await MainActor.run {
                    print("[State] draftCaptureId set reason=commitComplete")
                    self.draftCaptureId = nil
                }
                
            } catch {
                print("[ERROR][CaptureFlow] commit failed: \(error)")
            }
        }
    }
    
    // Legacy support for older calls if any
    func addWindowEntry(image: UIImage, date: Date = Date(), targetedPairId: String? = nil, camera: CameraService? = nil) {
        commitDraft(image: image, date: date, targetedPairId: targetedPairId, camera: camera)
    }
    
    func saveMoment(url: URL?, date: Date, metadata: [String: Any] = [:]) {
        // Phase 213.3: Use authoritative captureId from metadata if present, or fallback
        let authoritativeId = metadata["captureId"] as? String
        let captureId = authoritativeId ?? self.draftCaptureId ?? FileUtils.generateCaptureId(for: date)
        
        let instanceId = ObjectIdentifier(self)
        print("[AppVM][SaveMoment] instanceId=\(instanceId) draftCaptureId=\(self.draftCaptureId ?? "nil") authoritativeId=\(authoritativeId ?? "nil")")
        
        // Phase 211.2: Force set to property immediately (Re-confirm)
        Task { @MainActor in
            if self.draftCaptureId != captureId {
                print("[AppVM][SaveMoment] Syncing draftCaptureId: \(self.draftCaptureId ?? "nil") -> \(captureId)")
                print("[State] draftCaptureId set reason=saveMomentSync")
                self.draftCaptureId = captureId
                self.previewCaptureId = captureId // Phase 211.7: Sync preview ID
            }
        }
        
        print("[AppVM][SaveMoment] entry. instanceId=\(instanceId) captureId=\(captureId)")
        
        // Assign to property so addWindowEntry can await it
        momentSaveTask = Task(priority: .background) {
            do {
                let todayKey = date.yyyyMMdd
                var meta: [String: Any] = metadata
                meta["todayKey"] = todayKey
                meta["captureId"] = captureId
                meta["createdAt"] = ISO8601DateFormatter().string(from: Date())

                if let url = url {
                    print("[AppVM] Saving moment video (Level 1/2) to Draft: \(captureId)...")
                    let relativePath = try await self.imageStore.saveMoment(sourceURL: url, for: date, captureId: captureId)
                    
                    // Phase 206.3: Strictly extract SHA from the PHYSICAL SAVED FILE
                    let momentURL = FileUtils.resolveMomentURL(for: date, captureId: captureId)!
                    let physicalSha = FileUtils.extractFrame0SHA(from: momentURL) ?? "err_extraction_failed"
                    
                    let fm = FileManager.default
                    let attrs = try? fm.attributesOfItem(atPath: momentURL.path)
                    let size = attrs?[.size] as? Int64 ?? 0
                    let modDate = attrs?[.modificationDate] as? Date ?? Date()
                    let iso8601 = ISO8601DateFormatter().string(from: modDate)

                    meta["frame0sha"] = physicalSha
                    meta["fileSize"] = size
                    meta["modifiedAt"] = iso8601
                    meta["hasMoment"] = true
                    meta["moment"] = ["path": relativePath, "duration": 2.5]
                    
                    // Phase 285: IMPORTANT - Use saveMeta to MERGE and avoid overwriting targetedPairId
                    self.imageStore.saveMeta(json: meta, for: date, captureId: captureId)
                    
                    print("[Capture] Draft moment file saved path=\(relativePath) (NOT COMMITTED)")

                } else {
                    print("[Capture] NO moment URL provided.")
                }
                
                self.imageStore.saveMeta(json: meta, for: date, captureId: captureId)
                print("[Capture] saveMoment Draft SUCCESS. current_draftID=\(self.draftCaptureId ?? "nil")")
            } catch {
                print("[ERROR][AppVM] Failed to save moment to draft: \(error)")
            }
        }
    }
    

    
    // Phase 257: New Centralized Capture Sync (Personal & Metadata-driven)
    private func finalizeCaptureSyncToCloud(photo: UIImage, thumb: UIImage?, momentURL: URL?, date: Date, captureId: String, targetedPairId: String? = nil) {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        let dateKey = date.yyyyMMdd
        let db = Firestore.firestore()
        let docRef = db.collection("users").document(uid).collection("captures").document(dateKey)
        
        let basePath = "users/\(uid)/captures/\(dateKey)/\(captureId)"
        
        Task(priority: .background) {
            do {
                // 1. Initial metadata with "uploading" status
                try await docRef.setData([
                    "dateKey": dateKey,
                    "captureId": captureId, // Phase 257: Persist the authoritative timestamped ID
                    "capturedAt": Timestamp(date: date),
                    "createdAt": FieldValue.serverTimestamp(),
                    "updatedAt": FieldValue.serverTimestamp(),
                    "ownerUid": uid,
                    "uploadStatus": "uploading",
                    "uploadVersion": FieldValue.increment(Int64(1)),
                    "hasMoment": momentURL != nil
                ], merge: true)
                
                // 2. Upload Photo (720p)
                let photoPath = "\(basePath)/photo_720.jpg"
                let uploadedPhotoPath = try await CloudStorageService.shared.uploadImage(image: photo, path: photoPath)
                let photoURL = try await CloudStorageService.shared.getDownloadURL(for: uploadedPhotoPath)
                
                var mediaUpdate: [String: Any] = [
                    "photo": [
                        "path": uploadedPhotoPath,
                        "url": photoURL.absoluteString,
                        "w": Int(photo.size.width),
                        "h": Int(photo.size.height),
                        "bytes": photo.jpegData(compressionQuality: 0.8)?.count ?? 0
                    ]
                ]
                
                // 3. Upload Thumbnail (320p)
                if let thumb = thumb {
                    let thumbPath = "\(basePath)/thumb_320.jpg"
                    let uploadedThumbPath = try await CloudStorageService.shared.uploadImage(image: thumb, path: thumbPath)
                    let thumbURL = try await CloudStorageService.shared.getDownloadURL(for: uploadedThumbPath)
                    mediaUpdate["thumb"] = [
                        "path": uploadedThumbPath,
                        "url": thumbURL.absoluteString,
                        "w": Int(thumb.size.width),
                        "h": Int(thumb.size.height),
                        "bytes": thumb.jpegData(compressionQuality: 0.8)?.count ?? 0
                    ]
                }
                
                // 4. Upload Moment (720p)
                if let mURL = momentURL, FileManager.default.fileExists(atPath: mURL.path) {
                    let momentPath = "\(basePath)/moment_720.mp4"
                    let uploadedMomentPath = try await CloudStorageService.shared.uploadFile(localURL: mURL, path: momentPath, contentType: "video/mp4")
                    let momentURL = try await CloudStorageService.shared.getDownloadURL(for: uploadedMomentPath)
                    mediaUpdate["moment"] = [
                        "path": uploadedMomentPath,
                        "url": momentURL.absoluteString,
                        "durationSec": 3,
                        "bytes": (try? FileManager.default.attributesOfItem(atPath: mURL.path)[.size] as? Int) ?? 0
                    ]
                }
                
                // 5. Finalize Metadata
                mediaUpdate["uploadStatus"] = "uploaded"
                mediaUpdate["updatedAt"] = FieldValue.serverTimestamp()
                
                try await docRef.setData(mediaUpdate, merge: true)
                print("[Sync] ✅ Firestore metadata updated for \(dateKey)")
                
                // 6. Final atomic update: Photos & Weekly Lamp
                // This makes photos appear AND turns lamps green for all partners simultaneously.
                let finalThumbPath = (mediaUpdate["thumb"] as? [String: Any])?["path"] as? String
                let finalPhotoPath = (mediaUpdate["photo"] as? [String: Any])?["path"] as? String
                let finalMomentPath = (mediaUpdate["moment"] as? [String: Any])?["path"] as? String
                if let finalPhotoPath = finalPhotoPath {
                    if let targetId = targetedPairId {
                        // Targeted Mode: Only update the specific pair
                        await pairStore.markMyWindowCaptured(
                            pairId: targetId,
                            thumbPath: finalThumbPath,
                            fullPath: finalPhotoPath,
                            momentPath: finalMomentPath,
                            isTargeted: true
                        )
                        // Phase 285: Even targeted photos contribute to weekly "Activity Done" status
                        try? await pairStore.updateWeeklyProgress(pairId: targetId, date: date)
                        await pairStore.addWeeklyPhotoRef(pairId: targetId, date: date, thumbPath: finalThumbPath ?? finalPhotoPath, fullPath: finalPhotoPath)
                    } else {
                        // Public/Global Mode: Update all pairs
                        for ref in pairStore.pairRefs {
                            // Priority 1: Image visibility
                            await pairStore.markMyWindowCaptured(
                                pairId: ref.id,
                                thumbPath: finalThumbPath,
                                fullPath: finalPhotoPath,
                                momentPath: finalMomentPath,
                                isTargeted: false
                            )
                            
                            // Priority 2: Weekly Progress (Lamp)
                            // Moving this inside the upload completion ensures WYSIWYG for partners
                            try? await pairStore.updateWeeklyProgress(pairId: ref.id, date: date)
                            
                            // Phase 93: Track weekly photo refs
                            await pairStore.addWeeklyPhotoRef(pairId: ref.id, date: date, thumbPath: finalThumbPath ?? finalPhotoPath, fullPath: finalPhotoPath)
                        }
                    }
                }
                
                // Finalize local state
                await MainActor.run {
                    self.recordsStore.markAsShared(for: date)
                }
                
            } catch {
                print("[Sync] ❌ Failed to sync to cloud: \(error)")
                try? await docRef.setData(["uploadStatus": "failed"], merge: true)
            }
        }
    }

    private func syncWindowToCloud(image: UIImage, pairId: String, uid: String, date: Date, momentURL: URL? = nil, memo: String? = nil) {
        let todayKey = date.yyyyMMdd
        let syncKey = "\(pairId)_\(todayKey)"
        
        // Phase 400: Guard against duplicate concurrent syncs for the same day/pair
        if inProgressUploads.contains(syncKey) {
            print("[Sync][Skip] Sync already in progress for \(syncKey)")
            return
        }
        inProgressUploads.insert(syncKey)
        
        let pathBase = "pairs/\(pairId)/daily/\(todayKey)/\(uid)/window"
        let momentPathBase = "pairs/\(pairId)/daily/\(todayKey)/\(uid)/moment_720.mp4"

        Task {
            defer {
                inProgressUploads.remove(syncKey)
            }
            do {
                // 1. Upload Movie if available
                var uploadedMomentPath: String? = nil
                if let mURL = momentURL {
                    uploadedMomentPath = try? await CloudStorageService.shared.uploadFile(localURL: mURL, path: momentPathBase, contentType: "video/quicktime")
                }

                // 2. Upload Images
                let (fullPath, thumbPath) = try await CloudStorageService.shared.uploadImagePair(image: image, pathBase: pathBase)
                
                await pairStore.markMyWindowCaptured(pairId: pairId, thumbPath: thumbPath, fullPath: fullPath, momentPath: uploadedMomentPath, memo: memo)

                // Add to Weekly Photo Ref (Phase 93)
                await pairStore.addWeeklyPhotoRef(pairId: pairId, date: date, thumbPath: thumbPath, fullPath: fullPath)

                // Mark as shared in local records
                await MainActor.run {
                    self.recordsStore.markAsShared(for: date)
                }
            } catch {
                print("[ERROR][WindowSync] Cloud upload FAILED for pairId=\(pairId): \(error.localizedDescription)")
                // Fallback attempt with single path if pair upload fails (legacy behavior)
                // (Keeping simple fallback for now, omitting moment for fallback to keep it simple)
                let cloudPath = "\(pathBase).jpg"
                if let uploadedPath = try? await CloudStorageService.shared.uploadImage(image: image, path: cloudPath) {
                    await pairStore.markMyWindowCaptured(pairId: pairId, thumbPath: nil, fullPath: uploadedPath)
                    await pairStore.addWeeklyPhotoRef(pairId: pairId, date: date, thumbPath: uploadedPath, fullPath: uploadedPath)
                    await MainActor.run {
                        self.recordsStore.markAsShared(for: date)
                    }
                }
            }
        }
    }
    
    func checkAndBackfillDailySync() {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        let activePairs = pairStore.pairRefs
        if activePairs.isEmpty { return }
        
        // Phase 400: Prevent duplicate backfill loops
        if isBackfilling {
            print("[Sync] Backfill already in progress. Skipping.")
            return
        }
        isBackfilling = true

        Task(priority: .background) {
            defer { isBackfilling = false }
            // Filter all records that have a window but are NOT shared yet
            let pendingEntries = records.values
                .filter { $0.hasWindow && !$0.isShared }
                .sorted { $0.id > $1.id } // Newest first

            if pendingEntries.isEmpty { return }
            print("[Sync] Found \(pendingEntries.count) unshared historical records. Starting background backfill...")

            for entry in pendingEntries {
                guard let date = DateFormatter.yyyyMMdd.date(from: entry.id) else { continue }
                
                // Safety check: verify local file exists before attempting upload
                if let path = entry.windowImagePath, let image = loadImage(path: path) {
                    print("[Sync] Backfilling unshared photo/video: \(entry.id)")
                    
                    // Check for video (moment.mov) in both legacy and new structure
                    var momentURL: URL? = nil
                    let fm = FileManager.default
                    let captureId = entry.selectedCaptureId ?? ""
                    let movieURL = FileUtils.resolveMomentURL(for: date, captureId: captureId)
                    let legacyMovieURL = FileUtils.resolveMomentURL(for: date, captureId: "") // Old structure
                    
                    if let url = movieURL, fm.fileExists(atPath: url.path) {
                        momentURL = url
                    } else if let lUrl = legacyMovieURL, fm.fileExists(atPath: lUrl.path) {
                        momentURL = lUrl
                    }

                    for pair in activePairs {
                        syncWindowToCloud(image: image, pairId: pair.id, uid: uid, date: date, momentURL: momentURL, memo: entry.memo)
                    }
                    
                    // Throttle: Wait 1.0s between historical uploads to reduce burst load
                    try? await Task.sleep(nanoseconds: 1_000_000_000)
                } else {
                    print("[Sync] ⚠️ Skipping backfill for \(entry.id): Local file missing.")
                }
            }
            print("[Sync] Background backfill completed.")
        }
    }
    
    // MARK: - Actions
    
    func loadAvatar(uid: String, updatedAt: Date?) -> UIImage? {
        let currentUid = Auth.auth().currentUser?.uid ?? ""
        
        // 1. If it's my own avatar and we have a pending update, show it
        if uid == currentUid, let pending = pendingAvatarImage {
            return pending
        }
        
        // 2. Load from cache
        if let cached = AvatarCacheService.shared.loadAvatar(for: uid, updatedAt: updatedAt) {
            return cached
        }
        
        return nil
    }

    /// Fetches avatar from Storage if missing in cache and triggers an update
    func ensureAvatarCached(uid: String, path: String?, updatedAt: Date?) async {
        guard let path = path, !path.isEmpty else { return }
        
        // Skip if already in cache
        if AvatarCacheService.shared.loadAvatar(for: uid, updatedAt: updatedAt) != nil {
            return
        }
        
        do {
            print("[DEBUG][AvatarSync] Cache miss for \(uid). Downloading from \(path)...")
            let url = try await CloudStorageService.shared.getDownloadURL(for: path)
            let (data, _) = try await URLSession.shared.data(from: url)
            _ = try AvatarCacheService.shared.saveAvatar(data: data, for: uid, updatedAt: updatedAt)
            print("[DEBUG][AvatarSync] Download & Cache OK for \(uid)")
            
            // Trigger UI update
            await MainActor.run {
                self.objectWillChange.send()
            }
        } catch {
            print("[ERROR][AvatarSync] Failed to fetch/cache avatar for \(uid): \(error)")
        }
    }

    func uploadAvatar(_ image: UIImage) {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        
        // Update UI immediately
        DispatchQueue.main.async {
            self.pendingAvatarImage = image
            self.objectWillChange.send()
        }
        
        Task {
            do {
                print("[DEBUG][AvatarUpload] START upload for \(uid)")
                // 1. Upload to Storage (returns both full and thumb)
                let (fullPath, thumbPath) = try await CloudStorageService.shared.uploadAvatar(image: image, uid: uid)
                print("[DEBUG][AvatarUpload] Storage OK: thumb=\(thumbPath)")
                
                // 2. Update Firestore with both paths
                try await pairStore.updateAvatarMetadata(fullPath: fullPath, thumbPath: thumbPath)
                print("[DEBUG][AvatarUpload] Firestore OK. Waiting for sync to clear pending...")
                
                // Note: We don't clear pendingAvatarImage immediately.
                // We'll let the Firestore listener in setupSocialSync handle the transition.
                // But we should ensure the cache is saved with the correct timestamp when it arrives.
                
            } catch {
                print("[ERROR][AvatarUpload] Failed: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    self.pendingAvatarImage = nil
                }
            }
        }
    }

    func updateNickname(_ name: String) {
        Task {
            try? await pairStore.updateNickname(name)
        }
    }
    
    func togglePrivacy() {
        let newStatus = !profile.isPrivate
        Task {
            try? await pairStore.updatePrivacy(isPrivate: newStatus)
            await MainActor.run {
                self.profile.isPrivate = newStatus
                self.objectWillChange.send()
            }
        }
    }
    
    func finishOnboarding(draft: OnboardingDraft) async throws {
        print("[AppViewModel] finishOnboarding START. uid=\(Auth.auth().currentUser?.uid ?? "nil")")
        
        // 0. Ensure Auth is actually ready. If not, wait or throw early.
        if Auth.auth().currentUser == nil {
            print("[AppViewModel] finishOnboarding Error: No current user. Attempting to ensure signed in...")
            await sessionStore.ensureSignedIn()
            if Auth.auth().currentUser == nil {
                print("[AppViewModel] finishOnboarding Error: Still no user after ensureSignedIn.")
                // Throw error to trigger UI catch
                throw PairStore.PairError.authUnavailable
            }
        }

        // 1. Update Profile (Nickname & Handle)
        try await pairStore.updateProfile(nickname: draft.nickname, handle: draft.handle)
        
        // 2. Update Birthdate
        try await pairStore.updateBirthdate(draft.birthday)
        
        // 3. Upload Avatar if exists
        if let image = draft.avatarImage {
            // Upload to Storage (returns both full and thumb) & Update Firestore
            let (fullPath, thumbPath) = try await CloudStorageService.shared.uploadAvatar(image: image, uid: Auth.auth().currentUser?.uid ?? "")
            try await pairStore.updateAvatarMetadata(fullPath: fullPath, thumbPath: thumbPath)
            
            // Sync to local cache
            await MainActor.run {
                self.pendingAvatarImage = image
            }
        }
        
        // 4. Set completed
        await MainActor.run {
            print("[AppViewModel] finishOnboarding SUCCESS. Setting hasCompletedOnboarding = true")
            withAnimation(.spring()) {
                self.hasCompletedOnboarding = true
                self.showForceOnboarding = false
            }
        }
    }
    
    func updateBirthdate(_ date: Date) {
        Task {
            try? await pairStore.updateBirthdate(date)
        }
    }
    

    func updateMemo(date: Date, memo: String) {
        let dateId = date.yyyyMMdd
        recordsStore.updateMemo(for: date, memo: memo)
        
        // Only update remote if paired
        if let _ = pairStore.pairRefs.first?.id {
            Task {
                await pairStore.updateMyMemo(dateId: dateId, memo: memo)
            }
        }
    }

    func updateTargetedMemo(date: Date, pairId: String? = nil, memo: String) {
        let dateId = date.yyyyMMdd
        let pId = pairId ?? targetedPairId ?? pairStore.pairRefs.first?.id
        
        recordsStore.updateTargetedMemo(for: date, pairId: pId, memo: memo)
        
        if let pairId = pId {
            Task {
                await pairStore.updateMyTargetedMemo(pairId: pairId, dateId: dateId, memo: memo)
            }
        }
    }
    
    func updateRating(dateId: String, rating: Int) {
        guard let date = DateFormatter.yyyyMMdd.date(from: dateId) else { return }
        
        // 1. Update local
        recordsStore.updateRating(for: date, rating: rating)
        
        // 2. Update remote
        if let pairId = pairStore.pairRefs.first?.id {
            Task {
                await pairStore.updateMyRating(pairId: pairId, dateId: dateId, rating: rating)
            }
        }
    }

    func resetAllRatings() {
        let dateIds = records.keys.sorted()
        
        // 1. Reset all local
        for dateId in dateIds {
            if let date = DateFormatter.yyyyMMdd.date(from: dateId) {
                recordsStore.updateRating(for: date, rating: -1)
            }
        }
        
        // 2. Reset remote
        if let pairId = pairStore.pairRefs.first?.id {
            Task {
                await pairStore.resetRatings(pairId: pairId, dateIds: dateIds)
            }
        }
    }
    
    func deletePhoto(date: Date) async throws {
        let dateId = date.yyyyMMdd
        print("[DEBUG][DeletePhoto] Starting deletion for \(dateId)...")
        
        // --- Phase 257: Clean up the new centralized cloud storage ---
        if let uid = Auth.auth().currentUser?.uid {
            let db = Firestore.firestore()
            let dateKey = date.yyyyMMdd
            
            // 1. Storage Cleanup (New architecture)
            let basePath = "users/\(uid)/captures/\(dateKey)"
            let storage = CloudStorageService.shared
            
            // Delete files in parallel (Allow failure if already missing)
            _ = try? await storage.deleteImage(path: "\(basePath)/photo_720.jpg")
            _ = try? await storage.deleteImage(path: "\(basePath)/thumb_320.jpg")
            _ = try? await storage.deleteImage(path: "\(basePath)/moment_720.mp4")
            
            // 2. Firestore Cleanup (New architecture)
            try? await db.collection("users").document(uid).collection("captures").document(dateKey).delete()
            print("[DEBUG][DeletePhoto] New architecture cloud cleanup DONE for \(dateKey)")
        }
        
        // 1. Delete local record and file
        recordsStore.removeRecord(for: date)
        
        // 1.5 Delete physical files to prevent auto-restore on relaunch
        imageStore.forceCleanupDayDirectory(for: date)
        
        // 2. Delete from Firebase (Updates both user log and all pair logs)
        try await pairStore.deleteMyWindowPhoto(date: date)

        // 3. Recalculate UI state
        updateCaptureStatus()
        print("[DEBUG][DeletePhoto] All deletion steps completed for \(dateId)")
    }
    
    /// Phase 300: Toggle between Public and Private for a specific capture
    func updatePhotoPrivacy(date: Date, isPrivate: Bool) async {
        let dateId = date.yyyyMMdd
        
        // 1. Update local recordsStore
        if var record = records[dateId] {
            record.isPrivate = isPrivate
            recordsStore.upsertRecord(record)
            
            await MainActor.run {
                self.records[dateId] = record
            }
        }
        
        // 2. Update Firestore and social state
        await pairStore.togglePhotoPrivacy(dateId: dateId, isPrivate: isPrivate)
    }

    
    func signOut() {
        do {
            try Auth.auth().signOut()
            
            // 1. Wipe local data completely
            imageStore.clearAllData()
            recordsStore.clearAllData()
            pairStore.resetAllData()
            
            // 2. Reset VM state
            self.profile = UserProfile(name: "User", handle: "unassigned")
            self.hasCompletedOnboarding = false
            self.pairs = []
            self.records = [:]
            self.isCapturedToday = false
            self.isWindowCapturedToday = false
            
            // Clean up notifications on sign out
            NotificationService.shared.cancelDailyReminder()
            
            print("[AppVM] Sign out completed and local data wiped.")
        } catch {
            print("Error signing out: \(error)")
        }
    }
    
    func updateNotificationSchedule() {
        if isDailyReminderEnabled {
            let date = Date(timeIntervalSince1970: reminderTime)
            NotificationService.shared.scheduleDailyReminder(at: date)
        } else {
            NotificationService.shared.cancelDailyReminder()
        }
    }
    
    func deleteAccount() {
        Task {
            do {
                guard let uid = Auth.auth().currentUser?.uid else { return }
                
                print("[DEBUG][AccountDelete] Requesting deletion for \(uid)... (Grace period active)")
                
                // Set the deletion request timestamp and TTL expiry
                let expireAt = Calendar.current.date(byAdding: .day, value: 30, to: Date()) ?? Date().addingTimeInterval(30 * 24 * 3600)
                try await Firestore.firestore().collection("users").document(uid).setData([
                    "deletionRequestedAt": FieldValue.serverTimestamp(),
                    "expireAt": Timestamp(date: expireAt)
                ], merge: true)
                
                // Sign Out immediately
                signOut()
                
            } catch {
                print("[ERROR][AccountDelete] Deletion request failed: \(error.localizedDescription)")
            }
        }
    }
    
    var notificationDetail: String {
        if isDailyReminderEnabled {
            let date = Date(timeIntervalSince1970: reminderTime)
            let formatter = DateFormatter()
            formatter.timeStyle = .short
            return formatter.string(from: date)
        } else {
            return "Off"
        }
    }
    
    #if DEBUG
    func debugResetCaptureUI() {
        print("[DEBUG][AppVM] debugResetCaptureUI: Toggling UI state to NOT captured.")
        self.isCapturedToday = false
        self.objectWillChange.send()
    }
    
    
    func debugResetToday() {
        Task {
            print("[DEBUG][AppVM] debugResetToday STARTING...")
            
            // 1. Perform Comprehensive Hard Reset (Firestore/Storage/Local/Cache)
            recordsStore.debugHardResetToday()
            
            // 2. Clear Local Image Directory
            imageStore.forceCleanupDayDirectory(for: Date())
            
            // 3. Sync and Refresh UI
            await MainActor.run {
                self.isCapturedToday = false
                self.isWindowCapturedToday = false
                self.objectWillChange.send()
                print("[DEBUG][AppVM] debugResetToday DONE.")
            }
        }
    }
    #endif
    
    // MARK: - Computed Properties
    
    var sortedEntries: [DayRecord] {
        records.values
            .filter { $0.hasAnyWindow && !pairStore.isTombstoned($0.id) } // Guard: Hide if tombstoned
            .sorted { $0.id > $1.id }
    }
    
    /// Phase 298: Earliest record date for main calendar limiting
    var firstRecordDate: String {
        records.keys.filter { !$0.contains("_") }.sorted().first ?? Date().yyyyMMdd
    }
    
    var sortedEntriesAsc: [DayRecord] {
        records.values
            .filter { $0.hasAnyWindow && !pairStore.isTombstoned($0.id) }
            .sorted { $0.id < $1.id }
    }
    
    var currentStreak: Int {
        guard !records.isEmpty else { return 0 }
        let calendar = Calendar.current
        var streak = 0
        var checkDate = Date()
        if records[Date().yyyyMMdd] == nil {
            checkDate = calendar.date(byAdding: .day, value: -1, to: checkDate) ?? Date()
        }
        while let record = records[checkDate.yyyyMMdd], record.hasAnyWindow {
            streak += 1
            guard let nextCheck = calendar.date(byAdding: .day, value: -1, to: checkDate) else { break }
            checkDate = nextCheck
        }
        return streak
    }
    
    var monthlyHomeCount: Int {
        let currentYearMonth = Date().yyyyMMdd.prefix(7)
        return records.keys.filter { $0.hasPrefix(currentYearMonth) }.count
    }

    var unratedCount: Int {
        records.values.filter { $0.hasAnyWindow && $0.rating == -1 }.count
    }
    
    var averageRating: Double {
        let rated = records.values
            .filter { $0.hasAnyWindow && $0.rating >= 0 }
            .sorted { $0.id > $1.id }
            .prefix(30)
            .map { Double($0.rating) }
        
        guard !rated.isEmpty else { return 0.0 }
        return rated.reduce(0, +) / Double(rated.count)
    }
    
    func entry(on date: Date) -> DayRecord? {
        records[date.yyyyMMdd]
    }
    
    var lastCapturedImage: UIImage? {
        let sorted = sortedEntries.filter { $0.hasWindow }
        guard let latest = sorted.first else { return nil }
        
        // 今日撮影済みの場合は、その1つ前の写真を取得（撮影の基準にするため）
        if latest.id == Date().yyyyMMdd {
            if sorted.count > 1 {
                return loadImage(path: sorted[1].windowImagePath ?? "")
            }
            return nil
        }
        
        return loadImage(path: latest.windowImagePath ?? "")
    }
    
    func loadImage(path: String) -> UIImage? {
        // Guard: if the path belongs to a tombstoned/deleted day, do not load
        let components = path.split(separator: "/")
        if let key = components.first(where: { $0.count == 8 || ($0.count == 10 && $0.contains("-")) }) {
            let normalized = String(key).replacingOccurrences(of: "-", with: "")
            if pairStore.isTombstoned(normalized) {
                print("[LoadImage] Blocking load for deleted date: \(normalized)")
                return nil
            }
        }
        return imageStore.loadImage(at: path)
    }

    func updateCaptureStatus() {
        let today = Date()
        
        let todayRecord = recordsStore.record(for: today)
        let hasLocalWindow = todayRecord?.hasWindow ?? false
        
        // Remote Check
        let hasRemoteWindow = pairStore.myToday.windowDidCapture
        
        DispatchQueue.main.async {
            let selected = todayRecord?.selectedCaptureId
            if self.selectedCaptureId != selected {
                print("[State] selectedCaptureId set reason=updateCaptureStatus todayRecord=\(todayRecord?.id ?? "nil") selected=\(selected ?? "nil")")
                self.selectedCaptureId = selected
            }

            let newVal = hasLocalWindow || hasRemoteWindow

            if self.isCapturedToday != newVal {
                if newVal && self.pairStore.isClearingWindowPhoto {
                    print("[DEBUG][AppVM] isCapturedToday BLOCKED by isClearingWindowPhoto")
                } else {
                    print("[DEBUG][AppVM] isCapturedToday updated: \(newVal)")
                    self.isCapturedToday = newVal
                }
            }

            if self.isWindowCapturedToday != newVal {
                if newVal && self.pairStore.isClearingWindowPhoto {
                    print("[DEBUG][AppVM] isWindowCapturedToday BLOCKED by isClearingWindowPhoto")
                } else {
                    print("[DEBUG][AppVM] isWindowCapturedToday updated: \(newVal)")
                    self.isWindowCapturedToday = newVal
                }
            }
        }
    }
    
    func fullSyncAndRestore() async {
        await hydrateFromFirestore()
        await self.autoRestoreMissingRecords()
        self.autoCacheLatestThumbnails()
    }
    
    /// Phase 280: Centralized Hydration (Single Source of Truth restoration)
    /// This is a heavy operation, only called on sign-in or when local records are empty.
    func hydrateFromFirestore() async {
        guard !isHydrating else {
            print("[Hydration] Already in progress, skipping.")
            return
        }
        
        // Guard: Only allow once per session unless forced or explicitly needed
        if isHydrated {
            print("[Hydration] Already hydrated in this session.")
            return
        }

        isHydrating = true
        defer { isHydrating = false }

        guard let uid = Auth.auth().currentUser?.uid ?? pairStore.authUid else { return }
        print("[Hydration] Starting Firestore Hydration for UID: \(uid)...")

        let db = Firestore.firestore()
        let capturesRef = db.collection("users").document(uid).collection("captures")

        do {
            let snapshot = try await capturesRef.getDocuments()
            print("[Hydration] Found \(snapshot.documents.count) records in Firestore.")
            
            // Fail-Safe: If remote is empty, do NOT wipe local
            if snapshot.documents.isEmpty {
                print("[Hydration] Firestore is empty. Maintaining local records.")
                isHydrated = true
                return
            }

            for doc in snapshot.documents {
                let dateKey = doc.documentID
                let data = doc.data()
                guard let date = DateFormatter.yyyyMMdd.date(from: dateKey) else { continue }
                
                let local = recordsStore.record(for: date)
                if let merged = mergeRemoteDataIntoRecord(local: local, remote: data, dateKey: dateKey) {
                    recordsStore.upsertRecord(merged)
                    
                    // Phase 284: Proactively cache ALL missing media (Public + Targeted)
                    self.ensureImageDownloaded(for: date)
                    self.ensureMomentDownloaded(for: date)
                }
            }
            
            isHydrated = true
            print("[Hydration] ✅ Success. Merged \(snapshot.documents.count) records.")
            
            await MainActor.run {
                self.updateCaptureStatus()
            }
        } catch {
            print("[Hydration] ❌ Error: \(error.localizedDescription)")
            // Fail-Safe: On error, records are kept intact
        }
    }

    /// Phase 280: Local-First Merge Strategy
    private func mergeRemoteDataIntoRecord(local: DayRecord?, remote: [String: Any], dateKey: String) -> DayRecord? {
        var record = local ?? DayRecord(id: dateKey)
        var changed = false
        
        // 1. Photo URL & Metadata (Only update if local doesn't have a path)
        if let photo = remote["photo"] as? [String: Any], let url = photo["url"] as? String {
            if record.windowPhotoUrl != url {
                record.windowPhotoUrl = url
                changed = true
            }
        }
        
        // 2. Thumb URL
        if let thumb = remote["thumb"] as? [String: Any], let url = thumb["url"] as? String {
            if record.windowThumbPath != url {
                record.windowThumbPath = url
                changed = true
            }
        }
        
        // 3. Moment URL
        if let moment = remote["moment"] as? [String: Any], let url = moment["url"] as? String {
            // Only update if local path is missing OR it's currently a URL
            if record.momentPath == nil || record.momentPath?.hasPrefix("http") == true {
                if record.momentPath != url {
                    record.momentPath = url
                    changed = true
                }
            }
        }
        
        // 4. Capture ID (Index anchor)
        if let cid = remote["captureId"] as? String {
            // If local doesn't have a file, sync the ID to know where to download
            if record.selectedCaptureId != cid && record.windowImagePath == nil {
                record.selectedCaptureId = cid
                changed = true
            }
        }
        
        // 5. CapturedAt
        if let ts = remote["capturedAt"] as? Timestamp {
            let remoteDate = ts.dateValue()
            if record.windowCapturedAt == nil || abs(record.windowCapturedAt?.timeIntervalSince(remoteDate) ?? 0) > 1 {
                record.windowCapturedAt = remoteDate
                changed = true
            }
        }
        
        // 6. User inputs (Memo/Rating)
        if record.memo == nil || record.memo?.isEmpty == true {
            if let m = remote["memo"] as? String {
                record.memo = m
                changed = true
            }
        }

        if record.rating == -1 {
            if let r = remote["rating"] as? Int {
                record.rating = r
                changed = true
            }
        }

        return changed ? record : (local == nil ? record : nil)
    }
    
    // Phase 280: Improved download logic with captureId hierarchy awareness
    func ensureImageDownloaded(for date: Date) {
        let dateKey = date.yyyyMMdd
        guard let record = records[dateKey] else { return }
        
        let fm = FileManager.default
        let appSupport = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        
        // Internal helper to download a single item
        func download(urlString: String, captureId: String, isTargeted: Bool, pairId: String?) {
            guard let url = URL(string: urlString) else { return }
            let destURL = appSupport.appendingPathComponent("StillMe/records/\(dateKey)/\(captureId)/photo_720.jpg")
            let relativePath = "\(dateKey)/\(captureId)/photo_720.jpg"
            
            if fm.fileExists(atPath: destURL.path) {
                updateRecord(isTargeted: isTargeted, pairId: pairId, relativePath: relativePath)
                return
            }
            
            Task(priority: .background) {
                do {
                    print("[AppVM] Downloading image (\(isTargeted ? "🔒" : "🌐")): \(relativePath)")
                    let (data, _) = try await URLSession.shared.data(from: url)
                    try fm.createDirectory(at: destURL.deletingLastPathComponent(), withIntermediateDirectories: true)
                    try data.write(to: destURL, options: .atomic)
                    
                    await MainActor.run {
                        updateRecord(isTargeted: isTargeted, pairId: pairId, relativePath: relativePath)
                        print("[AppVM] ✅ Image download SUCCESS: \(relativePath)")
                    }
                } catch {
                    print("[AppVM] ❌ Image download FAIL: \(error)")
                }
            }
        }
        
        func updateRecord(isTargeted: Bool, pairId: String?, relativePath: String) {
            guard var updated = self.records[dateKey] else { return }
            if isTargeted, let pid = pairId {
                var s = updated.targetedCaptures[pid] ?? TargetedStatus()
                s.windowImagePath = relativePath
                updated.targetedCaptures[pid] = s
            } else {
                updated.windowImagePath = relativePath
            }
            self.recordsStore.upsertRecord(updated)
        }
        
        // 1. Check Public Photo
        if let url = record.windowPhotoUrl, record.windowImagePath == nil {
            let cid = record.selectedCaptureId ?? "restored"
            download(urlString: url, captureId: cid, isTargeted: false, pairId: nil)
        }
        
        // 2. Check Targeted Photos
        for (pid, status) in record.targetedCaptures {
            if let url = status.windowPhotoUrl, status.windowImagePath == nil {
                // Determine captureId from URL or fallback
                let cid = url.contains("/") ? (url.components(separatedBy: "/").last?.split(separator: "_").first.map(String.init) ?? "restored") : "restored"
                // Actually, Storage path structure: users/{uid}/captures/{date}/{cid}/photo_720.jpg
                // A more reliable way is to extract the CID from the path segment before the file name.
                let extractedCid = url.components(separatedBy: "/").dropLast().last ?? "restored"
                
                download(urlString: url, captureId: extractedCid, isTargeted: true, pairId: pid)
            }
        }
    }

    func ensureMomentDownloaded(for date: Date) {
        let dateKey = date.yyyyMMdd
        guard let record = records[dateKey] else { return }
        
        let fm = FileManager.default
        let appSupport = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        
        func download(urlString: String, captureId: String, isTargeted: Bool, pairId: String?) {
            guard let url = URL(string: urlString) else { return }
            let destURL = appSupport.appendingPathComponent("StillMe/records/\(dateKey)/\(captureId)/moment_720.mp4")
            let relativePath = "\(dateKey)/\(captureId)/moment_720.mp4"
            
            if fm.fileExists(atPath: destURL.path) {
                updateRecord(isTargeted: isTargeted, pairId: pairId, relativePath: relativePath)
                return
            }
            
            Task(priority: .background) {
                do {
                    print("[AppVM] Downloading moment (\(isTargeted ? "🔒" : "🌐")): \(relativePath)")
                    let (data, _) = try await URLSession.shared.data(from: url)
                    try fm.createDirectory(at: destURL.deletingLastPathComponent(), withIntermediateDirectories: true)
                    try data.write(to: destURL, options: .atomic)
                    
                    await MainActor.run {
                        updateRecord(isTargeted: isTargeted, pairId: pairId, relativePath: relativePath)
                        print("[AppVM] ✅ Moment download SUCCESS: \(relativePath)")
                    }
                } catch {
                    print("[AppVM] ❌ Moment download FAIL: \(error)")
                }
            }
        }
        
        func updateRecord(isTargeted: Bool, pairId: String?, relativePath: String) {
            guard var updated = self.records[dateKey] else { return }
            if isTargeted, let pid = pairId {
                var s = updated.targetedCaptures[pid] ?? TargetedStatus()
                s.momentPath = relativePath
                updated.targetedCaptures[pid] = s
            } else {
                updated.momentPath = relativePath
            }
            self.recordsStore.upsertRecord(updated)
        }
        
        // 1. Check Public Moment
        if let url = record.momentPath, url.hasPrefix("http"), record.momentPath == nil || record.momentPath!.hasPrefix("http") {
            let cid = record.selectedCaptureId ?? "restored"
            download(urlString: url, captureId: cid, isTargeted: false, pairId: nil)
        }
        
        // 2. Check Targeted Moments
        for (pid, status) in record.targetedCaptures {
            if let url = status.momentPath, url.hasPrefix("http") {
                let extractedCid = url.components(separatedBy: "/").dropLast().last ?? "restored"
                download(urlString: url, captureId: extractedCid, isTargeted: true, pairId: pid)
            }
        }
    }

    var totalPhotos: Int {
        get {
            records.values.filter { $0.hasWindow }.count
        }
    }
}

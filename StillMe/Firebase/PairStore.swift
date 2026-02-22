import Foundation
import Combine
import SwiftUI
import FirebaseAuth
import FirebaseFirestore

@MainActor
final class PairStore: ObservableObject {
    static let shared = PairStore()

    // MARK: - Auth
    @Published var authUid: String? = nil
    private var authListener: AuthStateDidChangeListenerHandle? = nil

    // MARK: - Firestore listeners
    private var inboxListener: ListenerRegistration? = nil
    private var outboxListener: ListenerRegistration? = nil
    private var pairRefsListener: ListenerRegistration? = nil
    private var pairRefsFetchToken: UUID = UUID()
    private var nicknameFetchTask: Task<Void, Never>? = nil

    // MARK: - Listener diagnostics
    private var inboxListenTick: Int = 0
    private var outboxListenTick: Int = 0

    // MARK: - Display name cache
    private var nameCache: [String: String] = [:]
    private var cacheUpdatedAt: [String: Date] = [:]
    private var inflightNameFetch: [String: Task<String, Error>] = [:]

    // MARK: - Notice debounce
    private var lastNotice: (msg: String, at: Date)? = nil

    // MARK: - Errors
    enum PairError: Error {
        case invalidHandle
        case alreadyHasHandle
        case handleTaken
        case authUnavailable
        case unknown
        case handleNotFound
        case invalidUserDoc
        case maxPairsReached
        case alreadyPairedWithSameUser
        case alreadyProcessed
        case alreadyPaired
        case forbidden
        case coolingDown
        case alreadyHasInvite
    }

    // MARK: - Profile
    struct Profile {
        enum Status: String { case none, invited, paired }
        var status: Status = .none
        var partnerName: String = ""
        var inviteCode: String? = nil
        var myId: String = ""
    }

    @Published var profile: Profile = .init()
    @Published var myNickname: String = ""
    @Published var myHandle: String = ""
    @Published var myHandleUpdatedAt: Date? = nil
    @Published var myAvatarPath: String = ""
    @Published var myAvatarUpdatedAt: Date? = nil
    @Published var myBirthdate: Date? = nil
    @Published var isPrivate: Bool = false
    private var myProfileListener: ListenerRegistration? = nil

    // MARK: - PairView compatibility state
    struct InviteItem: Identifiable, Equatable {
        var id: String
        var fromUid: String
        var toUid: String
        var status: String
        var createdAt: Date?
    }

    struct PairRefItem: Identifiable, Equatable {
        var id: String
        var partnerUid: String
        var partnerDisplayName: String?
        var partnerAvatarPath: String?
        var partnerAvatarUpdatedAt: Date?
        var partnerHandle: String?
        var createdAt: Date?
    }

    @Published var inbox: [InviteItem] = []
    @Published var outbox: [InviteItem] = []
    @Published var pairRefs: [PairRefItem] = []
    @Published var blockedUids: [String] = []
    @Published var hiddenPairIds: [String] = []
    @Published var mutedUids: [String] = []
    
    // MARK: - Invite Badge
    @Published var pendingInviteCount: Int = 0

    // MARK: - Daily (Multi-Pair Scoped State)
    @Published var statusByPair: [String: TodayStatusModel] = [:]
    private var dailyListeners: [String: ListenerRegistration] = [:]
    private var dailyListenerKeys: [String: String] = [:] // pairId -> yyyy-MM-dd
    
    // MARK: - Weekly Sync (Phase 220)
    @Published var weeklyProgressByPair: [String: WeekProgress] = [:]
    private var weekListeners: [String: ListenerRegistration] = [:]
    private var weekListenerKeys: [String: String] = [:] // pairId -> startOfWeekKey
    
    private var blockedUidsListener: ListenerRegistration? = nil
    private var hiddenPairsListener: ListenerRegistration? = nil
    private var mutedUidsListener: ListenerRegistration? = nil
    // Tombstone set to prevent resurrection of deleted records
    private var deletedKeys: Set<String> = [] {
        didSet {
            UserDefaults.standard.set(Array(deletedKeys), forKey: "TombstoneKeys_v1")
        }
    }
    
    private func savePairStatusCache() {
        guard let uid = currentUid else { return }
        let dataToSave = statusByPair
        Task.detached(priority: .utility) {
            do {
                let data = try JSONEncoder().encode(dataToSave)
                UserDefaults.standard.set(data, forKey: "CachedStatusByPair_\(uid)")
            } catch {
                print("[ERROR][Cache] Failed to save statusByPair: \(error)")
            }
        }
    }
    
    private func loadPairStatusCache() {
        guard let uid = currentUid else { return }
        guard let data = UserDefaults.standard.data(forKey: "CachedStatusByPair_\(uid)") else { return }
        do {
            let cached = try JSONDecoder().decode([String: TodayStatusModel].self, from: data)
            self.statusByPair = cached
            print("[DEBUG][Cache] Loaded \(cached.count) pairs status from local cache.")
        } catch {
            print("[ERROR][Cache] Failed to load statusByPair: \(error)")
        }
    }
    
    private func saveWeeklyProgressCache() {
        guard let uid = currentUid else { return }
        let dataToSave = weeklyProgressByPair
        Task.detached(priority: .utility) {
            do {
                let data = try JSONEncoder().encode(dataToSave)
                UserDefaults.standard.set(data, forKey: "CachedWeeklyProgressByPair_\(uid)")
            } catch {
                print("[ERROR][Cache] Failed to save weeklyProgressByPair: \(error)")
            }
        }
    }
    
    private func loadWeeklyProgressCache() {
        guard let uid = currentUid else { return }
        guard let data = UserDefaults.standard.data(forKey: "CachedWeeklyProgressByPair_\(uid)") else { return }
        do {
            let cached = try JSONDecoder().decode([String: WeekProgress].self, from: data)
            self.weeklyProgressByPair = cached
            print("[DEBUG][Cache] Loaded \(cached.count) pairs weekly progress from local cache.")
        } catch {
            print("[ERROR][Cache] Failed to load weeklyProgressByPair: \(error)")
        }
    }
    
    private func savePartnerProfileCache() {
        guard let uid = currentUid else { return }
        let dataToSave = partnerProfileCache
        Task.detached(priority: .utility) {
            do {
                let data = try JSONEncoder().encode(dataToSave)
                UserDefaults.standard.set(data, forKey: "CachedPartnerProfiles_\(uid)")
            } catch {
                print("[ERROR][Cache] Failed to save partnerProfileCache: \(error)")
            }
        }
    }
    
    private func loadPartnerProfileCache() {
        guard let uid = currentUid else { return }
        guard let data = UserDefaults.standard.data(forKey: "CachedPartnerProfiles_\(uid)") else { return }
        do {
            let cached = try JSONDecoder().decode([String: PartnerProfileInfo].self, from: data)
            self.partnerProfileCache = cached
            print("[DEBUG][Cache] Loaded \(cached.count) partner profiles from local cache.")
        } catch {
            print("[ERROR][Cache] Failed to load partnerProfileCache: \(error)")
        }
    }
    func isTombstoned(_ key: String) -> Bool {
        // --- Phase 187: Disable Tombstone Logic ---
        return false
    }

    // Lifecycle: managed by UI or AppViewModel
    func startPairSync(pairId: String) {
        let currentDayKey = todayKey
        
        // Phase 270: DateTime-Aware Re-attachment
        // If listener exists but it's for an OLD date, force re-attach.
        if let existingKey = dailyListenerKeys[pairId], existingKey == currentDayKey {
            return
        }
        
        // Remove old if date changed
        dailyListeners[pairId]?.remove()
        
        let path = "pairs/\(pairId)/daily/\(currentDayKey)"
        print("[PairStatus] listen daily path=\(path)")
        let db = Firestore.firestore()
        
        dailyListenerKeys[pairId] = currentDayKey
        dailyListeners[pairId] = db.document(path).addSnapshotListener { [weak self] snap, err in
            guard let self = self else { return }
            if let err = err {
                print("[ERROR][PairSync] pairId=\(pairId): \(err.localizedDescription)")
                return
            }
            
            let status = (snap?.exists ?? false) ? TodayStatusModel.from(data: snap?.data() ?? [:]) : TodayStatusModel(statusByUid: [:])
            
            Task { @MainActor in
                self.statusByPair[pairId] = status
                self.savePairStatusCache() // Phase 290: Update cache
                self.objectWillChange.send()
            }
        }
        
        // Also start weekly sync (Same logic)
        let currentWeekKey = Date().startOfWeekKey
        if let existingWeekKey = weekListenerKeys[pairId], existingWeekKey == currentWeekKey {
            return
        }
        
        weekListeners[pairId]?.remove()
        let weekPath = "pairs/\(pairId)/weeks/\(currentWeekKey)"
        print("[PairStatus] listen weekly path=\(weekPath)")
        
        weekListenerKeys[pairId] = currentWeekKey
        weekListeners[pairId] = db.document(weekPath).addSnapshotListener { [weak self] snap, err in
            guard let self = self else { return }
            if let err = err {
                print("[ERROR][WeekSync] pairId=\(pairId): \(err.localizedDescription)")
                return
            }
            
            if let data = snap?.data() {
                Task { @MainActor in
                    do {
                        let progress = try snap!.data(as: WeekProgress.self)
                        self.weeklyProgressByPair[pairId] = progress
                        self.saveWeeklyProgressCache() // Phase 290: Update cache
                        self.objectWillChange.send()
                    } catch {
                        print("[WARNING][WeekSync] Manual decode for \(pairId)")
                        let fallback = WeekProgress(
                            id: currentWeekKey,
                            dailyDoneByUid: data["dailyDoneByUid"] as? [String: [Bool]] ?? [:],
                            doneCountByUid: data["doneCountByUid"] as? [String: Int] ?? [:],
                            requiredDays: data["requiredDays"] as? Int ?? 7,
                            unlocked: data["unlocked"] as? Bool ?? false,
                            unlockedAt: (data["unlockedAt"] as? Timestamp)?.dateValue(),
                            updatedAt: (data["updatedAt"] as? Timestamp)?.dateValue() ?? Date()
                        )
                        self.weeklyProgressByPair[pairId] = fallback
                        self.saveWeeklyProgressCache() // Phase 290: Update cache
                        self.objectWillChange.send()
                    }
                }
            }
        }
    }
    
    func startWeekSync(pairId: String) {
        startPairSync(pairId: pairId)
    }

    func stopPairSync(pairId: String) {
        print("[PairStore] stopPairSync pairId=\(pairId)")
        dailyListeners[pairId]?.remove()
        dailyListeners[pairId] = nil
        statusByPair.removeValue(forKey: pairId)
        
        weekListeners[pairId]?.remove()
        weekListeners[pairId] = nil
        weeklyProgressByPair.removeValue(forKey: pairId)
    }

    func stopAllPairSync() {
        print("[PairStore] stopAllPairSync")
        for (_, listener) in dailyListeners {
            listener.remove()
        }
        dailyListeners = [:]
        statusByPair = [:]
        
        for (_, listener) in weekListeners {
            listener.remove()
        }
        weekListeners = [:]
        weeklyProgressByPair = [:]
    }

    // MARK: - Legacy Daily (UI local state - DEPRECATED in favor of statusByPair)
    struct LegacyDailyStatus: Equatable {
        var windowDidCapture: Bool = false
        var windowThumbRelativePath: String?
        var windowPhotoUrl: String?
        var windowCapturedAt: Date?
        var momentPath: String?
        var rating: Int?
        var memo: String?
        var isPrivate: Bool? = false // Phase 300
        var isDeleted: Bool = false
        var shouldMirrorForUI: Bool = false // Phase 207.2

        // Targeted Capture
        var targetedWindowDidCapture: Bool = false
        var targetedWindowThumbRelativePath: String?
        var targetedWindowPhotoUrl: String?
        var targetedWindowCapturedAt: Date?
        var targetedMomentPath: String?
        var targetedMemo: String?

        static func empty() -> LegacyDailyStatus { 
            .init(
                windowDidCapture: false, windowThumbRelativePath: nil, windowPhotoUrl: nil, windowCapturedAt: nil, momentPath: nil, rating: nil, memo: nil, isDeleted: false, shouldMirrorForUI: false,
                targetedWindowDidCapture: false, targetedWindowThumbRelativePath: nil, targetedWindowPhotoUrl: nil, targetedWindowCapturedAt: nil, targetedMomentPath: nil, targetedMemo: nil
            ) 
        }
    }

    typealias DailyStatus = LegacyDailyStatus

    @Published var myDaily: [String: LegacyDailyStatus] = [:]
    
    // Paging metadata
    private var lastDailyDocument: DocumentSnapshot? = nil
    @Published var canLoadMoreDaily: Bool = true
    @Published var isLoadingMoreDaily: Bool = false

    // MARK: - Search Photo Paging (Phase 87)
    @Published var searchUserPhotos: [String: LegacyDailyStatus] = [:]
    @Published var canLoadMoreSearch: Bool = true
    @Published var isLoadingMoreSearch = false
    private var lastSearchDocument: DocumentSnapshot? = nil
    @Published var partnerDaily: [String: LegacyDailyStatus] = [:]

    // GUARD: True during deletion process to prevent listener rewrites
    @Published var isClearingWindowPhoto = false

    var myToday: LegacyDailyStatus {
        get { 
            if deletedKeys.contains(todayKey) { return .empty() }
            return myDaily[todayKey] ?? .empty() 
        }
        set { 
            if !deletedKeys.contains(todayKey) {
                myDaily[todayKey] = newValue 
            }
        }
    }

    var partnerToday: LegacyDailyStatus {
        get { 
            if deletedKeys.contains(todayKey) { return .empty() }
            return partnerDaily[todayKey] ?? .empty() 
        }
        set { 
            if !deletedKeys.contains(todayKey) {
                partnerDaily[todayKey] = newValue 
            }
        }
    }

    var todayKey: String { Date().yyyyMMdd }

    var currentUid: String? { Auth.auth().currentUser?.uid ?? authUid }

    init() {
        print("[PairStore] init instance=\(ObjectIdentifier(self).hashValue)")
        self.authUid = Auth.auth().currentUser?.uid
    }

    /// For unifying entry points (calling once from anywhere is enough)
    func initialize() {
        // Load local tombstones immediately
        if let local = UserDefaults.standard.stringArray(forKey: "TombstoneKeys_v1") {
            self.deletedKeys = Set(local)
            print("[Tombstone] Loaded \(local.count) keys from local storage.")
        }
        
        // Phase 290/291: Load local cache immediately
        loadPairStatusCache()
        loadWeeklyProgressCache()
        loadPartnerProfileCache()
        
        startAuthListener()
        fetchTombstonesOnStartup()
    }
    
    func markAsTombstoned(_ key: String) {
        // --- Phase 187: Deprecated ---
        print("[Tombstone] markAsTombstoned ignored (Phase 187).")
    }
    
    func removeTombstone(_ key: String) async {
        // --- Phase 187: Deprecated ---
        print("[Tombstone] removeTombstone ignored (Phase 187).")
    }
    
    private func fetchTombstonesOnStartup() {
        guard let uid = Auth.auth().currentUser?.uid ?? authUid else { return }
        let db = Firestore.firestore()
        db.collection("users").document(uid).collection("tombstones").getDocuments { [weak self] snap, err in
            guard let self = self, let docs = snap?.documents else { return }
            let keys = docs.map { $0.documentID }
            DispatchQueue.main.async {
                self.deletedKeys = Set(keys)
                if !keys.isEmpty {
                    print("[Tombstone] Loaded \(keys.count) keys on startup: \(keys)")
                    self.objectWillChange.send()
                }
            }
        }
    }

    // MARK: - Basic logs as UI notices
    func postNotice(_ message: String) {
        let now = Date()
        if let last = lastNotice, last.msg == message, now.timeIntervalSince(last.at) < 1.0 {
            return
        }
        lastNotice = (message, now)
        print("[NOTICE] \(message)")
    }

    // MARK: - DEBUG Helpers
    /// Clears local observable state for debugging purposes.
    /// This does not touch Firestore; it only resets in-memory UI state.
    func debugResetPairStateForMe() {
        inbox = []
        outbox = []
        pairRefs = []
        profile = .init()
        myDaily = [:]
        partnerDaily = [:]
        postNotice("debugResetPairStateForMe: local state cleared")
    }

    #if DEBUG
    func debugRestartListeners() {
        stopInviteListeners()
        stopPairRefsListener()
        startInviteListeners()
        startPairRefsListener()
        postNotice("listeners restarted (debug)")
    }
    #endif

    // MARK: - Auth listener
    func startAuthListener() {
        if authListener != nil { return }

        authListener = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            guard let self = self else { return }
            let newUid = user?.uid

            Task { @MainActor in
                print("[PairStore] auth state changed uid=\(newUid ?? "nil")")
                self.authUid = newUid

                if let uid = newUid {
                    print("[PairStore] UID confirmed. Starting listeners for uid=\(uid)")
                    
                    // Phase 291: Load caches now that UID is known
                    self.loadPairStatusCache()
                    self.loadWeeklyProgressCache()
                    self.loadPartnerProfileCache()
                    
                    self.startInviteListeners()
                    self.startPairRefsListener()
                    self.startMyProfileListener()
                    self.startPrivacyListeners()
                } else {
                    print("[PairStore] UID is nil. Stopping all listeners.")
                    self.stopInviteListeners()
                    self.stopPairRefsListener()
                    self.stopMyProfileListener()
                    self.stopPrivacyListeners()
                    self.stopAllPairSync()
                }
            }
        }

        // Initial check if user is already there
        if let user = Auth.auth().currentUser {
            let uid = user.uid
            print("[PairStore] Auth listener initialized. Current user exists: \(uid)")
            self.authUid = uid
            startInviteListeners()
            startPairRefsListener()
            startMyProfileListener()
        } else {
            print("[PairStore] Auth listener initialized. No current user found.")
        }
    }

    deinit {
        if let h = authListener {
            Auth.auth().removeStateDidChangeListener(h)
        }
        Task { @MainActor [weak self] in
            self?.stopInviteListeners()
            self?.stopPairRefsListener()
            self?.stopMyProfileListener()
            self?.stopPrivacyListeners()
        }
    }

    // MARK: - Invite listeners (Firestore)
    func startInviteListeners() {
        guard let uid = Auth.auth().currentUser?.uid ?? authUid else {
            print("[PairStore] startInviteListeners FAIL: no uid")
            return
        }
        print("[PairStore] startInviteListeners uid=\(uid)")

        let db = Firestore.firestore()

        // inbox: toUid == me and status == pending
        inboxListener?.remove()
        inboxListener = db.collection("pairInvites")
            .whereField("toUid", isEqualTo: uid)
            .whereField("status", isEqualTo: "pending")
            .addSnapshotListener { [weak self] snap, err in
                guard let self = self else { return }
                if let err = err {
                    let ns = err as NSError
                    print("[ERROR][InviteInboxListen] domain=\(ns.domain) code=\(ns.code) desc=\(ns.localizedDescription) userInfo=\(ns.userInfo)")
                    return
                }

                self.inboxListenTick += 1
                let docs = snap?.documents ?? []
                
                let items: [InviteItem] = docs.map { d in
                    let data = d.data()
                    let ts = (data["createdAt"] as? Timestamp)?.dateValue()
                    return InviteItem(
                        id: d.documentID,
                        fromUid: data["fromUid"] as? String ?? "",
                        toUid: data["toUid"] as? String ?? "",
                        status: data["status"] as? String ?? "",
                        createdAt: ts
                    )
                }

                Task { @MainActor in
                    self.inbox = items
                    self.pendingInviteCount = items.count
                    print("[PairStore] inbox count=\(items.count)")
                    
                    // Pre-fetch inviter profiles for cache
                    for item in items {
                        _ = try? await self.getPartnerProfile(uid: item.fromUid)
                    }
                }
            }

        // outbox: fromUid == me (pending only)
        outboxListener?.remove()
        outboxListener = db.collection("pairInvites")
            .whereField("fromUid", isEqualTo: uid)
            .whereField("status", isEqualTo: "pending")
            .addSnapshotListener { [weak self] snap, err in
                guard let self = self else { return }
                if let err = err {
                    let ns = err as NSError
                    print("[ERROR][InviteOutboxListen] domain=\(ns.domain) code=\(ns.code) desc=\(ns.localizedDescription) userInfo=\(ns.userInfo)")
                    return
                }

                self.outboxListenTick += 1
                let docs = snap?.documents ?? []

                let items: [InviteItem] = docs.map { d in
                    let data = d.data()
                    let ts = (data["createdAt"] as? Timestamp)?.dateValue()
                    return InviteItem(
                        id: d.documentID,
                        fromUid: data["fromUid"] as? String ?? "",
                        toUid: data["toUid"] as? String ?? "",
                        status: data["status"] as? String ?? "",
                        createdAt: ts
                    )
                }

                Task { @MainActor in
                    self.outbox = items
                    print("[PairStore] outbox count=\(items.count)")
                }
            }
    }

    func stopInviteListeners() {
        inboxListener?.remove()
        inboxListener = nil
        outboxListener?.remove()
        outboxListener = nil
        // clear invite lists
        inbox = []
        outbox = []
        print("[PairStore] stopInviteListeners")
    }

    // MARK: - My Profile listener
    func startMyProfileListener() {
        guard let uid = Auth.auth().currentUser?.uid ?? authUid else { return }
        print("[PairStore] startMyProfileListener uid=\(uid)")
        let db = Firestore.firestore()
        
        myProfileListener = db.collection("users").document(uid).addSnapshotListener { [weak self] snap, err in
            guard let self = self else { return }
            if let data = snap?.data() {
                Task { @MainActor in
                    self.myNickname = data["nickname"] as? String ?? ""
                    self.myHandle = data["handle"] as? String ?? ""
                    self.myHandleUpdatedAt = (data["handleUpdatedAt"] as? Timestamp)?.dateValue()
                    self.myAvatarPath = data["avatarPath"] as? String ?? ""
                    self.myAvatarUpdatedAt = (data["avatarUpdatedAt"] as? Timestamp)?.dateValue()
                    self.myBirthdate = (data["birthdate"] as? Timestamp)?.dateValue()
                    self.isPrivate = data["isPrivate"] as? Bool ?? false
                    
                    // Update profile for compatibility
                    var p = self.profile
                    p.partnerName = self.myNickname
                    self.profile = p
                }
            }
        }
    }
    
    func stopMyProfileListener() {
        myProfileListener?.remove()
        myProfileListener = nil
        myNickname = ""
        myHandle = ""
        myAvatarPath = ""
        myAvatarUpdatedAt = nil
        myBirthdate = nil
    }

    // MARK: - Pair refs listener (updated: listen users/{uid}/pairRefs)
    func startPairRefsListener() {
        guard let uid = Auth.auth().currentUser?.uid ?? authUid else { return }
        print("[PairStore] startPairRefsListener uid=\(uid)")
        let db = Firestore.firestore()

        pairRefsListener?.remove()
        pairRefsListener = db.collection("users").document(uid).collection("pairRefs")
            .order(by: "createdAt", descending: true)
            .addSnapshotListener { [weak self] snap, err in
                guard let self = self else { return }
                if let err = err { print("[ERROR][PairRefsListen] \(err)"); return }

                // Token for this snapshot
                let token = UUID()
                self.pairRefsFetchToken = token

                let docs = snap?.documents ?? []
                let actualCount = docs.count
                self.syncPairCountWithActualRefs(uid: uid, count: actualCount)

                var items: [PairRefItem] = docs.compactMap { d in
                    let data = d.data()
                    // Fixed: Use 'partnerUid' or 'otherUid' as stored in pairRefs
                    let partnerUid = data["partnerUid"] as? String ?? data["otherUid"] as? String ?? ""
                    guard !partnerUid.isEmpty else { return nil }
                    
                    let ts = (data["createdAt"] as? Timestamp)?.dateValue()
                    return PairRefItem(
                        id: d.documentID,
                        partnerUid: partnerUid,
                        partnerDisplayName: nil,
                        partnerHandle: nil,
                        createdAt: ts
                    )
                }
                // Local sort (nil-safe) + tie-breaker
                items.sort {
                    let lhs = $0.createdAt ?? .distantPast
                    let rhs = $1.createdAt ?? .distantPast
                    if lhs == rhs { return $0.id > $1.id }
                    return lhs > rhs
                }

                // Update immediately without names
                Task { @MainActor in
                    self.pairRefs = items
                    
                    // Phase 291: Automatically start status sync for all pairs
                    for item in items {
                        self.startPairSync(pairId: item.id)
                    }
                }

                // Cancel previous name fetch
                self.nicknameFetchTask?.cancel()
                // Fill partner details (name, avatar, etc.) in background
                self.nicknameFetchTask = Task { [weak self] in
                    guard let self = self else { return }
                    if Task.isCancelled { return }

                    var profileMap: [String: PartnerProfileInfo] = [:]
                    let uids = Array(Set(items.map { $0.partnerUid })).filter { !$0.isEmpty }

                    await withTaskGroup(of: (String, PartnerProfileInfo?).self) { group in
                        for uid in uids {
                            group.addTask { [weak self] in
                                guard let self = self else { return (uid, nil) }
                                if Task.isCancelled { return (uid, nil) }
                                do {
                                    let info = try await self.getPartnerProfile(uid: uid)
                                    
                                    // Check cache for avatar image
                                    if let path = info.avatarPath, !path.isEmpty {
                                        let cached = await AvatarCacheService.shared.loadAvatar(for: uid, updatedAt: info.avatarUpdatedAt)
                                        if cached == nil {
                                            // Download if not in cache
                                            print("[DEBUG][AvatarSync] Cache miss for \(uid). Downloading from \(path)...")
                                            let url = try await CloudStorageService.shared.getDownloadURL(for: path)
                                            let (data, _) = try await URLSession.shared.data(from: url)
                                            _ = try await AvatarCacheService.shared.saveAvatar(data: data, for: uid, updatedAt: info.avatarUpdatedAt)
                                            print("[DEBUG][AvatarSync] Download & Cache OK for \(uid)")
                                        }
                                    }
                                    
                                    return (uid, info)
                                } catch {
                                    print("[ERROR][AvatarSync] Failed to fetch/cache profile for \(uid): \(error)")
                                    return (uid, nil)
                                }
                            }
                        }
                        for await (uid, info) in group {
                            if Task.isCancelled { return }
                            if let info { profileMap[uid] = info }
                        }
                        
                        if Task.isCancelled { return }
                        
                        await MainActor.run {
                            var newRefs = self.pairRefs
                            for i in 0..<newRefs.count {
                                if let prof = profileMap[newRefs[i].partnerUid] {
                                    newRefs[i].partnerDisplayName = prof.name
                                    newRefs[i].partnerAvatarPath = prof.avatarPath
                                    newRefs[i].partnerAvatarUpdatedAt = prof.avatarUpdatedAt
                                    newRefs[i].partnerHandle = prof.handle
                                }
                            }
                            // Only update if token still matches
                            if self.pairRefsFetchToken == token {
                                self.pairRefs = newRefs
                                print("[PairStore] pairRefs enriched with names/handles OK")
                            }
                        }
                    }
                }
            }
    }

    func stopPairRefsListener() {
        pairRefsListener?.remove()
        pairRefsListener = nil
        // cancel ongoing nickname fetch
        nicknameFetchTask?.cancel()
        nicknameFetchTask = nil
        // advance token generation to invalidate in-flight nickname fills
        pairRefsFetchToken = UUID()
        // clear pair refs list
        pairRefs = []
    }

    // MARK: - Internal helpers
    func invalidatePairRefsFillToken() {
        pairRefsFetchToken = UUID()
    }

    // MARK: - PairView required APIs (minimal)
    func createInvite() -> String {
        let code = String(UUID().uuidString.prefix(6)).uppercased()
        var p = profile
        p.inviteCode = code
        p.status = .invited
        profile = p
        return code
    }

    func enterInviteCode(_ code: String) {
        var p = profile
        p.status = .paired
        p.inviteCode = nil
        profile = p
        if partnerDaily[todayKey] == nil { partnerDaily[todayKey] = .empty() }
    }

    /// Deprecated: use unpair(pairId:) which is Firestore-consistent and authoritative.
    func unpair() {
        fatalError("Use unpair(pairId:)")
    }

    func toggleSimulatePartnerDone() {
        var s = partnerToday
        s.windowDidCapture.toggle()
        partnerToday = s
    }

    // MARK: - Capture completion (Firestore write)

    func markMyWindowCaptured(pairId: String, thumbPath: String?, fullPath: String?, momentPath: String? = nil, memo: String? = nil, isTargeted: Bool = false) async {
        let didCapture = true
        await MainActor.run {
            var s = self.myToday
            if isTargeted {
                s.targetedWindowDidCapture = didCapture
                s.targetedWindowThumbRelativePath = thumbPath
                s.targetedWindowCapturedAt = Date()
                s.targetedMomentPath = momentPath
            } else {
                s.windowDidCapture = didCapture
                s.windowThumbRelativePath = thumbPath
                s.windowCapturedAt = Date()
                s.momentPath = momentPath
            }
            s.isDeleted = false
            self.myToday = s
        }

        // Phase 270: Synchronous local update (Instant UI reflection for the lamp)
        await MainActor.run {
            if var current = self.statusByPair[pairId], let myUid = self.currentUid {
                var myStatus = current.statusByUid[myUid] ?? TodayStatusModel.TodayUserStatus()
                if isTargeted {
                    myStatus.targetedWindowDidCapture = didCapture
                    myStatus.targetedWindowThumbPath = thumbPath
                    myStatus.targetedWindowCapturedAt = Date()
                } else {
                    myStatus.windowDidCapture = didCapture
                    myStatus.windowThumbPath = thumbPath
                    myStatus.windowCapturedAt = Date()
                }
                current.statusByUid[myUid] = myStatus
                self.statusByPair[pairId] = current
                self.objectWillChange.send()
            }
        }

        var windowUrl: String? = nil
        // Use thumbPath for URL if available, otherwise fallback to fullPath
        if let path = thumbPath ?? fullPath {
            windowUrl = try? await CloudStorageService.shared.getDownloadURL(for: path).absoluteString
        }
        
        // Phase 270: Update URL once available
        await MainActor.run {
            if var current = self.statusByPair[pairId], let myUid = self.currentUid {
                var myStatus = current.statusByUid[myUid] ?? TodayStatusModel.TodayUserStatus()
                if isTargeted {
                    myStatus.targetedWindowPhotoUrl = windowUrl
                } else {
                    myStatus.windowPhotoUrl = windowUrl
                }
                current.statusByUid[myUid] = myStatus
                self.statusByPair[pairId] = current
                self.objectWillChange.send()
            }
            
            if isTargeted {
                self.myToday.targetedWindowPhotoUrl = windowUrl
            } else {
                self.myToday.windowPhotoUrl = windowUrl
            }
        }

        await self.writeMyPersonalDaily(
            windowDidCapture: didCapture,
            windowThumbPath: thumbPath,
            windowFullPath: fullPath,
            windowPhotoUrl: windowUrl,
            momentPath: momentPath,
            rating: self.myToday.rating,
            memo: memo ?? self.myToday.memo,
            isTargeted: isTargeted
        )
        
        await self.writeMyDailyToPairDaily(
            pairId: pairId,
            windowDidCapture: didCapture,
            windowThumbPath: thumbPath,
            windowFullPath: fullPath,
            windowPhotoUrl: windowUrl,
            momentPath: momentPath,
            rating: self.myToday.rating,
            memo: memo ?? self.myToday.memo,
            isTargeted: isTargeted
        )
    }

    func writeMyDailyToPairDaily(pairId: String, windowDidCapture: Bool = false, windowThumbPath: String? = nil, windowFullPath: String? = nil, windowPhotoUrl: String? = nil, momentPath: String? = nil, rating: Int? = nil, memo: String? = nil, windowCapturedAt: Date? = nil, isTargeted: Bool = false) async {
        guard let uid = Auth.auth().currentUser?.uid ?? authUid else { return }

        let db = Firestore.firestore()
        let docRef = db.collection("pairs").document(pairId).collection("daily").document(todayKey)
        
        // Phase 283: Use granular dot-notation for EVERY field to prevent overwriting counterparts (Public vs Targeted)
        var updates: [String: Any] = [
            "updatedAt": FieldValue.serverTimestamp(),
            "statusByUid.\(uid).updatedAt": FieldValue.serverTimestamp()
        ]

        let prefix = "statusByUid.\(uid)"

        if isTargeted {
            updates["\(prefix).targetedWindowDidCapture"] = windowDidCapture
            updates["\(prefix).targetedWindowCapturedAt"] = windowCapturedAt.map { Timestamp(date: $0) } ?? FieldValue.serverTimestamp()
            updates["\(prefix).targetedMemo"] = memo ?? (myDaily[todayKey]?.targetedMemo ?? "")
            
            if let thumb = windowThumbPath, !thumb.isEmpty { updates["\(prefix).targetedWindowThumbPath"] = thumb }
            if let full = windowFullPath, !full.isEmpty { updates["\(prefix).targetedWindowFullPath"] = full }
            if let url = windowPhotoUrl, !url.isEmpty { updates["\(prefix).targetedWindowPhotoUrl"] = url }
            if let moment = momentPath, !moment.isEmpty { updates["\(prefix).targetedMomentPath"] = moment }
        } else {
            updates["\(prefix).windowDidCapture"] = windowDidCapture
            updates["\(prefix).windowCapturedAt"] = windowCapturedAt.map { Timestamp(date: $0) } ?? FieldValue.serverTimestamp()
            updates["\(prefix).memo"] = memo ?? (myDaily[todayKey]?.memo ?? "")
            updates["\(prefix).shouldMirrorForUI"] = (myDaily[todayKey]?.shouldMirrorForUI ?? false)
            
            if let thumb = windowThumbPath, !thumb.isEmpty { updates["\(prefix).windowThumbPath"] = thumb }
            if let full = windowFullPath, !full.isEmpty { updates["\(prefix).windowFullPath"] = full }
            if let url = windowPhotoUrl, !url.isEmpty { updates["\(prefix).windowPhotoUrl"] = url }
            if let moment = momentPath, !moment.isEmpty { updates["\(prefix).momentPath"] = moment }
            if let r = rating { updates["\(prefix).rating"] = r }
        }
        
        if let rating = rating {
            updates["\(prefix).rating"] = rating
        }
        
        do {
            try await docRef.updateData(updates)
        } catch {
            // Phase 270/283: SAFE FALLBACK.
            // If document doesn't exist, we must use setData. 
            // We use merge: true, but notice we are still passing the nested structure.
            print("[PairStore] updateData failed, using safe merge fallback: \(error.localizedDescription)")
            let fallback: [String: Any] = [
                "updatedAt": FieldValue.serverTimestamp(),
                "statusByUid": [uid: updates.filter { $0.key.starts(with: prefix) }.reduce(into: [String: Any]()) { dict, pair in
                    let subKey = pair.key.replacingOccurrences(of: "\(prefix).", with: "")
                    dict[subKey] = pair.value
                }]
            ]
            try? await docRef.setData(fallback, merge: true)
        }
    }

    /// Personal Log: users/{uid}/daily/{yyyy-MM-dd} (Source of Truth)
    func writeMyPersonalDaily(windowDidCapture: Bool = false, windowThumbPath: String? = nil, windowFullPath: String? = nil, windowPhotoUrl: String? = nil, momentPath: String? = nil, rating: Int? = nil, windowCapturedAt: Date? = nil, memo: String? = nil, isTargeted: Bool = false) async {
        guard let uid = currentUid else { return }
        let db = Firestore.firestore()
        let docRef = db.collection("users").document(uid).collection("daily").document(todayKey)
        
        var stats: [String: Any] = [
            "updatedAt": FieldValue.serverTimestamp()
        ]

        if isTargeted {
            stats["targetedWindowDidCapture"] = windowDidCapture
            stats["targetedWindowThumbPath"] = (windowThumbPath ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            stats["targetedWindowFullPath"] = (windowFullPath ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            stats["targetedWindowPhotoUrl"] = windowPhotoUrl ?? ""
            stats["targetedWindowCapturedAt"] = windowCapturedAt.map { Timestamp(date: $0) } ?? FieldValue.serverTimestamp()
            stats["targetedMomentPath"] = momentPath ?? ""
            stats["targetedMemo"] = memo ?? (myDaily[todayKey]?.targetedMemo ?? "")
        } else {
            stats["windowDidCapture"] = windowDidCapture
            stats["windowThumbPath"] = (windowThumbPath ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            stats["windowFullPath"] = (windowFullPath ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            stats["windowPhotoUrl"] = windowPhotoUrl ?? ""
            stats["windowCapturedAt"] = windowCapturedAt.map { Timestamp(date: $0) } ?? FieldValue.serverTimestamp()
            stats["momentPath"] = momentPath ?? ""
            stats["memo"] = memo ?? (myDaily[todayKey]?.memo ?? "")
            stats["shouldMirrorForUI"] = (myDaily[todayKey]?.shouldMirrorForUI ?? false)
            if let r = rating { stats["rating"] = r }
        }
        
        do {
            try await docRef.setData(stats, merge: true)
            print("[Capture] write userDaily path=\(docRef.path)")
        } catch {
            print("[ERROR][PersonalDailyWrite] failed: \(error)")
        }
    }

    /// Backfill today's data from personal logs to the new pair document
    func initialPairSync(pairId: String, uids: [String]) async {
        print("[PairSync] Initial sync for pairId=\(pairId)")
        let db = Firestore.firestore()
        
        var combinedStatus: [String: [String: Any]] = [:]
        let now = FieldValue.serverTimestamp()
        
        for uid in uids {
            var userStatus: [String: Any] = [
                "windowDidCapture": false,
                "windowThumbPath": "",
                "updatedAt": now
            ]
            
            do {
                let snap = try await db.collection("users").document(uid).collection("daily").document(todayKey).getDocument()
                if let data = snap.data() {
                    let captured = data["windowDidCapture"] as? Bool ?? false
                    let updatedAt = (data["updatedAt"] as? Timestamp)?.dateValue() ?? Date.distantPast
                    
                    // Phase 270: Ghost Data Protection
                    // If the personal record was updated more than 4 hours ago, 
                    // and we are just now forming a pair, treat it as potentially stale 
                    // unless we are absolutely sure.
                    let isFresh = Date().timeIntervalSince(updatedAt) < 4 * 3600
                    
                    if captured && isFresh {
                        userStatus["windowDidCapture"] = true
                        userStatus["windowThumbPath"] = data["windowThumbPath"] as? String ?? ""
                        userStatus["windowFullPath"] = data["windowFullPath"] as? String ?? ""
                        userStatus["windowPhotoUrl"] = data["windowPhotoUrl"] as? String ?? ""
                        userStatus["windowCapturedAt"] = (data["windowCapturedAt"] as? Timestamp)?.dateValue()
                        if let rating = data["rating"] as? Int {
                            userStatus["rating"] = rating
                        }
                        userStatus["momentPath"] = data["momentPath"] as? String ?? ""
                        userStatus["memo"] = data["memo"] as? String ?? ""
                        userStatus["shouldMirrorForUI"] = data["shouldMirrorForUI"] as? Bool ?? false
                    } else {
                        // Data too old or not captured, keep defaults (false)
                        userStatus["windowDidCapture"] = false
                    }
                    
                    if let ts = data["updatedAt"] {
                        userStatus["updatedAt"] = ts
                    }
                }
            } catch {
                print("[WARNING][PairSync] Failed to fetch personal log for \(uid): \(error)")
            }
            combinedStatus[uid] = userStatus
        }
        
        // Phase 270: Automatic Repair (Bidirectional)
        // If the personal record says captured, light up the lamp. Otherwise ensure it's OFF.
        for uid in uids {
            let captured = (combinedStatus[uid]?["windowDidCapture"] as? Bool) ?? false
            Task {
                try? await self.updateWeeklyProgress(pairId: pairId, date: Date(), status: captured, uid: uid)
            }
        }
        
        let pairDailyRef = db.collection("pairs").document(pairId).collection("daily").document(todayKey)
        let updates: [String: Any] = [
            "statusByUid": combinedStatus,
            "updatedAt": now,
            "createdAt": now // Task B-1: Ensure basic fields exist
        ]
        
        do {
            // Use merge: false for initial sync to overwrite any "null" or broken docs
            try await pairDailyRef.setData(updates, merge: true)
            let summary = combinedStatus.mapValues { ($0["windowDidCapture"] as? Bool) ?? false }
            print("[PairSync] Initial sync CREATED pairId=\(pairId) data=\(summary)")
        } catch {
            print("[ERROR][PairSync] Initial sync failed for pairId=\(pairId): \(error)")
        }
    }

    /// Fetch historical daily captures from Firestore with paging
    func fetchMyPersonalDailyLogs(limit: Int = 20) async {
        guard let uid = Auth.auth().currentUser?.uid ?? authUid, canLoadMoreDaily else { return }
        
        let startTime = Date()
        await MainActor.run { isLoadingMoreDaily = true }
        
        let db = Firestore.firestore()
        
        // 0. Fetch Tombstones (to prevent resurrection of deleted items)
        var deletedKeys: Set<String> = []
        do {
            let tsSnap = try await db.collection("users").document(uid).collection("tombstones").getDocuments()
            let keys = tsSnap.documents.map { $0.documentID }
            deletedKeys = Set(keys)
            if !keys.isEmpty {
                 print("[Paging] Found \(keys.count) tombstones. Will ignore these keys: \(keys)")
            }
        } catch {
            print("[Paging] Failed to fetch tombstones: \(error)")
        }
        
        var query = db.collection("users").document(uid).collection("daily")
            .order(by: "updatedAt", descending: true)
            .limit(to: limit)
        
        if let lastDoc = lastDailyDocument {
            query = query.start(afterDocument: lastDoc)
        }
        
        do {
            let snap = try await query.getDocuments()
            let elapsed = Int(Date().timeIntervalSince(startTime) * 1000)
            print("[PERF][Paging] Fetched \(snap.documents.count) docs in \(elapsed)ms")
            
            if snap.documents.isEmpty {
                await MainActor.run {
                    self.canLoadMoreDaily = false
                    self.isLoadingMoreDaily = false
                }
                return
            }
            
            self.lastDailyDocument = snap.documents.last
            var fetched: [String: LegacyDailyStatus] = [:]
            
            for doc in snap.documents {
                let dateId = doc.documentID
                
                let data = doc.data()
                let isDeleted = (data["isDeleted"] as? Bool) ?? false
                
                // GUARD: Tombstone / Logical Delete check
                if deletedKeys.contains(dateId) || isDeleted {
                    print("[Paging] ⚠️ Skipping resurrected doc for \(dateId) (Tombstone or Logical Delete found)")
                    continue
                }
                
                var status = LegacyDailyStatus.empty()
                status.windowDidCapture = data["windowDidCapture"] as? Bool ?? false
                status.windowThumbRelativePath = (data["windowThumbPath"] as? String) ?? (data["windowFullPath"] as? String) ?? (data["windowThumbRelativePath"] as? String)
                status.windowCapturedAt = (data["windowCapturedAt"] as? Timestamp)?.dateValue()
                status.windowPhotoUrl = data["windowPhotoUrl"] as? String
                status.momentPath = data["momentPath"] as? String
                status.memo = data["memo"] as? String
                status.rating = data["rating"] as? Int
                status.isDeleted = isDeleted
                status.shouldMirrorForUI = data["shouldMirrorForUI"] as? Bool ?? false // Phase 207.2
                
                fetched[dateId] = status
            }
            
            await MainActor.run {
                for (dateId, status) in fetched {
                    if let existing = self.myDaily[dateId] {
                        var current = existing
                        if status.windowDidCapture { current.windowDidCapture = true }
                        if let wp = status.windowThumbRelativePath, !wp.isEmpty { current.windowThumbRelativePath = wp }
                        if let win = status.windowCapturedAt { current.windowCapturedAt = win }
                        if let url = status.windowPhotoUrl, !url.isEmpty { current.windowPhotoUrl = url }
                        if let mp = status.momentPath, !mp.isEmpty { current.momentPath = mp }
                        if let m = status.memo { current.memo = m }
                        if let r = status.rating { current.rating = r }
                        current.shouldMirrorForUI = status.shouldMirrorForUI // Phase 207.2
                        self.myDaily[dateId] = current
                    } else {
                        self.myDaily[dateId] = status
                    }
                }
                self.isLoadingMoreDaily = false
                if snap.documents.count < limit {
                    self.canLoadMoreDaily = false
                }
            }
        } catch {
            print("[ERROR][Paging] Failed to fetch daily logs: \(error)")
            await MainActor.run { self.isLoadingMoreDaily = false }
        }
    }
    
    /// Syncs all historical logs (one-time or on-demand)
    func syncAllMyPersonalDailyLogs() async {
        print("[PairStore] syncAllMyPersonalDailyLogs START")
        // Increase limit to 500 to cover more historical data for restoration
        await fetchMyPersonalDailyLogs(limit: 500)
        print("[PairStore] syncAllMyPersonalDailyLogs DONE. Count: \(myDaily.count)")
    }

    func resetDailyPaging() {
        lastDailyDocument = nil
        canLoadMoreDaily = true
        myDaily = [:]
    }

    // MARK: - Search User Photos (Phase 87)
    
    func fetchUserPhotos(uid: String, limit: Int = 20) async {
        guard canLoadMoreSearch else { return }
        
        await MainActor.run { isLoadingMoreSearch = true }
        
        let db = Firestore.firestore()
        var query = db.collection("users").document(uid).collection("daily")
            .order(by: "updatedAt", descending: true)
            .limit(to: limit)
        
        if let lastDoc = lastSearchDocument {
            query = query.start(afterDocument: lastDoc)
        }
        
        do {
            let snap = try await query.getDocuments()
            if snap.documents.isEmpty {
                await MainActor.run {
                    self.canLoadMoreSearch = false
                    self.isLoadingMoreSearch = false
                }
                return
            }
            
            self.lastSearchDocument = snap.documents.last
            var fetched: [String: LegacyDailyStatus] = [:]
            
            for doc in snap.documents {
                let dateId = doc.documentID
                let data = doc.data()
                
                var status = LegacyDailyStatus.empty()
                status.windowDidCapture = data["windowDidCapture"] as? Bool ?? false
                status.windowThumbRelativePath = (data["windowThumbPath"] as? String) ?? (data["windowFullPath"] as? String)
                status.windowCapturedAt = (data["windowCapturedAt"] as? Timestamp)?.dateValue()
                
                fetched[dateId] = status
            }
            
            await MainActor.run {
                for (dateId, status) in fetched {
                    self.searchUserPhotos[dateId] = status
                }
                self.isLoadingMoreSearch = false
                if snap.documents.count < limit {
                    self.canLoadMoreSearch = false
                }
            }
        } catch {
            print("[ERROR][Search] fetchUserPhotos FAIL: \(error)")
            await MainActor.run { isLoadingMoreSearch = false }
        }
    }
    
    func resetSearchPaging() {
        searchUserPhotos = [:]
        canLoadMoreSearch = true
        isLoadingMoreSearch = false
        lastSearchDocument = nil
    }

    /// Ensure "Today" document exists for a pair (fallback for legacy pairs)
    func ensureTodayPairDocument(pairId: String, uids: [String]) async {
        let db = Firestore.firestore()
        let docRef = db.collection("pairs").document(pairId).collection("daily").document(todayKey)
        
        do {
            let snap = try await docRef.getDocument()
            if snap.exists {
                print("[PairSync] ensureTodayPairDocument EXISTS pairId=\(pairId)")
            } else {
                print("[PairSync] ensureTodayPairDocument NOT FOUND pairId=\(pairId). Triggering fallback...")
                await initialPairSync(pairId: pairId, uids: uids)
            }
        } catch {
            print("[ERROR][PairSync] ensureTodayPairDocument failed for \(pairId): \(error)")
        }
    }

    func deleteMyWindowPhoto(date: Date) async throws {
        let key = date.yyyyMMdd
        guard let uid = currentUid else { return }
        
        isClearingWindowPhoto = true
        defer { isClearingWindowPhoto = false }
        
        // 1. Storage
        if let path = myDaily[key]?.windowThumbRelativePath, !path.isEmpty {
            try? await CloudStorageService.shared.deleteImage(path: path)
        }
        
        // 2. Firestore Window fields
        let db = Firestore.firestore()
        let personalRef = db.collection("users").document(uid).collection("daily").document(key)
        try await personalRef.updateData([
            "windowDidCapture": false,
            "windowThumbPath": "",
            "windowPhotoUrl": "",
            "windowCapturedAt": FieldValue.delete(),
            "momentPath": FieldValue.delete(),
            "memo": FieldValue.delete(),
            "updatedAt": FieldValue.serverTimestamp()
        ])
        
        // 3. Update all pairs
        for ref in pairRefs {
            let pairRef = db.collection("pairs").document(ref.id).collection("daily").document(key)
            try? await pairRef.updateData([
                "statusByUid.\(uid).windowDidCapture": false,
                "statusByUid.\(uid).windowThumbPath": "",
                "statusByUid.\(uid).windowPhotoUrl": "",
                "statusByUid.\(uid).windowCapturedAt": FieldValue.delete(),
                "updatedAt": FieldValue.serverTimestamp()
            ])
            
            // Phase 270: Explicitly turn off weekly achievement lamp
            try? await self.updateWeeklyProgress(pairId: ref.id, date: date, status: false)
        }
        
        // 4. Update local state
        await MainActor.run {
            if key == todayKey {
                var s = myToday
                s.windowDidCapture = false
                s.windowThumbRelativePath = nil
                s.windowPhotoUrl = nil
                s.windowCapturedAt = nil
                myToday = s
            } else {
                // For past dates, remove the entry entirely from local cache
                myDaily.removeValue(forKey: key)
            }
            self.objectWillChange.send()
        }
    }

    /// Phase 300: Toggle between Public and Private for a specific capture
    func togglePhotoPrivacy(dateId: String, isPrivate: Bool) async {
        guard let uid = Auth.auth().currentUser?.uid ?? authUid else { return }
        let db = Firestore.firestore()
        let date = DateFormatter.yyyyMMdd.date(from: dateId) ?? Date()
        
        // 1. Update personal log
        let personalRef = db.collection("users").document(uid).collection("daily").document(dateId)
        try? await personalRef.setData(["isPrivate": isPrivate], merge: true)
        
        // 2. Fetch data if we are going to restore (Public)
        var statusToUpdate: [String: Any]? = nil
        if !isPrivate {
            if let snapshot = try? await personalRef.getDocument(), let data = snapshot.data() {
                statusToUpdate = [
                    "windowDidCapture": data["windowDidCapture"] as? Bool ?? false,
                    "windowThumbPath": data["windowThumbPath"] ?? "",
                    "windowPhotoUrl": data["windowPhotoUrl"] ?? "",
                    "windowCapturedAt": data["windowCapturedAt"] ?? FieldValue.delete(),
                    "momentPath": data["momentPath"] ?? FieldValue.delete(),
                    "memo": data["memo"] ?? FieldValue.delete(),
                    "isPrivate": false
                ]
            }
        }
        
        // 3. Update all pairs
        for ref in pairRefs {
            let pairRef = db.collection("pairs").document(ref.id).collection("daily").document(dateId)
            
            var updates: [String: Any] = ["updatedAt": FieldValue.serverTimestamp()]
            if isPrivate {
                // Clear data for partners
                updates["statusByUid.\(uid).windowDidCapture"] = false
                updates["statusByUid.\(uid).windowThumbPath"] = ""
                updates["statusByUid.\(uid).windowPhotoUrl"] = ""
                updates["statusByUid.\(uid).windowCapturedAt"] = FieldValue.delete()
                updates["statusByUid.\(uid).isPrivate"] = true
            } else if let restore = statusToUpdate {
                // Restore data for partners
                for (key, value) in restore {
                    updates["statusByUid.\(uid).\(key)"] = value
                }
            }
            
            do {
                try await pairRef.updateData(updates)
            } catch {
                // If updateData fails because the document doesn't exist, use setData
                if !isPrivate, let restore = statusToUpdate {
                    var fullData: [String: Any] = ["updatedAt": FieldValue.serverTimestamp()]
                    var statusByUid: [String: Any] = [:]
                    statusByUid[uid] = restore
                    fullData["statusByUid"] = statusByUid
                    try? await pairRef.setData(fullData, merge: true)
                }
            }
            
            // Phase 270: Update weekly progress lamp (treat private as false for partner)
            try? await self.updateWeeklyProgress(pairId: ref.id, date: date, status: !isPrivate)
        }
        
        // 4. Update local state
        await MainActor.run {
            if dateId == todayKey {
                var s = myToday
                s.isPrivate = isPrivate
                myToday = s
            } else if var s = myDaily[dateId] {
                s.isPrivate = isPrivate
                myDaily[dateId] = s
            }
            self.objectWillChange.send()
        }
    }

    func updateMyMemo(dateId: String, memo: String) async {
        guard let uid = Auth.auth().currentUser?.uid ?? authUid else { return }
        let db = Firestore.firestore()
        
        // 1. Update personal log
        let personalRef = db.collection("users").document(uid).collection("daily").document(dateId)
        try? await personalRef.setData([
            "memo": memo,
            "updatedAt": FieldValue.serverTimestamp()
        ], merge: true)
        // 2. Update pair logs
        for pair in pairRefs {
            let pairRef = db.collection("pairs").document(pair.id).collection("daily").document(dateId)
            let dotUpdates: [String: Any] = [
                "updatedAt": FieldValue.serverTimestamp(),
                "statusByUid.\(uid).memo": memo
            ]
            do {
                try await pairRef.updateData(dotUpdates)
            } catch {
                print("[PairStore] updateData (memo) failed, using safe merge fallback: \(error.localizedDescription)")
                let fallback: [String: Any] = [
                    "updatedAt": FieldValue.serverTimestamp(),
                    "statusByUid": [
                        uid: ["memo": memo]
                    ]
                ]
                try? await pairRef.setData(fallback, merge: true)
            }
        }
        
        // 3. Update local state
        await MainActor.run {
            if dateId == todayKey {
                myToday.memo = memo
            } else if var s = myDaily[dateId] {
                s.memo = memo
                myDaily[dateId] = s
            }
            self.objectWillChange.send()
        }
    }

    func updateMyTargetedMemo(pairId: String, dateId: String, memo: String) async {
        guard let uid = Auth.auth().currentUser?.uid ?? authUid else { return }
        let db = Firestore.firestore()
        
        // 1. Update personal log
        let personalRef = db.collection("users").document(uid).collection("daily").document(dateId)
        try? await personalRef.setData([
            "targetedMemo": memo,
            "updatedAt": FieldValue.serverTimestamp()
        ], merge: true)
        
        // 2. Update specific pair log
        let pairRef = db.collection("pairs").document(pairId).collection("daily").document(dateId)
        let dotUpdates: [String: Any] = [
            "updatedAt": FieldValue.serverTimestamp(),
            "statusByUid.\(uid).targetedMemo": memo
        ]
        do {
            try await pairRef.updateData(dotUpdates)
        } catch {
            print("[PairStore] updateMyTargetedMemo (updateData) failed, using safe merge fallback")
            let fallback: [String: Any] = [
                "updatedAt": FieldValue.serverTimestamp(),
                "statusByUid": [
                    uid: ["targetedMemo": memo]
                ]
            ]
            try? await pairRef.setData(fallback, merge: true)
        }
        
        // 3. Update local state
        await MainActor.run {
            if dateId == todayKey {
                myToday.targetedMemo = memo
            } else if var s = myDaily[dateId] {
                s.targetedMemo = memo
                myDaily[dateId] = s
            }
            self.objectWillChange.send()
        }
    }

    func updateMyRating(pairId: String, dateId: String, rating: Int) async {
        guard let uid = Auth.auth().currentUser?.uid ?? authUid else { return }
        let db = Firestore.firestore()
        let docRef = db.collection("pairs").document(pairId).collection("daily").document(dateId)
        
        let dotUpdates: [String: Any] = [
            "updatedAt": FieldValue.serverTimestamp(),
            "statusByUid.\(uid).rating": rating
        ]
        
        do {
            try await docRef.updateData(dotUpdates)
        } catch {
            print("[PairStore] updateData (rating) failed, using safe merge fallback: \(error.localizedDescription)")
            let fallback: [String: Any] = [
                "updatedAt": FieldValue.serverTimestamp(),
                "statusByUid": [
                    uid: ["rating": rating]
                ]
            ]
            try? await docRef.setData(fallback, merge: true)
        }
        
        // Update local state if it exists
        if dateId == todayKey {
            var s = myToday
            s.rating = rating
            myToday = s
            
            // Scoped update
            if var current = statusByPair[pairId] {
                var myStatus = current.statusByUid[uid] ?? TodayStatusModel.TodayUserStatus(windowDidCapture: false, windowThumbPath: nil, rating: nil)
                myStatus.rating = rating
                current.statusByUid[uid] = myStatus
                self.statusByPair[pairId] = current
            }
        } else if var s = myDaily[dateId] {
            s.rating = rating
            myDaily[dateId] = s
        }
    }


    func resetRatings(pairId: String, dateIds: [String]) async {
        guard let uid = Auth.auth().currentUser?.uid ?? authUid else { return }
        let db = Firestore.firestore()
        
        for dateId in dateIds {
            let docRef = db.collection("pairs").document(pairId).collection("daily").document(dateId)
            let updates: [String: Any] = [
                "updatedAt": FieldValue.serverTimestamp(),
                "statusByUid.\(uid).rating": -1
            ]
            
            do {
                try await docRef.updateData(updates)
                print("[DEBUG][RatingReset] OK \(dateId)")
            } catch {
                print("[ERROR][RatingReset] failed \(dateId): \(error)")
            }
        }
        
        // Reset local state in bulk
        await MainActor.run {
            for dateId in dateIds {
                if var s = myDaily[dateId] {
                    s.rating = -1
                    myDaily[dateId] = s
                }
            }
            if let todayRating = myToday.rating, todayRating != -1 {
                var s = myToday
                s.rating = -1
                myToday = s
            }
        }
    }
    
    /// [DEBUG] Delete own photo from Firestore/Storage and reset state
    func deleteMyPhoto(pairId: String, dateId: String) async throws {
        guard let uid = Auth.auth().currentUser?.uid ?? authUid else {
            print("[PairStore] updateProfile FAIL: authUnavailable (authUid=\(authUid ?? "nil"))")
            throw PairError.authUnavailable
        }
        let db = Firestore.firestore()
        let docRef = db.collection("pairs").document(pairId).collection("daily").document(dateId)
        
        await MainActor.run {
            self.isClearingWindowPhoto = true
        }
        
        defer {
            Task { @MainActor in
                self.isClearingWindowPhoto = false
            }
        }
        
        // 1. Fetch document once to get the Storage path
        let snap = try await docRef.getDocument()
        let data = snap.data() ?? [:]
        let status = (data["statusByUid"] as? [String: Any])?[uid] as? [String: Any] ?? [:]
        let storagePath = status["thumbPath"] as? String ?? ""
        
        // 2. Delete the physical file from Storage
        if !storagePath.isEmpty {
            do {
                try await CloudStorageService.shared.deleteImage(path: storagePath)
                print("[DEBUG][DeletePhoto] Storage deleted: \(storagePath)")
            } catch {
                print("[WARNING][DeletePhoto] Storage delete failed: \(error)")
            }
        }
        
        // 3. Identify and delete/reset own field in Firestore
        let updates: [String: Any] = [
            "updatedAt": FieldValue.serverTimestamp(),
            "statusByUid.\(uid).windowThumbPath": FieldValue.delete(),
            "statusByUid.\(uid).windowDidCapture": false,
            "statusByUid.\(uid).windowPhotoUrl": FieldValue.delete(),
            "statusByUid.\(uid).windowCapturedAt": FieldValue.delete()
        ]
        
        try await docRef.updateData(updates)
        print("[DEBUG][DeletePhoto] Firestore ROBUST update OK for \(dateId)")
        
        // 4. Update local in-memory state immediately
        await MainActor.run {
            if dateId == todayKey {
                var s = myToday
                s.windowDidCapture = false
                s.windowThumbRelativePath = nil
                myToday = s
            } else {
                myDaily.removeValue(forKey: dateId)
            }
            // Notify UI to refresh
            self.objectWillChange.send()
        }
    }

    /// [DEBUG] Delete Window photo from Firestore/Storage and reset state
    func deleteMyWindowPhoto(pairId: String, dateId: String) async throws {
        guard let uid = Auth.auth().currentUser?.uid ?? authUid else {
            throw PairError.authUnavailable
        }
        let db = Firestore.firestore()
        let docRef = db.collection("pairs").document(pairId).collection("daily").document(dateId)
        
        await MainActor.run {
            self.isClearingWindowPhoto = true
        }
        
        defer {
            Task { @MainActor in
                self.isClearingWindowPhoto = false
            }
        }
        
        let snap = try await docRef.getDocument()
        let data = snap.data() ?? [:]
        let status = (data["statusByUid"] as? [String: Any])?[uid] as? [String: Any] ?? [:]
        let storagePath = status["windowThumbPath"] as? String ?? ""
        
        if !storagePath.isEmpty {
            try? await CloudStorageService.shared.deleteImage(path: storagePath)
        }
        
        let updates: [String: Any] = [
            "updatedAt": FieldValue.serverTimestamp(),
            "statusByUid.\(uid).windowThumbPath": FieldValue.delete(),
            "statusByUid.\(uid).windowDidCapture": false,
            "statusByUid.\(uid).windowPhotoUrl": FieldValue.delete()
        ]
        
        try await docRef.updateData(updates)
        
        await MainActor.run {
            if dateId == todayKey {
                var s = myToday
                s.windowDidCapture = false
                s.windowThumbRelativePath = nil
                myToday = s
            }
            self.objectWillChange.send()
        }
    }

    // MARK: - Handle/Profile update (Unified)
    func updateProfile(nickname: String, handle: String) async throws {
        guard let uid = Auth.auth().currentUser?.uid ?? authUid else {
            print("[PairStore] updateProfile FAIL: authUnavailable (authUid=\(authUid ?? "nil"))")
            throw PairError.authUnavailable
        }
        
        let db = Firestore.firestore()
        let userRef = db.collection("users").document(uid)
        
        // Normalize handle: remove @, trim, lowercase
        let newHandle = handle.replacingOccurrences(of: "@", with: "").trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let oldHandle = self.myHandle.lowercased()
        
        // Handle change validation
        if !newHandle.isEmpty && newHandle != oldHandle {
            let regex = try NSRegularExpression(pattern: "^[a-z0-9._]{3,20}$")
            let range = NSRange(location: 0, length: (newHandle as NSString).length)
            guard regex.firstMatch(in: newHandle, options: [], range: range) != nil else {
                throw PairError.invalidHandle
            }
            
            // Cooldown check (30 days) - ONLY apply if oldHandle was NOT empty (i.e., a real change, not first time)
            if !oldHandle.isEmpty, let lastUpdated = self.myHandleUpdatedAt {
                let thirtyDays: TimeInterval = 30 * 24 * 3600
                if Date().timeIntervalSince(lastUpdated) < thirtyDays {
                    throw PairError.coolingDown
                }
            }
        }
        
        _ = try await db.runTransaction { (transaction, errorPointer) -> Any? in
            var userUpdates: [String: Any] = [
                "nickname": nickname.trimmingCharacters(in: .whitespacesAndNewlines),
                "updatedAt": FieldValue.serverTimestamp()
            ]
            
            // Handle uniqueness and update
            if !newHandle.isEmpty && newHandle != oldHandle {
                let handleRef = db.collection("handles").document(newHandle)
                let handleDoc: DocumentSnapshot
                do {
                    handleDoc = try transaction.getDocument(handleRef)
                } catch let fetchError as NSError {
                    errorPointer?.pointee = fetchError
                    return nil
                }
                
                if handleDoc.exists {
                    errorPointer?.pointee = NSError(domain: "PairStore", code: 409, userInfo: [NSLocalizedDescriptionKey: "Handle is already taken"])
                    return nil
                }
                
                // Release old handle
                if !oldHandle.isEmpty {
                    let oldHandleRef = db.collection("handles").document(oldHandle)
                    transaction.deleteDocument(oldHandleRef)
                }
                
                // Claim new handle
                transaction.setData([
                    "uid": uid,
                    "createdAt": FieldValue.serverTimestamp()
                ], forDocument: handleRef)
                
                userUpdates["handle"] = newHandle
                userUpdates["handleLower"] = newHandle
                userUpdates["handleUpdatedAt"] = FieldValue.serverTimestamp()
            }
            
            transaction.setData(userUpdates, forDocument: userRef, merge: true)
            return nil
        }
        
        print("[PairStore] updateProfile OK uid=\(uid)")
        
        // Clear cache
        nameCache.removeValue(forKey: uid)
        cacheUpdatedAt.removeValue(forKey: uid)
    }
    
    func checkHandleAvailability(_ handle: String) async throws -> Bool {
        let newHandle = handle.replacingOccurrences(of: "@", with: "").trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if newHandle.isEmpty { return true }
        
        let db = Firestore.firestore()
        let handleRef = db.collection("handles").document(newHandle)
        let handleDoc = try await handleRef.getDocument()
        
        if handleDoc.exists {
            let data = handleDoc.data()
            let currentUid = Auth.auth().currentUser?.uid ?? authUid
            if data?["uid"] as? String == currentUid {
                return true
            }
            return false
        }
        return true
    }

    /// Deprecated: use updateProfile
    func registerHandle(_ handle: String) async throws {
        try await updateProfile(nickname: self.myNickname, handle: handle)
    }

    // MARK: - Nickname update
    /// Updates users/{uid}.nickname
    func updateNickname(_ nickname: String) async throws {
        let trimmed = nickname.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        guard let uid = Auth.auth().currentUser?.uid ?? authUid else {
            print("[PairStore] updateNickname FAIL: authUnavailable (authUid=\(authUid ?? "nil"))")
            throw PairError.authUnavailable
        }

        let db = Firestore.firestore()
        try await db.collection("users").document(uid).setData([
            "uid": uid,
            "nickname": trimmed,
            "updatedAt": FieldValue.serverTimestamp()
        ], merge: true)

        print("[PairStore] updateNickname OK uid=\(uid) nickname=\(trimmed)")

        // invalidate self cache so next read refetches
        if let uid = Auth.auth().currentUser?.uid ?? authUid {
            nameCache.removeValue(forKey: uid)
            cacheUpdatedAt.removeValue(forKey: uid)
        }
    }
    
    /// Updates users/{uid}.avatarPath (thumb), avatarFullPath, and avatarUpdatedAt
    func updateAvatarMetadata(fullPath: String, thumbPath: String) async throws {
        guard let uid = Auth.auth().currentUser?.uid ?? authUid else {
            print("[PairStore] updateAvatarMetadata FAIL: authUnavailable (authUid=\(authUid ?? "nil"))")
            throw PairError.authUnavailable
        }

        let db = Firestore.firestore()
        try await db.collection("users").document(uid).setData([
            "avatarPath": thumbPath,
            "avatarFullPath": fullPath,
            "avatarUpdatedAt": FieldValue.serverTimestamp()
        ], merge: true)

        print("[PairStore] updateAvatarMetadata OK uid=\(uid) fullPath=\(fullPath) thumbPath=\(thumbPath)")
    }
    
    // MARK: - Birthdate update
    func updateBirthdate(_ birthdate: Date) async throws {
        guard let uid = Auth.auth().currentUser?.uid ?? authUid else {
            print("[PairStore] updateBirthdate FAIL: authUnavailable (authUid=\(authUid ?? "nil"))")
            throw PairError.authUnavailable
        }
        
        let db = Firestore.firestore()
        try await db.collection("users").document(uid).setData([
            "birthdate": Timestamp(date: birthdate),
            "updatedAt": FieldValue.serverTimestamp()
        ], merge: true)
        
        print("[PairStore] updateBirthdate OK uid=\(uid) birthdate=\(birthdate)")
    }
    

    // MARK: - Privacy setting
    func updatePrivacy(isPrivate: Bool) async throws {
        guard let uid = Auth.auth().currentUser?.uid ?? authUid else {
            throw PairError.authUnavailable
        }
        
        let db = Firestore.firestore()
        try await db.collection("users").document(uid).setData([
            "isPrivate": isPrivate,
            "updatedAt": FieldValue.serverTimestamp()
        ], merge: true)
        
        print("[PairStore] updatePrivacy OK uid=\(uid) isPrivate=\(isPrivate)")
    }
    
    // MARK: - Invites (Firestore)
    struct UserSummary: Identifiable {
        let id: String // uid
        let nickname: String
        let handle: String
        let avatarPath: String?
        let avatarUpdatedAt: Date?
    }
    
    // users/{uid}: { uid: String, handle: String, ... }
    // invites/{inviteId}: { fromUid, toUid, status, createdAt, updatedAt }
    func searchUser(byHandle handle: String) async throws -> UserSummary {
        let normalized = handle.replacingOccurrences(of: "@", with: "").trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !normalized.isEmpty else { throw PairError.invalidHandle }
        
        let db = Firestore.firestore()
        let snap = try await db.collection("users")
            .whereField("handleLower", isEqualTo: normalized)
            .limit(to: 1)
            .getDocuments()
            
        guard let doc = snap.documents.first else {
            throw PairError.handleNotFound
        }
        
        let data = doc.data()
        if (data["isPrivate"] as? Bool) == true {
            throw PairError.handleNotFound
        }
        let uid = doc.documentID
        let nickname = data["nickname"] as? String ?? ""
        let avatarPath = data["avatarPath"] as? String
        let avatarUpdatedAt = (data["avatarUpdatedAt"] as? Timestamp)?.dateValue()
        
        return UserSummary(
            id: uid,
            nickname: nickname,
            handle: normalized,
            avatarPath: avatarPath,
            avatarUpdatedAt: avatarUpdatedAt
        )
    }

    func sendInvite(toUid: String) async throws {
        guard let fromUid = currentUid else { throw PairError.authUnavailable }
        if toUid == fromUid { throw PairError.forbidden }
        
        let db = Firestore.firestore()
        let myInviteRef = db.collection("pairInvites").document("\(fromUid)_\(toUid)")
        let partnerInviteRef = db.collection("pairInvites").document("\(toUid)_\(fromUid)")
        let pairId = deterministicPairId(u1: fromUid, u2: toUid)
        let pairRef = db.collection("pairs").document(pairId)
        
        let u1 = min(fromUid, toUid)
        let u2 = max(fromUid, toUid)
        let u1Ref = db.collection("users").document(u1)
        let u2Ref = db.collection("users").document(u2)
        let myHiddenRef = db.collection("users").document(fromUid).collection("hiddenPairIds").document(pairId)
        
        let result = try await db.runTransaction { (transaction, errorPointer) -> Any? in
            // 1. Get incoming invite from partner
            let partnerInviteSnap: DocumentSnapshot
            do { partnerInviteSnap = try transaction.getDocument(partnerInviteRef) } catch {
                errorPointer?.pointee = error as NSError; return nil
            }
            
            let hasIncomingPending = (partnerInviteSnap.data()?["status"] as? String) == "pending"
            
            // 2. Already paired?
            let pairSnap: DocumentSnapshot
            do { pairSnap = try transaction.getDocument(pairRef) } catch {
                errorPointer?.pointee = error as NSError; return nil
            }
            
            // Orphaned pair check: If pair doc is active but my own refs are missing, treat as archived
            let myPairRefDoc = db.collection("users").document(fromUid).collection("pairRefs").document(pairId)
            let myPairRefSnap: DocumentSnapshot
            do { myPairRefSnap = try transaction.getDocument(myPairRefDoc) } catch {
                errorPointer?.pointee = error as NSError; return nil
            }

            if pairSnap.exists && (pairSnap.data()?["archived"] as? Bool) != true {
                if myPairRefSnap.exists {
                    print("[PairStore][sendInvite] Already paired found. pairId=\(pairId). Ensuring UNHIDDEN.")
                    transaction.deleteDocument(myHiddenRef)
                    return "already_paired"
                } else {
                    print("[PairStore][Inconsistency] Found active pair \(pairId) but missing my pairRef. Allowing re-pair fall-through.")
                }
            } else {
                print("[PairStore][sendInvite] No active pair found or archived: \(pairId)")
            }
            
            // 3. Check pair capacity
            let u1Snap: DocumentSnapshot
            let u2Snap: DocumentSnapshot
            do {
                u1Snap = try transaction.getDocument(u1Ref)
                u2Snap = try transaction.getDocument(u2Ref)
            } catch {
                errorPointer?.pointee = error as NSError; return nil
            }
            let u1Count = (u1Snap.data()?["pairCount"] as? Int) ?? 0
            let u2Count = (u2Snap.data()?["pairCount"] as? Int) ?? 0
            if u1Count >= 5 || u2Count >= 5 {
                print("[PairStore][sendInvite] maxPairsReached: u1(\(u1))=\(u1Count), u2(\(u2))=\(u2Count)")
                errorPointer?.pointee = NSError(domain: "PairStore", code: 422, userInfo: [NSLocalizedDescriptionKey: "maxPairsReached"])
                return nil
            }

            if hasIncomingPending {
                // AUTO-PAIRING
                // A) Update both invites to "paired"
                transaction.setData([
                    "fromUid": fromUid, "toUid": toUid, "status": "paired",
                    "createdAt": FieldValue.serverTimestamp(), "updatedAt": FieldValue.serverTimestamp()
                ], forDocument: myInviteRef, merge: true)
                
                transaction.updateData([
                    "status": "paired", "updatedAt": FieldValue.serverTimestamp()
                ], forDocument: partnerInviteRef)
                
                // B) Create/Re-activate Pair
                let now = Date()
                let localDate = now.yyyyMMdd
                let weekKey = now.startOfWeekKey
                let dayIndex = now.isoWeekdayIndex
                let reqDays = 7 - dayIndex
                
                transaction.setData([
                    "u1": u1, "u2": u2, "memberUids": [u1, u2], "type": "dm",
                    "archived": false, "createdAt": FieldValue.serverTimestamp(), "updatedAt": FieldValue.serverTimestamp(),
                    "pairedAt": FieldValue.serverTimestamp(),
                    "pairedLocalDate": localDate,
                    "pairedWeekKey": weekKey
                ], forDocument: pairRef, merge: true)
                
                // Force initialize the week document
                let firstWeekRef = db.collection("pairs").document(pairId).collection("weeks").document(weekKey)
                let initialProgress = WeekProgress.empty(id: weekKey, uids: [u1, u2], required: reqDays)
                transaction.setData([
                    "id": initialProgress.id,
                    "dailyDoneByUid": initialProgress.dailyDoneByUid,
                    "doneCountByUid": initialProgress.doneCountByUid,
                    "requiredDays": initialProgress.requiredDays,
                    "unlocked": initialProgress.unlocked,
                    "updatedAt": FieldValue.serverTimestamp()
                ], forDocument: firstWeekRef)
                
                // C) Update Users & pairRefs
                transaction.setData(["uid": u1, "pairCount": u1Count + 1, "updatedAt": FieldValue.serverTimestamp()], forDocument: u1Ref, merge: true)
                transaction.setData(["uid": u2, "pairCount": u2Count + 1, "updatedAt": FieldValue.serverTimestamp()], forDocument: u2Ref, merge: true)
                
                let u1PairRef = u1Ref.collection("pairRefs").document(pairId)
                let u2PairRef = u2Ref.collection("pairRefs").document(pairId)
                
                // Pre-read hidden status for safety in transactions
                let h1Ref = u1Ref.collection("hiddenPairIds").document(pairId)
                let h2Ref = u2Ref.collection("hiddenPairIds").document(pairId)
                _ = try? transaction.getDocument(h1Ref)
                _ = try? transaction.getDocument(h2Ref)

                transaction.setData(["pairId": pairId, "otherUid": u2, "createdAt": FieldValue.serverTimestamp()], forDocument: u1PairRef, merge: true)
                transaction.setData(["pairId": pairId, "otherUid": u1, "createdAt": FieldValue.serverTimestamp()], forDocument: u2PairRef, merge: true)
                
                // Ensure unhidden on both sides for new pairs
                transaction.deleteDocument(h1Ref)
                transaction.deleteDocument(h2Ref)

                print("[PairStore][sendInvite] AUTO-PAIRED success path")
                return "paired"
            } else {
                // JUST SENDING INVITE
                print("[PairStore][sendInvite] Sending initial pending invite")
                transaction.setData([
                    "fromUid": fromUid, "toUid": toUid, "status": "pending",
                    "createdAt": FieldValue.serverTimestamp(), "updatedAt": FieldValue.serverTimestamp()
                ], forDocument: myInviteRef, merge: true)
                
                // Pre-read hidden status
                let h1Ref = u1Ref.collection("hiddenPairIds").document(pairId)
                let h2Ref = u2Ref.collection("hiddenPairIds").document(pairId)
                _ = try? transaction.getDocument(h1Ref)
                _ = try? transaction.getDocument(h2Ref)
                
                // Ensure unhidden on both sides
                transaction.deleteDocument(h1Ref)
                transaction.deleteDocument(h2Ref)

                return "pending"
            }
        }

        if let res = result as? String {
            print("[PairStore][sendInvite] Transaction FINISHED with result: \(res)")
            if res == "already_paired" {
                throw PairError.alreadyPaired
            }
        } else {
            print("[PairStore][sendInvite] Transaction finished with non-string result: \(String(describing: result))")
        }
    }

    private func deterministicPairId(u1: String, u2: String) -> String {
        let a = min(u1, u2)
        let b = max(u1, u2)
        return "\(a)_\(b)"
    }

    func acceptInvite(_ inviteId: String) async throws {
        let db = Firestore.firestore()
        guard let me = Auth.auth().currentUser?.uid ?? authUid else { throw PairError.authUnavailable }

        do {
            let result = try await db.runTransaction { (transaction, errorPointer) -> Any? in
                let inviteRef = db.collection("pairInvites").document(inviteId)
                let inviteSnap: DocumentSnapshot
                do { inviteSnap = try transaction.getDocument(inviteRef) } catch {
                    errorPointer?.pointee = error as NSError; return nil
                }
                guard let inv = inviteSnap.data() else {
                    errorPointer?.pointee = NSError(domain: "PairStore", code: 404, userInfo: [NSLocalizedDescriptionKey: "invite not found"])
                    return nil
                }
                let fromUid = inv["fromUid"] as? String ?? ""
                let toUid = inv["toUid"] as? String ?? ""
                let status = inv["status"] as? String ?? ""
                guard !fromUid.isEmpty, !toUid.isEmpty else {
                    errorPointer?.pointee = NSError(domain: "PairStore", code: 400, userInfo: [NSLocalizedDescriptionKey: "invalid invite fields"])
                    return nil
                }
                // recipient only
                guard toUid == me else {
                    errorPointer?.pointee = NSError(domain: "PairStore", code: 403, userInfo: [NSLocalizedDescriptionKey: "forbidden"])
                    return nil
                }
                // pending only
                guard status == "pending" else {
                    errorPointer?.pointee = NSError(domain: "PairStore", code: 409, userInfo: [NSLocalizedDescriptionKey: "alreadyProcessed"])
                    return nil
                }

                let a = min(fromUid, toUid)
                let b = max(fromUid, toUid)
                let pairId = "\(a)_\(b)"

                let pairRef = db.collection("pairs").document(pairId)
                let pairSnap: DocumentSnapshot
                do { pairSnap = try transaction.getDocument(pairRef) } catch {
                    errorPointer?.pointee = error as NSError; return nil
                }

                let u1Ref = db.collection("users").document(a)
                let u2Ref = db.collection("users").document(b)
                let u1Snap: DocumentSnapshot
                let u2Snap: DocumentSnapshot
                do {
                    u1Snap = try transaction.getDocument(u1Ref)
                    u2Snap = try transaction.getDocument(u2Ref)
                } catch {
                    errorPointer?.pointee = error as NSError; return nil
                }
                let u1Count = (u1Snap.exists ? (u1Snap.data()? ["pairCount"] as? Int) : nil) ?? 0
                let u2Count = (u2Snap.exists ? (u2Snap.data()? ["pairCount"] as? Int) : nil) ?? 0
                if u1Count >= 5 || u2Count >= 5 {
                    errorPointer?.pointee = NSError(domain: "PairStore", code: 422, userInfo: [NSLocalizedDescriptionKey: "maxPairsReached"])
                    return nil
                }

                // pairRefs read for createdAt protection
                let u1PairRef = u1Ref.collection("pairRefs").document(pairId)
                let u2PairRef = u2Ref.collection("pairRefs").document(pairId)
                let u1PairSnap: DocumentSnapshot
                let u2PairSnap: DocumentSnapshot
                do {
                    u1PairSnap = try transaction.getDocument(u1PairRef)
                    u2PairSnap = try transaction.getDocument(u2PairRef)
                } catch {
                    errorPointer?.pointee = error as NSError; return nil
                }

                // ---- WRITES ----
                if !pairSnap.exists {
                    transaction.setData([
                        "u1": a,
                        "u2": b,
                        "memberUids": [a, b],
                        "type": "dm",
                        "inviteId": inviteId,
                        "archived": false,
                        "createdAt": FieldValue.serverTimestamp(),
                        "updatedAt": FieldValue.serverTimestamp()
                    ], forDocument: pairRef, merge: false)
                } else {
                    transaction.updateData([
                        "archived": false,
                        "updatedAt": FieldValue.serverTimestamp()
                    ], forDocument: pairRef)
                }

                transaction.updateData([
                    "status": "accepted",
                    "acceptedAt": FieldValue.serverTimestamp(),
                    "acceptedBy": me,
                    "pairId": pairId,
                    "updatedAt": FieldValue.serverTimestamp()
                ], forDocument: inviteRef)

                transaction.setData(["uid": a, "pairCount": u1Count + 1, "updatedAt": FieldValue.serverTimestamp()], forDocument: u1Ref, merge: true)
                transaction.setData(["uid": b, "pairCount": u2Count + 1, "updatedAt": FieldValue.serverTimestamp()], forDocument: u2Ref, merge: true)

                if !u1PairSnap.exists {
                    transaction.setData(["pairId": pairId, "otherUid": b, "createdAt": FieldValue.serverTimestamp()], forDocument: u1PairRef, merge: true)
                } else {
                    transaction.setData(["pairId": pairId, "otherUid": b], forDocument: u1PairRef, merge: true)
                }
                if !u2PairSnap.exists {
                    transaction.setData(["pairId": pairId, "otherUid": a, "createdAt": FieldValue.serverTimestamp()], forDocument: u2PairRef, merge: true)
                } else {
                    transaction.setData(["pairId": pairId, "otherUid": a], forDocument: u2PairRef, merge: true)
                }
                
                // Clear hidden status for both
                transaction.deleteDocument(u1Ref.collection("hiddenPairIds").document(pairId))
                transaction.deleteDocument(u2Ref.collection("hiddenPairIds").document(pairId))

                return [
                    "pairId": pairId,
                    "fromUid": fromUid,
                    "toUid": toUid
                ] as Any
            }
            if let info = result as? [String: String],
               let pairId = info["pairId"],
               let fromUid = info["fromUid"],
               let toUid = info["toUid"] {
                print("[PairStore] acceptInvite OK id=\(inviteId) pairId=\(pairId)")
                
                // 🔥 Initial backfill from personal logs
                Task {
                    await self.initialPairSync(pairId: pairId, uids: [fromUid, toUid])
                }
            } else {
                print("[PairStore] acceptInvite OK id=\(inviteId)")
            }

            await MainActor.run {
                self.inbox.removeAll { $0.id == inviteId }
            }
            // Read back the invite to confirm status
            do {
                let snap = try await db.collection("pairInvites").document(inviteId).getDocument()
                let data = snap.data() ?? [:]
                print("[PairStore][InviteAfterAccept] id=\(inviteId) status=\(data["status"] ?? "nil") toUid=\(data["toUid"] ?? "nil")")
            } catch {
                print("[PairStore][InviteAfterAccept] readback failed id=\(inviteId) error=\(error)")
            }
        } catch {
            let ns = error as NSError
            print("[PairStore][acceptInvite] failed domain=\(ns.domain) code=\(ns.code) desc=\(ns.localizedDescription) userInfo=\(ns.userInfo)")
            switch ns.code {
            case 403: throw PairError.forbidden
            case 409:
                if ns.userInfo[NSLocalizedDescriptionKey] as? String == "alreadyPaired" { throw PairError.alreadyPairedWithSameUser }
                else { throw PairError.alreadyProcessed }
            case 422: throw PairError.maxPairsReached
            default: throw error
            }
        }
    }

    func unpair(pairId: String) async throws {
        let db = Firestore.firestore()
        guard let me = Auth.auth().currentUser?.uid ?? authUid else { throw PairError.authUnavailable }

        do {
            _ = try await db.runTransaction { (transaction, errorPointer) -> Any? in
                let pairRef = db.collection("pairs").document(pairId)

                // ---- READS (must be before writes) ----
                let pairSnap: DocumentSnapshot
                do { pairSnap = try transaction.getDocument(pairRef) }
                catch { errorPointer?.pointee = error as NSError; return nil }

                guard let pair = pairSnap.data() else {
                    errorPointer?.pointee = NSError(domain: "PairStore", code: 404,
                        userInfo: [NSLocalizedDescriptionKey: "pair not found"])
                    return nil
                }

                let u1 = pair["u1"] as? String ?? ""
                let u2 = pair["u2"] as? String ?? ""
                guard !u1.isEmpty, !u2.isEmpty else {
                    errorPointer?.pointee = NSError(domain: "PairStore", code: 400,
                        userInfo: [NSLocalizedDescriptionKey: "invalid pair fields"])
                    return nil
                }
                guard u1 == me || u2 == me else {
                    errorPointer?.pointee = NSError(domain: "PairStore", code: 403,
                        userInfo: [NSLocalizedDescriptionKey: "forbidden"])
                    return nil
                }

                let alreadyArchived = (pair["archived"] as? Bool) == true

                let u1Ref = db.collection("users").document(u1)
                let u2Ref = db.collection("users").document(u2)

                // Read user docs (needed if we decrement counts; keep in read phase)
                let u1Snap: DocumentSnapshot
                let u2Snap: DocumentSnapshot
                do {
                    u1Snap = try transaction.getDocument(u1Ref)
                    u2Snap = try transaction.getDocument(u2Ref)
                } catch {
                    errorPointer?.pointee = error as NSError; return nil
                }

                // ---- WRITES ----
                if !alreadyArchived {
                    transaction.updateData([
                        "archived": true,
                        "archivedAt": FieldValue.serverTimestamp(),
                        "archivedBy": me,
                        "updatedAt": FieldValue.serverTimestamp()
                    ], forDocument: pairRef)
                }

                // Always delete pairRefs (idempotent cleanup)
                transaction.deleteDocument(u1Ref.collection("pairRefs").document(pairId))
                transaction.deleteDocument(u2Ref.collection("pairRefs").document(pairId))

                // Decrement pairCount only on first archive
                if !alreadyArchived {
                    let c1 = max(((u1Snap.data()? ["pairCount"] as? Int) ?? 0) - 1, 0)
                    let c2 = max(((u2Snap.data()? ["pairCount"] as? Int) ?? 0) - 1, 0)
                    transaction.setData([
                        "uid": u1,
                        "pairCount": c1,
                        "updatedAt": FieldValue.serverTimestamp()
                    ], forDocument: u1Ref, merge: true)
                    transaction.setData([
                        "uid": u2,
                        "pairCount": c2,
                        "updatedAt": FieldValue.serverTimestamp()
                    ], forDocument: u2Ref, merge: true)
                }

                return nil
            }

            print("[PairStore] unpair OK pairId=\(pairId)")

        } catch {
            // Preserve existing error mapping if needed by callers
            let ns = error as NSError
            switch ns.code {
            case 403: throw PairError.forbidden
            case 409: throw PairError.alreadyProcessed
            default: throw error
            }
        }
    }

    func declineInvite(_ inviteId: String) async throws {
        let db = Firestore.firestore()
        try await db.collection("pairInvites").document(inviteId).updateData([
            "status": "canceled",
            "updatedAt": FieldValue.serverTimestamp()
        ])
    }
    
    func cancelInvite(_ inviteId: String) async throws {
        let db = Firestore.firestore()
        try await db.collection("pairInvites").document(inviteId).updateData([
            "status": "canceled",
            "updatedAt": FieldValue.serverTimestamp()
        ])
    }

    // MARK: - SessionStore compatibility

    /// Used by SessionStore: returns signed-in uid (judging only by FirebaseAuth status)
    @MainActor
    // MARK: - Auth (Unified login handled by SessionStore)

    /// Legacy API compatibility: kept as it's called from SessionStore (updates authUid and starts listener internally)
    func startFirebaseSync(authUid: String) async throws {
        self.authUid = authUid
        self.startInviteListeners()
        self.startPairRefsListener()
    }

    // MARK: - Display name helpers
    private func displayName(from data: [String: Any], uid: String) -> String {
        if let nick = data["nickname"] as? String, !nick.isEmpty { return nick }
        return "@" + String(uid.prefix(6))
    }

    struct PartnerProfileInfo: Codable {
        var name: String
        var handle: String
        var avatarPath: String?
        var avatarUpdatedAt: Date?
    }
    
    // MARK: - Profile fetching (with cache)
    private var partnerProfileCache: [String: PartnerProfileInfo] = [:]
    private var inflightProfileFetch: [String: Task<PartnerProfileInfo, Error>] = [:]

    /// Get partner profile with in-memory cache and inflight coalescing
    func getPartnerProfile(uid: String) async throws -> PartnerProfileInfo {
        if uid.isEmpty { return PartnerProfileInfo(name: "Unknown", handle: "", avatarPath: nil, avatarUpdatedAt: nil) }
        
        // return from cache if present
        if let cached = partnerProfileCache[uid] { return cached }

        // if inflight exists, await it
        if let task = inflightProfileFetch[uid] {
            return try await task.value
        }

        let db = Firestore.firestore()
        let task = Task<PartnerProfileInfo, Error> {
            defer { inflightProfileFetch[uid] = nil }
            let snap = try await db.collection("users").document(uid).getDocument()
            let data = snap.data() ?? [:]
            
            let name = displayName(from: data, uid: uid)
            let handle = data["handle"] as? String ?? ""
            let avatarPath = data["avatarPath"] as? String
            let avatarUpdatedAt = (data["avatarUpdatedAt"] as? Timestamp)?.dateValue()
            
            let info = PartnerProfileInfo(
                name: name,
                handle: handle,
                avatarPath: avatarPath,
                avatarUpdatedAt: avatarUpdatedAt
            )
            
            partnerProfileCache[uid] = info
            savePartnerProfileCache() // Phase 291: Update cache
            return info
        }
        inflightProfileFetch[uid] = task
        return try await task.value
    }

    // MARK: - Weekly Unlock Transaction (Phase 93)
    
    func updateWeeklyProgress(pairId: String, date: Date, status: Bool? = true, uid: String? = nil) async throws {
        guard let myUid = uid ?? currentUid else { throw PairError.authUnavailable }
        let weekKey = date.startOfWeekKey
        let dayIndex = date.isoWeekdayIndex // 0..6
        
        let db = Firestore.firestore()
        let pairRef = db.collection("pairs").document(pairId)
        let weekRef = pairRef.collection("weeks").document(weekKey)
        
        _ = try await db.runTransaction { (transaction, errorPointer) -> Any? in
            // 0. Fetch Pair Info for Pairing Date
            let pairSnap: DocumentSnapshot
            do { pairSnap = try transaction.getDocument(pairRef) } catch {
                errorPointer?.pointee = error as NSError; return nil
            }
            let pairedLocalDate = pairSnap.data()?["pairedLocalDate"] as? String
            let pairedWeekKey = pairSnap.data()?["pairedWeekKey"] as? String
            
            // 1. Fetch WeekProgress
            let weekSnap: DocumentSnapshot
            do { weekSnap = try transaction.getDocument(weekRef) } catch {
                errorPointer?.pointee = error as NSError; return nil
            }
            
            var progress: WeekProgress
            if weekSnap.exists {
                do {
                    progress = try weekSnap.data(as: WeekProgress.self)
                } catch {
                    let data = weekSnap.data() ?? [:]
                    progress = WeekProgress(
                        id: weekKey,
                        dailyDoneByUid: data["dailyDoneByUid"] as? [String: [Bool]] ?? [:],
                        doneCountByUid: data["doneCountByUid"] as? [String: Int] ?? [:],
                        requiredDays: data["requiredDays"] as? Int ?? 7,
                        unlocked: data["unlocked"] as? Bool ?? false,
                        unlockedAt: (data["unlockedAt"] as? Timestamp)?.dateValue(),
                        updatedAt: (data["updatedAt"] as? Timestamp)?.dateValue() ?? Date()
                    )
                }
            } else {
                let uids = pairId.components(separatedBy: "_")
                // Calculate requiredDays for Mid-week pairing
                var req = 7
                if let pWeek = pairedWeekKey, pWeek == weekKey, let pLocal = pairedLocalDate {
                    if let index = Date.isoWeekdayIndex(from: pLocal) {
                        req = 7 - index // Index 0(Mon) -> 7, Index 2(Wed) -> 5, Index 6(Sun) -> 1
                    }
                }
                progress = WeekProgress.empty(id: weekKey, uids: uids, required: req)
            }
            
            var myDaily = progress.dailyDoneByUid[myUid] ?? Array(repeating: false, count: 7)
            
            if let targetStatus = status {
                myDaily[dayIndex] = targetStatus
            }
            
            progress.dailyDoneByUid[myUid] = myDaily
            progress.doneCountByUid[myUid] = myDaily.filter { $0 }.count
            progress.updatedAt = Date()
            
            // 2. Check for Unlock (Mutual requiredDays achieved)
            if !progress.unlocked {
                let uids = pairId.components(separatedBy: "_")
                let countA = progress.doneCountByUid[uids[0]] ?? 0
                let countB = progress.doneCountByUid[uids[1]] ?? 0
                let req = progress.requiredDays
                
                if countA >= req && countB >= req {
                    progress.unlocked = true
                    progress.unlockedAt = Date()
                }
            }
            
            do {
                try transaction.setData(from: progress, forDocument: weekRef)
            } catch {
                errorPointer?.pointee = error as NSError; return nil
            }
            
            return "ok"
        }
    }
    
    func addWeeklyPhotoRef(pairId: String, date: Date, thumbPath: String, fullPath: String) async {
        guard let myUid = currentUid else { return }
        let weekKey = date.startOfWeekKey
        let dayIndex = date.isoWeekdayIndex
        
        let db = Firestore.firestore()
        let photoRef = db.collection("pairs").document(pairId)
            .collection("weeks").document(weekKey)
            .collection("photos").document("\(myUid)_\(dayIndex)")
        
        let data: [String: Any] = [
            "ownerUid": myUid,
            "dayIndex": dayIndex,
            "date": date.yyyyMMdd,
            "thumbPath": thumbPath,
            "fullPath": fullPath,
            "createdAt": FieldValue.serverTimestamp()
        ]
        
        try? await photoRef.setData(data, merge: true)
    }

    // MARK: - Privacy Management (Block, Hide, Mute)
    func startPrivacyListeners() {
        guard let uid = Auth.auth().currentUser?.uid ?? authUid else { return }
        let db = Firestore.firestore()
        let userRef = db.collection("users").document(uid)
        
        // Blocked Users
        blockedUidsListener = userRef.collection("blockedUids").addSnapshotListener { [weak self] snap, _ in
            let ids = snap?.documents.map { $0.documentID } ?? []
            Task { @MainActor in self?.blockedUids = ids }
        }
        
        // Hidden Pairs
        hiddenPairsListener = userRef.collection("hiddenPairIds").addSnapshotListener { [weak self] snap, _ in
            let ids = snap?.documents.map { $0.documentID } ?? []
            Task { @MainActor in self?.hiddenPairIds = ids }
        }
        
        // Muted Users
        mutedUidsListener = userRef.collection("mutedUids").addSnapshotListener { [weak self] snap, _ in
            let ids = snap?.documents.map { $0.documentID } ?? []
            Task { @MainActor in self?.mutedUids = ids }
        }
    }
    
    func stopPrivacyListeners() {
        blockedUidsListener?.remove()
        hiddenPairsListener?.remove()
        mutedUidsListener?.remove()
        blockedUids = []
        hiddenPairIds = []
        mutedUids = []
    }
    
    func blockUser(uid: String) async throws {
        guard let myUid = Auth.auth().currentUser?.uid ?? authUid else { return }
        let db = Firestore.firestore()
        
        // Optimistic update
        await MainActor.run {
            if !blockedUids.contains(uid) {
                blockedUids.append(uid)
            }
        }
        
        // 1. Unpair if exists
        let pairId1 = "\(myUid)_\(uid)"
        let pairId2 = "\(uid)_\(myUid)"
        try? await unpair(pairId: pairId1)
        try? await unpair(pairId: pairId2)
        
        // 2. Add to blockedUids
        try await db.collection("users").document(myUid).collection("blockedUids").document(uid).setData([
            "createdAt": FieldValue.serverTimestamp()
        ])
    }
    
    func unblockUser(uid: String) async throws {
        guard let myUid = Auth.auth().currentUser?.uid ?? authUid else { return }
        print("[PairStore][unblock] uid=\(uid) for me=\(myUid)")
        
        // Optimistic update
        await MainActor.run {
            self.blockedUids.removeAll { $0 == uid }
            print("[PairStore][unblock] Optimistic update done. Remaining=\(self.blockedUids.count)")
        }
        
        let db = Firestore.firestore()
        try await db.collection("users").document(myUid).collection("blockedUids").document(uid).delete()
        print("[PairStore][unblock] Firestore delete SUCCESS")
    }
    
    func hidePair(pairId: String) async throws {
        guard let myUid = Auth.auth().currentUser?.uid ?? authUid else { return }
        
        // Optimistic update
        await MainActor.run {
            if !hiddenPairIds.contains(pairId) {
                hiddenPairIds.append(pairId)
            }
        }
        
        let db = Firestore.firestore()
        try await db.collection("users").document(myUid).collection("hiddenPairIds").document(pairId).setData([
            "createdAt": FieldValue.serverTimestamp()
        ])
    }
    
    func unhidePair(pairId: String) async throws {
        guard let myUid = Auth.auth().currentUser?.uid ?? authUid else { return }
        
        // Optimistic update
        await MainActor.run {
            hiddenPairIds.removeAll { $0 == pairId }
        }
        
        let db = Firestore.firestore()
        try await db.collection("users").document(myUid).collection("hiddenPairIds").document(pairId).delete()
    }
    
    func toggleMuteUser(uid: String) async throws {
        guard let myUid = Auth.auth().currentUser?.uid ?? authUid else { return }
        
        // Optimistic update
        await MainActor.run {
            if mutedUids.contains(uid) {
                mutedUids.removeAll { $0 == uid }
            } else {
                mutedUids.append(uid)
            }
        }
        
        let db = Firestore.firestore()
        let ref = db.collection("users").document(myUid).collection("mutedUids").document(uid)
        
        if mutedUids.contains(uid) {
            // Re-check after potential race, but usually fine
            try await ref.setData(["createdAt": FieldValue.serverTimestamp()])
        } else {
            try await ref.delete()
        }
    }
    
    func reportUser(uid: String, reason: String) async throws {
        let db = Firestore.firestore()
        try await db.collection("reports").addDocument(data: [
            "reporterUid": authUid ?? "",
            "reportedUid": uid,
            "reason": reason,
            "createdAt": FieldValue.serverTimestamp()
        ])
    }

    private func syncPairCountWithActualRefs(uid: String, count: Int) {
        let db = Firestore.firestore()
        let userRef = db.collection("users").document(uid)
        
        Task {
            do {
                let snap = try await userRef.getDocument()
                let currentCount = (snap.data()?["pairCount"] as? Int) ?? 0
                if currentCount != count {
                    print("[PairStore] 🛠️ Auto-repairing pairCount for \(uid): \(currentCount) -> \(count)")
                    try await userRef.setData(["pairCount": count, "updatedAt": FieldValue.serverTimestamp()], merge: true)
                }
            } catch {
                print("[ERROR][PairStore] Failed to sync pairCount: \(error)")
            }
        }
    }

    /// Clears all local state and stops all listeners (Called on sign out)
    func resetAllData() {
        print("[PairStore] 🗑️ Resetting all data")
        
        // Stop all listeners
        stopAllPairSync()
        stopInviteListeners()
        stopMyProfileListener()
        
        // Reset published properties
        authUid = nil
        profile = .init()
        myNickname = ""
        myHandle = ""
        myHandleUpdatedAt = nil
        myAvatarPath = ""
        myAvatarUpdatedAt = nil
        myBirthdate = nil
        isPrivate = false
        inbox = []
        outbox = []
        pairRefs = []
        blockedUids = []
        hiddenPairIds = []
        mutedUids = []
        pendingInviteCount = 0
        statusByPair = [:]
        weeklyProgressByPair = [:]
        
        // Reset legacy / legacy-compatible daily states
        myDaily = [:]
        partnerDaily = [:]
        searchUserPhotos = [:]
        canLoadMoreDaily = true
        isLoadingMoreDaily = false
        canLoadMoreSearch = true
        isLoadingMoreSearch = false
        lastDailyDocument = nil
        lastSearchDocument = nil
        deletedKeys = []
        isClearingWindowPhoto = false
        
        // Clear caches
        nameCache.removeAll()
        cacheUpdatedAt.removeAll()
        inflightNameFetch.removeAll()
        
        objectWillChange.send()
    }
}

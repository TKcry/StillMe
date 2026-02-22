import SwiftUI
import Combine
import FirebaseFirestore
import FirebaseAuth

class PairStatusViewModel: ObservableObject {
    let pairId: String
    let myUid: String
    private var memberUids: [String] = []
    
    @Published var streak: Int = 0
    @Published var lastSync: String = "–"
    @Published var myCapturedToday: Bool = false
    @Published var partnerCapturedToday: Bool = false
    @Published var partnerName: String = "Partner"
    @Published var partnerHandle: String = ""
    @Published var partnerAvatarPath: String? = nil
    @Published var partnerAvatarUpdatedAt: Date? = nil
    @Published var isWeeklyUnlocked: Bool = false
    @Published var requiredDays: Int = 7
    @Published var weeklyProgress: WeekProgress? = nil
    
    
    // Keep raw data to allow recalculation
    @Published var lastDailyMap: [String: TodayStatusModel] = [:]
    
    // Raw data for detail view (photo display, etc.)
    @Published var currentTodayStatus: TodayStatusModel? = nil
    
    private var dailyListener: ListenerRegistration?
    private var partnerListener: ListenerRegistration?
    private var weeklyListener: ListenerRegistration?
    private let db = Firestore.firestore()
    private var cancellables = Set<AnyCancellable>()
    
    init(pairId: String, myUid: String) {
        self.pairId = pairId
        self.myUid = myUid
        
        print("[PairDetail] open pairId=\(pairId)")
        
        // Phase 290: Load history cache immediately for faster display
        loadDailyMapCache()
        
        startListening()
        setupStoreObservation()
    }
    
    deinit {
        dailyListener?.remove()
        partnerListener?.remove()
        weeklyListener?.remove()
        cancellables.removeAll()
    }
    
    var partnerUid: String {
        if !memberUids.isEmpty {
            return memberUids.first(where: { $0 != myUid }) ?? ""
        }
        let parts = pairId.components(separatedBy: "_")
        let found = parts.first(where: { $0 != myUid }) ?? ""
        return found
    }
    
    func startListening() {
        dailyListener?.remove()
        partnerListener?.remove()
        weeklyListener?.remove()
        
        // 1. Initial status from Store if available
        if let existing = PairStore.shared.statusByPair[pairId] {
            self.currentTodayStatus = existing
            let myS = existing.statusByUid[myUid]
            let pS = existing.statusByUid[partnerUid]
            self.myCapturedToday = (myS?.windowDidCapture ?? false) || (myS?.targetedWindowDidCapture ?? false)
            self.partnerCapturedToday = (pS?.windowDidCapture ?? false) || (pS?.targetedWindowDidCapture ?? false)
        }
        
        let todayKey = Date().yyyyMMdd
        let path = "pairs/\(pairId)/daily/\(todayKey)"
        print("[PairDetail] open pairId=\(pairId)")
        print("[PairStatus] todayKey=\(todayKey)")
        print("[PairStatus] listen path=\(path)")
        
        // Fetch daily documents for the last 31 days to calculate streak and calendar
        dailyListener = db.collection("pairs/\(pairId)/daily")
            .order(by: "__name__", descending: true)
            .limit(to: 31)
            .addSnapshotListener { [weak self] snap, err in
                guard let self = self else { return }
                
                if let err = err {
                    print("[ERROR][PairStatus] Listener error: \(err.localizedDescription)")
                    return
                }
                
                guard let docs = snap?.documents else {
                    print("[DEBUG][PairStatus] No documents found in \(path)")
                    return
                }
                
                print("[DEBUG][PairStatus] Received \(docs.count) docs for \(pairId)")
                self.processDailyData(docs)
            }
        
        // Observe partner's name and avatar
        fetchPairInfo()
        
        // Ensure store is also syncing this pair for summary and weekly progress
        PairStore.shared.startPairSync(pairId: pairId)
    }
    
    private func setupStoreObservation() {
        // Observe clearing flag for immediate UI reset
        PairStore.shared.$isClearingWindowPhoto
            .receive(on: DispatchQueue.main)
            .sink { [weak self] (isClearing: Bool) in
                if isClearing {
                    print("[DEBUG][PairStatus] Global CLEARING detected. Resetting UI flags.")
                    self?.myCapturedToday = false
                    if let map = self?.lastDailyMap {
                        self?.processDailyData(from: map)
                    }
                }
            }
            .store(in: &cancellables)
            
        PairStore.shared.$statusByPair
            .sink { [weak self] (statusMap: [String: TodayStatusModel]) in
                guard let self = self else { return }
                
                if let status = statusMap[self.pairId] {
                    print("[DEBUG][PairStatus] Scoped Store Update received for \(self.pairId)")
                    // Update today flags immediately from centralized store
                    self.currentTodayStatus = status
                    let myS = status.statusByUid[self.myUid]
                    let pS = status.statusByUid[self.partnerUid]
                    self.myCapturedToday = (myS?.windowDidCapture ?? false) || (myS?.targetedWindowDidCapture ?? false)
                    self.partnerCapturedToday = (pS?.windowDidCapture ?? false) || (pS?.targetedWindowDidCapture ?? false)
                    
                    // Phase 291: Mount today's status into the history map for immediate lamp reflection
                    let todayKey = Date().yyyyMMdd
                    if self.lastDailyMap[todayKey] != status {
                        self.lastDailyMap[todayKey] = status
                        self.updateCalendarDates()
                    }
                    
                    self.repairInconsistencyIfNeeded()
                } else {
                    // Reset if data is missing (e.g. after sign-out/resetAllData)
                    self.currentTodayStatus = nil
                    self.myCapturedToday = false
                    self.partnerCapturedToday = false
                }
            }
            .store(in: &cancellables)
            
        // Phase 270: Unified weekly sync
        PairStore.shared.$weeklyProgressByPair
            .sink { [weak self] progressMap in
                guard let self = self else { return }
                if let progress = progressMap[self.pairId] {
                    self.weeklyProgress = progress
                    self.isWeeklyUnlocked = progress.unlocked
                    self.requiredDays = progress.requiredDays
                    self.updateCalendarDates() // Refresh mini-calendar dots
                    self.repairInconsistencyIfNeeded()
                }
            }
            .store(in: &cancellables)
    }
    
    private func repairInconsistencyIfNeeded() {
        guard let status = currentTodayStatus, let progress = weeklyProgress else { return }
        
        // Phase 270: Bidirectional Repair Logic
        // RESCUE: If photo exists but lamp is OFF -> Turn lamp ON (Apply immediately)
        // CLEANUP: If photo missing but lamp is ON -> Turn lamp OFF (Apply after grace period)
        
        let now = Date()
        let dayIndex = now.isoWeekdayIndex
        let cleanupGracePeriod: TimeInterval = 120
        let timeSinceUpdate = now.timeIntervalSince(progress.updatedAt)
        
        // 1. Repair ME
        let myStatus = status.statusByUid[myUid]
        let myCaptured = (myStatus?.windowDidCapture ?? false) || (myStatus?.windowPhotoUrl != nil) || (myStatus?.targetedWindowDidCapture ?? false) || (myStatus?.targetedWindowPhotoUrl != nil)
        
        let myDoneArray = progress.dailyDoneByUid[myUid] ?? []
        let myLampOn = (dayIndex < myDoneArray.count) ? myDoneArray[dayIndex] : false
        
        if myCaptured && !myLampOn {
            print("[REPAIR] RESCUE: My photo exists but lamp is OFF. Lighting up for \(myUid)...")
            Task { try? await PairStore.shared.updateWeeklyProgress(pairId: pairId, date: now, status: true, uid: myUid) }
        } else if !myCaptured && myLampOn && timeSinceUpdate >= cleanupGracePeriod {
            print("[REPAIR] CLEANUP: My photo missing but lamp is ON. Turning off ghost lamp for \(myUid)...")
            Task { try? await PairStore.shared.updateWeeklyProgress(pairId: pairId, date: now, status: false, uid: myUid) }
        }
        
        // 2. Repair PARTNER
        let partnerStatus = status.statusByUid[partnerUid]
        let partnerCaptured = (partnerStatus?.windowDidCapture ?? false) || (partnerStatus?.windowPhotoUrl != nil) || (partnerStatus?.targetedWindowDidCapture ?? false) || (partnerStatus?.targetedWindowPhotoUrl != nil)
        
        let partnerDoneArray = progress.dailyDoneByUid[partnerUid] ?? []
        let partnerLampOn = (dayIndex < partnerDoneArray.count) ? partnerDoneArray[dayIndex] : false
        
        if partnerCaptured && !partnerLampOn {
            print("[REPAIR] RESCUE: Partner photo exists but lamp is OFF. Lighting up for \(partnerUid)...")
            Task { try? await PairStore.shared.updateWeeklyProgress(pairId: pairId, date: now, status: true, uid: partnerUid) }
        } else if !partnerCaptured && partnerLampOn && timeSinceUpdate >= cleanupGracePeriod {
            print("[REPAIR] CLEANUP: Partner photo missing but lamp is ON. Turning off ghost lamp for \(partnerUid)...")
            Task { try? await PairStore.shared.updateWeeklyProgress(pairId: pairId, date: now, status: false, uid: partnerUid) }
        }
    }
    

    private func saveDailyMapCache() {
        do {
            let data = try JSONEncoder().encode(lastDailyMap)
            UserDefaults.standard.set(data, forKey: "DailyMap_CACHE_\(pairId)")
        } catch {
            print("[ERROR][Cache] Failed to save DailyMap for \(pairId): \(error)")
        }
    }
    
    private func loadDailyMapCache() {
        guard let data = UserDefaults.standard.data(forKey: "DailyMap_CACHE_\(pairId)") else { return }
        do {
            let models = try JSONDecoder().decode([String: TodayStatusModel].self, from: data)
            self.lastDailyMap = models
            print("[DEBUG][Cache] Loaded \(models.count) days history from local cache for \(pairId).")
            
            // Trigger UI processing based on cached data
            processDailyData(from: models)
        } catch {
            print("[ERROR][Cache] Failed to load DailyMap for \(pairId): \(error)")
        }
    }

    private func processDailyData(_ docs: [QueryDocumentSnapshot]) {
        let dailyMap = docs.reduce(into: [String: TodayStatusModel]()) { dict, doc in
            let data = doc.data()
            if !data.isEmpty {
                dict[doc.documentID] = TodayStatusModel.from(data: data)
            }
        }
        processDailyData(from: dailyMap)
        
        // Compute last sync time from documents
        var foundLastSync: Date? = nil
        for doc in docs {
            if let ts = (doc.data()["updatedAt"] as? Timestamp)?.dateValue() {
                if foundLastSync == nil || ts > foundLastSync! {
                    foundLastSync = ts
                }
            }
        }
        if let syncDate = foundLastSync {
            DispatchQueue.main.async {
                self.lastSync = self.formatRelativeTime(syncDate)
            }
        }
    }

    private func processDailyData(from dailyMap: [String: TodayStatusModel]) {
        let todayKey = Date().yyyyMMdd
        print("[PairStatus] Processing streak/calendar - TodayKey: \(todayKey)")

        // Phase 270/292: Redundancy update for Today status
        if let status = dailyMap[todayKey] {
            // Priority Check: Only update from listener if Store status is completely missing
            // OR if the listener doc definitely has more capture data than what we have.
            let hasDirectCaptures = (self.currentTodayStatus?.statusByUid.values.contains { $0.windowDidCapture || $0.targetedWindowDidCapture } ?? false)
            let hasListenerCaptures = status.statusByUid.values.contains { $0.windowDidCapture || $0.targetedWindowDidCapture }
            
            if self.currentTodayStatus == nil || (!hasDirectCaptures && hasListenerCaptures) {
                print("[DEBUG][PairStatus] Adopting today's status from collection listener (Store was empty or less complete)")
                self.currentTodayStatus = status
                self.myCapturedToday = status.statusByUid[myUid]?.windowDidCapture ?? status.statusByUid[myUid]?.targetedWindowDidCapture ?? false
                self.partnerCapturedToday = status.statusByUid[partnerUid]?.windowDidCapture ?? status.statusByUid[partnerUid]?.targetedWindowDidCapture ?? false
            }
        }

        let pUid = partnerUid
        var newStreak = 0

        // 1. Calculate streak
        let calendar = Calendar(identifier: .gregorian)
        var checkDate = Date()

        for _ in 0..<31 {
            let key = checkDate.yyyyMMdd
            let altKey = key.replacingOccurrences(of: "-", with: "")
            if let status = dailyMap[key] ?? dailyMap[altKey] {
                // Rescue Logic for streak: Any capture by any user counts for continuity if doc exists
                let myCaptured = (status.statusByUid[myUid]?.windowDidCapture ?? false) || (status.statusByUid[myUid]?.targetedWindowDidCapture ?? false)
                let partnerCaptured = (status.statusByUid[pUid]?.windowDidCapture ?? false) || (status.statusByUid[pUid]?.targetedWindowDidCapture ?? false)
                
                let s1 = myCaptured
                let s2 = partnerCaptured

                if s1 && s2 {
                    newStreak += 1
                } else if key == todayKey {
                    // Ongoing
                } else if status.statusByUid.values.contains(where: { $0.windowDidCapture || $0.targetedWindowDidCapture }) {
                    // Rescue: If at least one of them captured in a past day, it might be a partial day or sync issue
                    // For now, only BOTH count for a "perfect" streak, but we could be more lenient.
                    // Keep existing "BOTH required" rule for streak to be strict.
                    break 
                } else {
                    break
                }
            } else if key == todayKey {
                // None
            } else {
                break
            }
            checkDate = calendar.date(byAdding: .day, value: -1, to: checkDate) ?? checkDate
        }

        // Batch update on the UI thread
        DispatchQueue.main.async {
            // Phase 292: MERGE logic instead of replace to prevent overwriting real-time Today status
            var newMap = self.lastDailyMap
            for (date, status) in dailyMap {
                // GUARD: Never let historical listener (31 docs) overwriteToday if we have a direct sync model
                if date == todayKey && self.currentTodayStatus != nil {
                    continue
                }
                newMap[date] = status
            }
            
            // Final safety: Ensure currentTodayStatus is mounted
            if let ts = self.currentTodayStatus {
                newMap[todayKey] = ts
            }
            
            self.lastDailyMap = newMap
            self.saveDailyMapCache() // Phase 290: Update cache
            self.streak = newStreak

            self.updateCalendarDates()
        }
    }

    // Mini Calendar (Fixed to Current Week Mon-Sun)
    struct DayStatus: Identifiable {
        let id: String // yyyy-MM-dd
        let date: Date
        let publicDone: Bool     // Phase 289: Individual status
        let targetedDone: Bool   // Phase 289: Individual status
        let bothDone: Bool       // Consolidated status (legacy/fallback)
        let isToday: Bool
    }

    @Published var calendarWeeks: [[DayStatus]] = []
    @Published var calendarDays: [DayStatus] = [] // Keep for compatibility

    func publicCount(for weekIdx: Int) -> Int {
        guard weekIdx < calendarWeeks.count else { return 0 }
        return calendarWeeks[weekIdx].filter { $0.publicDone }.count
    }

    func targetedCount(for weekIdx: Int) -> Int {
        guard weekIdx < calendarWeeks.count else { return 0 }
        return calendarWeeks[weekIdx].filter { $0.targetedDone }.count
    }

    func updateCalendarDates() {
        let today = Date()
        let todayStr = today.yyyyMMdd
        let pUid = partnerUid

        var cal = Calendar.current
        cal.firstWeekday = 2 // Monday

        // Phase 289/293: Generate only the current week (Removing last week history)
        var allWeeks: [[DayStatus]] = []

        for weekOffset in 0..<1 {
            var weekDates: [Date] = []
            let targetDate = cal.date(byAdding: .day, value: -7 * weekOffset, to: today) ?? today
            let components = cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: targetDate)

            if let startOfWeek = cal.date(from: components) {
                for i in 0..<7 {
                    if let d = cal.date(byAdding: .day, value: i, to: startOfWeek) {
                        weekDates.append(d)
                    }
                }
            }

            let weekStatus = weekDates.enumerated().map { (i, date) -> DayStatus in
                let key = date.yyyyMMdd
                let isToday = (key == todayStr)

                var publicDone = false
                var targetedDone = false

                // Phase 292.2: Ultra-Robust Lamp Logic (Rescue & Multiformat)
                let altKey = key.replacingOccurrences(of: "-", with: "")
                let status = self.lastDailyMap[key] ?? self.lastDailyMap[altKey]
                
                let mUid = self.myUid
                let paUid = self.partnerUid
                
                // A) Direct UID lookup (authoritative)
                let myS = status?.statusByUid[mUid]
                let pS = status?.statusByUid[paUid]
                
                publicDone = (pS?.windowDidCapture ?? false) || (pS?.windowPhotoUrl != nil)
                targetedDone = (pS?.targetedWindowDidCapture ?? false) || (pS?.targetedWindowPhotoUrl != nil)
                
                // B) Rescue Fallback: If UID lookup yields nothing, but doc exists, look for PARTNER capture field
                if !publicDone && !targetedDone, let s = status, let partnerS = s.statusByUid[paUid] {
                    let hasPub = partnerS.windowDidCapture || (partnerS.windowPhotoUrl?.isEmpty == false)
                    let hasTar = partnerS.targetedWindowDidCapture || (partnerS.targetedWindowPhotoUrl?.isEmpty == false)
                    if hasPub { publicDone = true }
                    if hasTar { targetedDone = true }
                }
                
                // C) Summary-based fallback (Reliability check for current week)
                if weekOffset == 0, let progress = self.weeklyProgress {
                    let partnerDone = progress.dailyDoneByUid[paUid]?[i] ?? false
                    if partnerDone {
                        // If summary says done but doc is missing/empty, project it onto lamps
                        if !publicDone && !targetedDone {
                            publicDone = true
                            targetedDone = true
                        }
                    }
                }

                return DayStatus(
                    id: key,
                    date: date,
                    publicDone: publicDone,
                    targetedDone: targetedDone,
                    bothDone: publicDone || targetedDone,
                    isToday: isToday
                )
            }
            allWeeks.insert(weekStatus, at: 0) // Reverse so last week is index 0, this week is index 1?
            // Actually, user wants to "slide to see last week", so typically [Last Week, This Week].
            // If we use index 1 as current, it works well.
        }

        DispatchQueue.main.async {
            self.calendarWeeks = allWeeks
            self.calendarDays = allWeeks.last ?? [] // Keep compatibility
        }
    }

    private func fetchPairInfo() {
        let pUid = partnerUid
        guard !pUid.isEmpty else { return }

        // 1. Partner User Doc
        partnerListener = db.collection("users").document(pUid).addSnapshotListener { [weak self] snap, err in
            guard let data = snap?.data() else { return }

            DispatchQueue.main.async {
                self?.partnerName = data["nickname"] as? String ?? self?.partnerName ?? "Partner"
                self?.partnerHandle = data["handle"] as? String ?? ""
                self?.partnerAvatarPath = data["avatarPath"] as? String
                self?.partnerAvatarUpdatedAt = (data["avatarUpdatedAt"] as? Timestamp)?.dateValue()
            }
        }
        
        db.collection("pairs").document(pairId).addSnapshotListener { [weak self] snap, err in
            guard let self = self, let data = snap?.data() else { return }
            
            // 🔥 Task C: Predict requiredDays based on JST pairedLocalDate
            let pLocalDate = data["pairedLocalDate"] as? String
            let pWeekKey = data["pairedWeekKey"] as? String
            let currentWeekKey = Date().startOfWeekKey
            
            print("[DEBUG][Phase94] PairDoc: pairedLocalDate=\(pLocalDate ?? "nil"), pairedWeekKey=\(pWeekKey ?? "nil"), currentWeekKey=\(currentWeekKey)")

            // 🔥 Task A: Backfill Pair Metadata if missing
            if pLocalDate == nil || pWeekKey == nil {
                let pairedAtTs = data["pairedAt"] as? Timestamp
                let baseDate = pairedAtTs?.dateValue() ?? Date()
                let backfilledLocal = baseDate.yyyyMMdd
                let backfilledWeek = baseDate.startOfWeekKey
                
                print("[DEBUG][Phase95] Backfilling Metadata for pair \(self.pairId): \(backfilledLocal) / \(backfilledWeek)")
                
                self.db.collection("pairs").document(self.pairId).updateData([
                    "pairedLocalDate": backfilledLocal,
                    "pairedWeekKey": backfilledWeek
                ])
                
                // Initialize the week doc immediately with correct requiredDays 
                // Phase 270: Use forceDone: false to prevent marking today as "done" when just backfilling metadata
                Task {
                    try? await PairStore.shared.updateWeeklyProgress(pairId: self.pairId, date: baseDate, status: nil as Bool?)
                }
            }
            
            if pWeekKey == currentWeekKey, let pLocal = pLocalDate {
                if let index = Date.isoWeekdayIndex(from: pLocal) {
                    let req = 7 - index
                    print("[DEBUG][Phase94] Predicted Initial requiredDays: \(req) (dayIndex: \(index))")
                    DispatchQueue.main.async {
                        if self.weeklyProgress == nil {
                            self.requiredDays = req
                        }
                    }
                }
            }

            if let members = data["memberUids"] as? [String] {
                DispatchQueue.main.async {
                    self.memberUids = members
                }
                // 🔥 Fallback for legacy pairs: ensure today's shared doc exists
                Task {
                    await PairStore.shared.ensureTodayPairDocument(pairId: self.pairId, uids: members)
                }
            }
        }
        
    }
    
    private func formatRelativeTime(_ date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) { return NSLocalizedString("time_today", comment: "") }
        if calendar.isDateInYesterday(date) { return NSLocalizedString("time_yesterday", comment: "") }
        let diff = calendar.dateComponents([.day], from: date, to: Date()).day ?? 0
        if diff < 7 { 
            return String(format: NSLocalizedString("time_days_ago_format", comment: ""), diff)
        }
        return date.formatted(.dateTime.month().day())
    }
}

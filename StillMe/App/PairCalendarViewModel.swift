import SwiftUI
import Combine
import FirebaseFirestore
import FirebaseAuth

class PairCalendarViewModel: ObservableObject {
    @Published var records: [String: DayRecord] = [:]
    @Published var isLoading: Bool = false
    @Published var startMonth: Date? = nil // Phase 298
    
    private let pairId: String
    private let myUid: String
    private var db = Firestore.firestore()
    private var listener: ListenerRegistration?
    
    init(pairId: String) {
        self.pairId = pairId
        self.myUid = Auth.auth().currentUser?.uid ?? ""
        
        // Phase 298: Identify start month for calendar limiting
        if let pair = PairStore.shared.pairRefs.first(where: { $0.id == pairId }) {
            self.startMonth = pair.createdAt
        }
        
        // Phase 290: Load cache first
        loadRecordsCache()
        
        startListening()
    }
    
    private func saveRecordsCache() {
        do {
            let data = try JSONEncoder().encode(records)
            UserDefaults.standard.set(data, forKey: "CalendarRecords_CACHE_\(pairId)")
        } catch {
            print("[ERROR][Cache] Failed to save calendar records for \(pairId): \(error)")
        }
    }
    
    private func loadRecordsCache() {
        guard let data = UserDefaults.standard.data(forKey: "CalendarRecords_CACHE_\(pairId)") else { return }
        do {
            let cached = try JSONDecoder().decode([String: DayRecord].self, from: data)
            self.records = cached
            self.allRecordEntries = Array(cached.values).sorted { $0.id > $1.id }
            print("[DEBUG][Cache] Loaded \(cached.count) days from calendar cache for \(pairId).")
        } catch {
            print("[ERROR][Cache] Failed to load calendar records for \(pairId): \(error)")
        }
    }
    
    deinit {
        listener?.remove()
    }
    
    func startListening() {
        isLoading = true
        listener?.remove()
        
        listener = db.collection("pairs").document(pairId).collection("daily")
            .addSnapshotListener { [weak self] snap, err in
                guard let self = self else { return }
                self.isLoading = false
                
                if let err = err {
                    print("[PairCalendarVM] Error fetching daily: \(err)")
                    return
                }
                
                guard let docs = snap?.documents else { return }
                
                var newGridRecords: [String: DayRecord] = [:]
                var allCaptures: [DayRecord] = []
                let partnerUid = self.pairId.components(separatedBy: "_").first(where: { $0 != self.myUid }) ?? ""
                
                for doc in docs {
                    let dateId = doc.documentID
                    let data = doc.data()
                    let status = TodayStatusModel.from(data: data)
                    
                    let myS = status.statusByUid[self.myUid]
                    let pS = status.statusByUid[partnerUid]
                    
                    let hasMyPublic = myS?.windowDidCapture ?? false || myS?.windowPhotoUrl != nil
                    let hasMyTargeted = myS?.targetedWindowDidCapture ?? false || myS?.targetedWindowPhotoUrl != nil
                    let hasPartnerPublic = pS?.windowDidCapture ?? false || pS?.windowPhotoUrl != nil
                    let hasPartnerTargeted = pS?.targetedWindowDidCapture ?? false || pS?.targetedWindowPhotoUrl != nil
                    
                    if !hasPartnerPublic && !hasPartnerTargeted {
                        continue
                    }
                    
                    // Phase 292/294: Create a consolidated DayRecord representing the day's overall status (Me OR Partner)
                    var consolidatedRecord = DayRecord(id: dateId)
                    
                    // 1. Fill Targeted Info (Blue Lamp)
                    if hasPartnerTargeted {
                        let s = pS
                        consolidatedRecord.targetedWindowImagePath = s?.targetedWindowFullPath ?? s?.targetedWindowThumbPath
                        consolidatedRecord.targetedWindowThumbPath = s?.targetedWindowThumbPath
                        consolidatedRecord.targetedWindowFullPath = s?.targetedWindowFullPath
                        consolidatedRecord.targetedWindowPhotoUrl = s?.targetedWindowPhotoUrl
                        consolidatedRecord.targetedWindowCapturedAt = s?.targetedWindowCapturedAt
                        consolidatedRecord.targetedMemo = s?.targetedMemo
                        consolidatedRecord.targetedMomentPath = s?.targetedMomentPath
                    }
                    
                    // 2. Fill Public Info (Green Lamp)
                    if hasPartnerPublic {
                        let s = pS
                        consolidatedRecord.windowImagePath = s?.windowFullPath ?? s?.windowThumbPath
                        consolidatedRecord.windowThumbPath = s?.windowThumbPath
                        consolidatedRecord.windowFullPath = s?.windowFullPath
                        consolidatedRecord.windowPhotoUrl = s?.windowPhotoUrl
                        consolidatedRecord.windowCapturedAt = s?.windowCapturedAt
                        consolidatedRecord.memo = s?.memo
                        consolidatedRecord.momentPath = s?.momentPath
                    }
                    
                    newGridRecords[dateId] = consolidatedRecord
                    // Phase 294: Add consolidated record as a single entry for the viewer stack
                    allCaptures.append(consolidatedRecord)
                }
                
                DispatchQueue.main.async {
                    self.records = newGridRecords
                    self.allRecordEntries = allCaptures.sorted { $0.id > $1.id }
                    self.saveRecordsCache() // Phase 290: Update cache
                }
            }
    }
    
    @Published var allRecordEntries: [DayRecord] = []
    
    var sortedEntries: [DayRecord] {
        allRecordEntries
    }
    
    func entry(on date: Date) -> DayRecord? {
        let key = DateFormatter.yyyyMMdd.string(from: date)
        return records[key]
    }
}

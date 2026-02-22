import Foundation
import SwiftUI
import Combine
import FirebaseAuth
import FirebaseFirestore
import FirebaseStorage

final class RecordsStore: ObservableObject {
    @Published private(set) var records: [String: DayRecord] = [:]
    private let fileURL: URL

    init() {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first ?? URL(fileURLWithPath: NSTemporaryDirectory())
        let dir = base.appendingPathComponent("StillMeLog", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        self.fileURL = dir.appendingPathComponent("records.json")
        load()
        scanLocalDirectories() // Phase 188: Catch new entries from disk
    }

    private var recordsDirectory: URL {
        let fm = FileManager.default
        let appSupport = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return appSupport.appendingPathComponent("StillMe/records", isDirectory: true)
    }

    func scanLocalDirectories() {
        let fm = FileManager.default
        guard fm.fileExists(atPath: recordsDirectory.path) else { return }
        guard let items = try? fm.contentsOfDirectory(atPath: recordsDirectory.path) else { return }

        var count = 0
        for dateString in items {
            // dateString example: 2026-02-20
            let dayDir = recordsDirectory.appendingPathComponent(dateString)
            var isDir: ObjCBool = false
            guard fm.fileExists(atPath: dayDir.path, isDirectory: &isDir), isDir.boolValue else { continue }

            var record = records[dateString] ?? DayRecord(id: dateString)
            var mediaFound = false

            // Pattern 1: Legacy (records/date/window.jpg)
            let legacyWindow = dayDir.appendingPathComponent("window.jpg")
            if fm.fileExists(atPath: legacyWindow.path) {
                record.windowImagePath = "\(dateString)/window.jpg"
                mediaFound = true
            }

            // Pattern 2: Captures Hierarchy (records/date/{captureId}/...)
            if let subItems = try? fm.contentsOfDirectory(atPath: dayDir.path) {
                // Directories that look like capture IDs (contain underscores/timestamps)
                let captureIds = subItems.filter { item in
                    let subPath = dayDir.appendingPathComponent(item)
                    var subIsDir: ObjCBool = false
                    return fm.fileExists(atPath: subPath.path, isDirectory: &subIsDir) && subIsDir.boolValue && item.contains("_")
                }.sorted(by: <) // Process all captures to build the full state

                for cid in captureIds {
                    let cDir = dayDir.appendingPathComponent(cid)
                    let p720 = cDir.appendingPathComponent("photo_720.jpg")
                    let wLegacy = cDir.appendingPathComponent("window.jpg")
                    let m720 = cDir.appendingPathComponent("moment_720.mp4")
                    
                    var captureImagePath: String? = nil
                    if fm.fileExists(atPath: p720.path) {
                        captureImagePath = "\(dateString)/\(cid)/photo_720.jpg"
                    } else if fm.fileExists(atPath: wLegacy.path) {
                        captureImagePath = "\(dateString)/\(cid)/window.jpg"
                    }
                    
                    var captureMomentPath: String? = nil
                    if fm.fileExists(atPath: m720.path) {
                        captureMomentPath = "\(dateString)/\(cid)/moment_720.mp4"
                    }
                    
                    if captureImagePath != nil || captureMomentPath != nil {
                        mediaFound = true
                        
                        // Load meta.json to determine if this is targeted
                        let metaURL = cDir.appendingPathComponent("meta.json")
                        var targetedPairId: String? = nil
                        var memo: String? = nil
                        var rating: Int? = nil
                        
                        if let data = try? Data(contentsOf: metaURL),
                           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                            targetedPairId = json["targetedPairId"] as? String
                            memo = json["memo"] as? String
                            rating = json["rating"] as? Int
                        }
                        
                        if let pid = targetedPairId {
                            // Phase 283: Restore Targeted fields
                            print("[RecordsStore] 🔒 Found Restricted Photo for pair: \(pid) (date: \(dateString), id: \(cid))")
                            record.targetedWindowImagePath = captureImagePath
                            record.targetedMomentPath = captureMomentPath
                            record.targetedMemo = memo
                            
                            var s = record.targetedCaptures[pid] ?? TargetedStatus()
                            s.windowImagePath = captureImagePath
                            s.momentPath = captureMomentPath
                            s.memo = memo
                            record.targetedCaptures[pid] = s
                        } else {
                            // Phase 283: Restore Public fields
                            print("[RecordsStore] 🌐 Found Public Photo (date: \(dateString), id: \(cid))")
                            record.windowImagePath = captureImagePath
                            record.momentPath = captureMomentPath
                            if let m = memo { record.memo = m }
                            if let r = rating { record.rating = r }
                            record.selectedCaptureId = cid
                        }
                    }
                }
            }

            if mediaFound {
                records[dateString] = record
                count += 1
            }
        }
        if count > 0 {
            print("[RecordsStore] Scanned and found \(count) local record directories (including deep hierarchy).")
            save()
        }
    }

    func record(for date: Date) -> DayRecord? {
        records[date.yyyyMMdd]
    }

    func progress(for date: Date) -> DayProgress {
        record(for: date)?.progress() ?? DayProgress.notStarted
    }

    func upsertRecord(_ record: DayRecord) {
        records[record.id] = record
        save()
    }


    func upsertWindow(for date: Date, imagePath: String, capturedAt: Date = Date(), isShared: Bool = false, shouldMirror: Bool = false) {
        var record = records[date.yyyyMMdd] ?? DayRecord(id: date.yyyyMMdd)
        record.windowImagePath = imagePath
        record.windowCapturedAt = capturedAt
        record.isShared = isShared
        record.shouldMirrorForUI = shouldMirror
        records[record.id] = record
        save()
    }

    func upsertTargetedWindow(for date: Date, pairId: String?, imagePath: String, capturedAt: Date = Date(), fullPath: String? = nil) {
        var record = records[date.yyyyMMdd] ?? DayRecord(id: date.yyyyMMdd)
        if let pid = pairId {
            var s = record.targetedCaptures[pid] ?? TargetedStatus()
            s.windowImagePath = imagePath
            s.windowCapturedAt = capturedAt
            s.windowFullPath = fullPath
            record.targetedCaptures[pid] = s
        } else {
            record.targetedWindowImagePath = imagePath
            record.targetedWindowCapturedAt = capturedAt
            record.targetedWindowFullPath = fullPath
        }
        records[record.id] = record
        save()
    }
    
    func upsertMoment(for date: Date, path: String) {
        var record = records[date.yyyyMMdd] ?? DayRecord(id: date.yyyyMMdd)
        record.momentPath = path
        records[record.id] = record
        save()
    }

    func updateSelectedCaptureId(for date: Date, captureId: String) {
        var record = records[date.yyyyMMdd] ?? DayRecord(id: date.yyyyMMdd)
        record.selectedCaptureId = captureId
        records[record.id] = record
        save()
    }

    func updateWindowThumbPath(for date: Date, thumbPath: String) {
        var record = records[date.yyyyMMdd] ?? DayRecord(id: date.yyyyMMdd)
        record.windowThumbPath = thumbPath
        records[record.id] = record
        save()
    }

    func updateTargetedWindowThumbPath(for date: Date, pairId: String?, thumbPath: String) {
        var record = records[date.yyyyMMdd] ?? DayRecord(id: date.yyyyMMdd)
        if let pid = pairId {
            var s = record.targetedCaptures[pid] ?? TargetedStatus()
            s.windowThumbPath = thumbPath
            record.targetedCaptures[pid] = s
        } else {
            record.targetedWindowThumbPath = thumbPath
        }
        records[record.id] = record
        save()
    }

    func upsertTargetedMoment(for date: Date, pairId: String?, path: String) {
        var record = records[date.yyyyMMdd] ?? DayRecord(id: date.yyyyMMdd)
        if let pid = pairId {
            var s = record.targetedCaptures[pid] ?? TargetedStatus()
            s.momentPath = path
            record.targetedCaptures[pid] = s
        } else {
            record.targetedMomentPath = path
        }
        records[record.id] = record
        save()
    }

    func updateTargetedMemo(for date: Date, pairId: String?, memo: String) {
        var record = records[date.yyyyMMdd] ?? DayRecord(id: date.yyyyMMdd)
        if let pid = pairId {
            var s = record.targetedCaptures[pid] ?? TargetedStatus()
            s.memo = memo
            record.targetedCaptures[pid] = s
        } else {
            record.targetedMemo = memo
        }
        records[record.id] = record
        save()
    }


    func markAsShared(for date: Date) {
        if var record = records[date.yyyyMMdd] {
            record.isShared = true
            records[date.yyyyMMdd] = record
            save()
        }
    }


    func removeWindowPath(for date: Date) {
        if var record = records[date.yyyyMMdd] {
            record.windowImagePath = nil
            records[date.yyyyMMdd] = record
            save()
        }
    }

    func updateRating(for date: Date, rating: Int) {
        var record = records[date.yyyyMMdd] ?? DayRecord(id: date.yyyyMMdd)
        record.rating = rating
        records[record.id] = record
        save()
    }

    func updateMemo(for date: Date, memo: String) {
        var record = records[date.yyyyMMdd] ?? DayRecord(id: date.yyyyMMdd)
        record.memo = memo
        records[record.id] = record
        save()
    }

    func removeRecord(for date: Date) {
        records.removeValue(forKey: date.yyyyMMdd)
        save()
    }
    
    func removeDummyRecords() {
        records = records.filter { $0.value.hasWindow }
        save()
    }

    // MARK: - Debug Hard Reset
    func debugHardResetToday() {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        
        let today = Date()
        let key = today.yyyyMMdd
        let db = Firestore.firestore()
        let storage = Storage.storage()
        
        print("[DebugReset] START Hard Reset for \(key)")
        
        // 0. Update PairStore Tombstone (Immediate Guard)
        PairStore.shared.markAsTombstoned(key)
        
        // A. User Daily: Just update updatedAt (Sync trigger)
        let userDailyRef = db.collection("users").document(uid).collection("daily").document(key)
        userDailyRef.setData([
            "updatedAt": FieldValue.serverTimestamp()
        ], merge: true)
        
        for pair in PairStore.shared.pairRefs {
            let pairDailyRef = db.collection("pairs").document(pair.id).collection("daily").document(key)
            pairDailyRef.setData([
                "updatedAt": FieldValue.serverTimestamp()
            ], merge: true)
        }
        
        // 4. Local Cache & Files
        DispatchQueue.main.async {
            // A. Global Cache Buster (Nuclear option)
            ImageCacheService.shared.incrementCacheBuster()
            
            // B. Targeted Prefix Removal (surgical disposal)
            // Memory records removal
            self.records.removeValue(forKey: key)
            self.save()
            
            // Storage based cache removal for EVERYTHING today
            // Surgical: pairs/{pairId}/daily/{key}/*
            for pair in PairStore.shared.pairRefs {
                ImageCacheService.shared.removeImagePrefix(prefix: "pairs/\(pair.id)/daily/\(key)/")
            }
            // User side
            ImageCacheService.shared.removeImagePrefix(prefix: "users/\(uid)/daily/\(key)")
            
            let dayDir = self.recordsDirectory.appendingPathComponent(key)
            try? FileManager.default.removeItem(at: dayDir)
            
            self.objectWillChange.send()
            print("[DebugReset] ✅ Local cleanup & Strategic Cache clear OK")
        }
        
        // 5. Verify (Delayed)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            userDailyRef.getDocument { snap, _ in
                print("[DebugReset] 🔍 VERIFY UserDoc exists? \(snap?.exists ?? false) (Should be false)")
            }
        }
    }

    func recentRecords(limit: Int = 7) -> [DayRecord] {
        let sorted = records.values.sorted { $0.id > $1.id }
        return Array(sorted.prefix(limit))
    }

    func allDatesSorted() -> [String] {
        records.keys.sorted()
    }

    private func load() {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return }
        do {
            let data = try Data(contentsOf: fileURL)
            let decoded = try JSONDecoder().decode([String: DayRecord].self, from: data)
            self.records = decoded
        } catch {
            print("Failed to load records: \(error)")
        }
    }

    private func save() {
        do {
            let data = try JSONEncoder().encode(records)
            try data.write(to: fileURL, options: [.atomic])
        } catch {
            print("Failed to save records: \(error)")
        }
    }

    /// Clears memory status (Called after ImageStore wipes files)
    func clearAllData() {
        self.records = [:]
        print("[RecordsStore] 🗑️ Memory state cleared.")
    }
}

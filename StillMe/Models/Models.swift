import Foundation
import SwiftUI
import CoreGraphics
import CryptoKit
import AVFoundation
import CoreMedia
import FirebaseFirestore

struct TargetedStatus: Codable, Equatable {
    var windowImagePath: String? = nil
    var windowThumbPath: String? = nil
    var windowFullPath: String? = nil
    var windowPhotoUrl: String? = nil
    var windowCapturedAt: Date? = nil
    var momentPath: String? = nil
    var memo: String? = nil
    
    var hasWindow: Bool { windowImagePath != nil || windowPhotoUrl != nil || windowThumbPath != nil || windowFullPath != nil || momentPath != nil }
}

// DayRecord: Represents a single day's window capture and memo
struct DayRecord: Identifiable, Codable {
    let id: String // YYYY-MM-DD
    var windowImagePath: String? = nil // Full path (Legacy/Compatibility)
    var windowThumbPath: String? = nil // Thumbnail path
    var windowFullPath: String? = nil  // Explicit full path
    var windowPhotoUrl: String? = nil
    var windowCapturedAt: Date? = nil
    var memo: String? = nil
    var rating: Int = -1 // -1: Not rated, 0: 👎, 1: 😐, 2: 👍
    var isShared: Bool = false // New flag: Whether this record is synced to cloud
    var shouldMirrorForUI: Bool = false // Phase 207.2
    var isPrivate: Bool? = false // Phase 300 (Optional to handle existing data)

    var momentPath: String? = nil // Path to moment.mov
    var selectedCaptureId: String? = nil // Phase 205: Track which capture is "the one"

    // Multi-Target Support (Phase 260)
    var targetedCaptures: [String: TargetedStatus] = [:]

    // Targeted (Pair-Specific) Capture Fields (Legacy Compatibility)
    var targetedWindowImagePath: String? = nil
    var targetedWindowThumbPath: String? = nil
    var targetedWindowFullPath: String? = nil
    var targetedWindowPhotoUrl: String? = nil
    var targetedWindowCapturedAt: Date? = nil
    var targetedMomentPath: String? = nil
    var targetedMemo: String? = nil

    var hasWindow: Bool { windowImagePath != nil || windowPhotoUrl != nil || windowThumbPath != nil || windowFullPath != nil || momentPath != nil }
    
    var hasTargetedWindow: Bool { 
        targetedWindowImagePath != nil || targetedWindowPhotoUrl != nil || targetedWindowThumbPath != nil || targetedWindowFullPath != nil || targetedMomentPath != nil ||
        targetedCaptures.values.contains { $0.hasWindow }
    }
    
    var hasAnyWindow: Bool { hasWindow || hasTargetedWindow }
    
    func targetedStatus(for pairId: String?) -> TargetedStatus? {
        guard let pid = pairId else { return nil }
        if let status = targetedCaptures[pid] { return status }
        
        // Single-pair fallback for legacy data (if we don't know which pair it was, we assume the requested one if it's the only one, but safer to just check fields)
        // Note: In early implementation, only 1 pair was supported for targeted captures.
        if targetedWindowImagePath != nil || targetedWindowPhotoUrl != nil {
            return TargetedStatus(
                windowImagePath: targetedWindowImagePath,
                windowThumbPath: targetedWindowThumbPath,
                windowFullPath: targetedWindowFullPath,
                windowPhotoUrl: targetedWindowPhotoUrl,
                windowCapturedAt: targetedWindowCapturedAt,
                momentPath: targetedMomentPath,
                memo: targetedMemo
            )
        }
        return nil
    }

    func progress() -> DayProgress {
        (hasWindow || hasTargetedWindow) ? .captured : .notStarted
    }
}

enum DayProgress: String, Codable {
    case notStarted
    case captured

    var label: String {
        switch self {
        case .notStarted: return "Not captured"
        case .captured: return "Captured"
        }
    }

    var color: Color {
        switch self {
        case .notStarted: return .gray
        case .captured: return .blue
        }
    }
}

// User and Social Models
struct UserProfile: Codable {
    var name: String // This is the nickname
    var handle: String // Unique ID (@xxxx)
    var avatarPath: String?
    var avatarUpdatedAt: Date?
    var birthdate: Date?
    var handleUpdatedAt: Date?
    var isPrivate: Bool = false
    
    static var mock: UserProfile {
        UserProfile(name: "Alex Morgan", handle: "alexmorgan", birthdate: nil, handleUpdatedAt: nil, isPrivate: false)
    }
}

// Pair Entry (formerly FriendEntry)
struct PairEntry: Identifiable, Codable {
    let id: String
    let partnerUid: String
    let name: String
    let partnerHandle: String?
    let avatarUpdatedAt: Date?
    let lastStatus: String
    let lastActive: String
}

// Photo preview context (for reliable synchronization)
struct PhotoViewerContext: Identifiable {
    let id: String // Selected date ID (YYYY-MM-DD)
    let allEntries: [DayRecord]
}

// Global Helpers
extension DateFormatter {
    static let yyyyMMdd: DateFormatter = {
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd"
        df.locale = Locale(identifier: "en_US_POSIX")
        df.timeZone = TimeZone(secondsFromGMT: 9 * 3600) // JST
        return df
    }()
    
    // Phase 257.2: Specialized formatter for matching display to storage day
    static let displayDateJST: DateFormatter = {
        let df = DateFormatter()
        df.dateStyle = .long
        df.timeStyle = .none
        df.locale = Locale(identifier: "ja_JP")
        df.timeZone = TimeZone(secondsFromGMT: 9 * 3600) // JST
        return df
    }()
    
    static let displayTimeJST: DateFormatter = {
        let df = DateFormatter()
        df.dateFormat = "H:mm"
        df.timeZone = TimeZone(secondsFromGMT: 9 * 3600) // JST
        return df
    }()
    
    static let monthTitleJST: DateFormatter = {
        let df = DateFormatter()
        df.dateFormat = "yyyy年 MMMM"
        df.locale = Locale(identifier: "ja_JP")
        df.timeZone = TimeZone(secondsFromGMT: 9 * 3600) // JST
        return df
    }()
}

struct FileUtils {
    static func resolveMomentURL(for date: Date, captureId: String?) -> URL? {
        guard let cid = captureId else { return nil }
        let fm = FileManager.default
        let appSupport = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let dateString = date.yyyyMMdd
        
        let base = appSupport.appendingPathComponent("StillMe/records/\(dateString)/\(cid)")
        
        // Phase 257: Try new high-quality format first
        let newURL = base.appendingPathComponent("moment_720.mp4")
        if fm.fileExists(atPath: newURL.path) {
            return newURL
        }
        
        // Legacy: Fallback to old format only if it physically EXISTS
        let legacyURL = base.appendingPathComponent("moment.mov")
        if fm.fileExists(atPath: legacyURL.path) {
            return legacyURL
        }
        
        // Default: If neither exists, we expect/create the new format
        return newURL
    }

    static func metaURL(for date: Date, captureId: String) -> URL {
        let fm = FileManager.default
        let appSupport = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let dateString = date.yyyyMMdd
        // Path: records / {date} / {captureId} / moment_meta.json
        return appSupport.appendingPathComponent("StillMe/records/\(dateString)/\(captureId)/moment_meta.json")
    }

    static func captureDirectoryURL(for date: Date, captureId: String) -> URL {
        let fm = FileManager.default
        let appSupport = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let dateString = date.yyyyMMdd
        // Path: records / {date} / {captureId} /
        return appSupport.appendingPathComponent("StillMe/records/\(dateString)/\(captureId)", isDirectory: true)
    }

    static func tempMomentURL() -> URL {
        let tempDir = NSTemporaryDirectory()
        let filename = "moment_temp_\(UUID().uuidString.prefix(6)).mov"
        return URL(fileURLWithPath: tempDir).appendingPathComponent(filename)
    }

    /// Phase 205.2: Strict Unique ID Generation
    static func generateCaptureId(for date: Date) -> String {
        let ts = Int(date.timeIntervalSince1970 * 1000)
        let rand = String(format: "%04X", Int.random(in: 0...0xFFFF))
        let df = DateFormatter()
        df.dateFormat = "yyyyMMdd_HHmmss"
        df.timeZone = TimeZone(secondsFromGMT: 9 * 3600)
        let timeStr = df.string(from: date)
        return "\(timeStr)_\(ts % 1000)_\(rand)"
    }

    /// Phase 205.2: SHA256 Fingerprint for Identity Proof
    static func computeSHA256(for image: UIImage) -> String {
        guard let data = image.pngData() else { return "error_no_data" }
        let hash = SHA256.hash(data: data)
        return hash.compactMap { String(format: "%02x", $0) }.joined()
    }

    /// Phase 206.3: Unified SHA extraction from physical video file
    static func extractFrame0SHA(from url: URL) -> String? {
        let asset = AVURLAsset(url: url)
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        if let cgImage = try? generator.copyCGImage(at: .zero, actualTime: nil) {
            return computeSHA256(for: UIImage(cgImage: cgImage))
        }
        return nil
    }
}

extension Date {
    var yyyyMMdd: String {
        DateFormatter.yyyyMMdd.string(from: self)
    }

    var startOfDay: Date {
        Calendar.current.startOfDay(for: self)
    }
    
    var dayString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d"
        return formatter.string(from: self)
    }

    func startOfMonth(using calendar: Calendar = .current) -> Date {
        let comps = calendar.dateComponents([.year, .month], from: self)
        return calendar.date(from: comps) ?? self
    }
    
    /// Returns the Monday of the current week as "yyyyMMdd" for WeekKey
    var startOfWeekKey: String {
        var cal = Calendar(identifier: .gregorian)
        cal.firstWeekday = 2 // Monday
        cal.timeZone = TimeZone(secondsFromGMT: 9 * 3600)! // JST
        let comps = cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: self)
        guard let monday = cal.date(from: comps) else { return self.yyyyMMdd.replacingOccurrences(of: "-", with: "") }
        
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd" // Use hyphens as recommended
        return f.string(from: monday)
    }
    
    /// Returns 0 (Mon) to 6 (Sun) correctly for JST
    var isoWeekdayIndex: Int {
        var cal = Calendar(identifier: .gregorian)
        cal.firstWeekday = 2 // Monday
        cal.timeZone = TimeZone(secondsFromGMT: 9 * 3600)!
        // Use weekday component (1=Sun, 2=Mon, ..., 7=Sat)
        let weekday = cal.component(.weekday, from: self)
        // Map: Mon(2)->0, Tue(3)->1, ..., Sat(7)->5, Sun(1)->6
        return (weekday + 5) % 7
    }
    
    /// Static helper to get index from "YYYY-MM-DD" string
    static func isoWeekdayIndex(from dateString: String) -> Int? {
        guard let date = DateFormatter.yyyyMMdd.date(from: dateString) else { return nil }
        return date.isoWeekdayIndex
    }
}

// Pair Status Models
struct TodayStatusModel: Equatable, Codable {
    var statusByUid: [String: TodayUserStatus]

    struct TodayUserStatus: Equatable, Codable {
        var windowDidCapture: Bool = false
        var windowThumbPath: String?
        var windowFullPath: String?
        var windowPhotoUrl: String?
        var windowCapturedAt: Date?
        var memo: String?
        var rating: Int?
        var isPrivate: Bool? = false // Phase 300 (Optional to handle existing data)
        var isDeleted: Bool = false
        var shouldMirrorForUI: Bool = false // Phase 207.2
        var momentPath: String?

        // Targeted (Pair-Specific) Capture Fields
        var targetedWindowDidCapture: Bool = false
        var targetedWindowThumbPath: String?
        var targetedWindowFullPath: String?
        var targetedWindowPhotoUrl: String?
        var targetedWindowCapturedAt: Date?
        var targetedMomentPath: String?
        var targetedMemo: String?
    }
    
    var isDeleted: Bool = false

    static func from(data: [String: Any]) -> TodayStatusModel {
        var dict: [String: TodayUserStatus] = [:]
        
        // Helper: convert values safely to Bool
        func toBool(_ val: Any?) -> Bool {
            if let b = val as? Bool { return b }
            if let n = val as? NSNumber { return n.boolValue }
            if let i = val as? Int { return i != 0 }
            return false
        }
        
        func parseUserStatus(_ v: [String: Any]) -> TodayUserStatus {
            let thumb = v["windowThumbPath"] as? String
            let full = v["windowFullPath"] as? String
            let url = v["windowPhotoUrl"] as? String
            
            let tThumb = v["targetedWindowThumbPath"] as? String
            let tFull = v["targetedWindowFullPath"] as? String
            let tUrl = v["targetedWindowPhotoUrl"] as? String

            return TodayUserStatus(
                windowDidCapture: toBool(v["windowDidCapture"]),
                windowThumbPath: (thumb?.isEmpty == false) ? thumb : nil,
                windowFullPath: (full?.isEmpty == false) ? full : nil,
                windowPhotoUrl: (url?.isEmpty == false) ? url : nil,
                windowCapturedAt: (v["windowCapturedAt"] as? Timestamp)?.dateValue() ?? (v["windowCapturedAt"] as? Date),
                memo: v["memo"] as? String,
                rating: v["rating"] as? Int,
                isDeleted: toBool(v["isDeleted"]),
                shouldMirrorForUI: toBool(v["shouldMirrorForUI"]),
                momentPath: v["momentPath"] as? String,
                
                // Targeted fields
                targetedWindowDidCapture: toBool(v["targetedWindowDidCapture"]),
                targetedWindowThumbPath: (tThumb?.isEmpty == false) ? tThumb : nil,
                targetedWindowFullPath: (tFull?.isEmpty == false) ? tFull : nil,
                targetedWindowPhotoUrl: (tUrl?.isEmpty == false) ? tUrl : nil,
                targetedWindowCapturedAt: (v["targetedWindowCapturedAt"] as? Timestamp)?.dateValue() ?? (v["targetedWindowCapturedAt"] as? Date),
                targetedMomentPath: v["targetedMomentPath"] as? String,
                targetedMemo: v["targetedMemo"] as? String
            )
        }

        if let map = data["statusByUid"] as? [String: Any] {
            for (uid, val) in map {
                if let v = val as? [String: Any] {
                    dict[uid] = parseUserStatus(v)
                }
            }
        }
        
        // Phase 270 Recovery: handle keys like "statusByUid.UID" at top level
        for (key, val) in data {
            if key.hasPrefix("statusByUid."), let v = val as? [String: Any] {
                let uid = String(key.dropFirst("statusByUid.".count))
                // Only fill if not already present or to potentially merge
                if dict[uid] == nil {
                    dict[uid] = parseUserStatus(v)
                }
            }
        }
        
        return TodayStatusModel(
            statusByUid: dict,
            isDeleted: toBool(data["isDeleted"])
        )
    }
}

// MARK: - Weekly Unlock Models
struct WeekProgress: Codable, Identifiable {
    var id: String // weekKey (Monday date e.g. "20260202")
    var dailyDoneByUid: [String: [Bool]] // [uid: [Bool] x7]
    var doneCountByUid: [String: Int]    // [uid: Int]
    var requiredDays: Int = 7            // Default to 7, can be less for first week
    var unlocked: Bool = false
    var unlockedAt: Date? = nil
    var updatedAt: Date = Date()
    
    static func empty(id: String, uids: [String], required: Int = 7) -> WeekProgress {
        var daily: [String: [Bool]] = [:]
        var counts: [String: Int] = [:]
        for uid in uids {
            daily[uid] = Array(repeating: false, count: 7)
            counts[uid] = 0
        }
        return WeekProgress(id: id, dailyDoneByUid: daily, doneCountByUid: counts, requiredDays: required)
    }
}

// MARK: - AppCard / Layout Constants

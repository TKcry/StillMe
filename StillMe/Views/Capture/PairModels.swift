import Foundation
import SwiftUI

public enum PairConnectionStatus: String, Codable, Equatable {
    case none, invited, paired
}

public struct PairProfile: Codable, Equatable, Identifiable {
    public var myId: String                // UUID -> String
    public var partnerId: String?          // UUID? -> String?
    public var partnerName: String
    public var status: PairConnectionStatus
    public var inviteCode: String?
    public var createdAt: Date

    public var id: String { myId }         // UUID -> String

    public static func initial() -> PairProfile {
        PairProfile(
            myId: "unknown",               // uid not fixed at startup. authUid assigned later.
            partnerId: nil,
            partnerName: "",
            status: .none,
            inviteCode: nil,
            createdAt: Date()
        )
    }
}


public struct DailyStatus: Codable, Equatable, Identifiable {
    public var dateKey: String
    public var didCapture: Bool
    public var thumbRelativePath: String?

    public var id: String { dateKey }

    public static func empty(for dateKey: String) -> DailyStatus {
        DailyStatus(dateKey: dateKey, didCapture: false, thumbRelativePath: nil)
    }
}

public enum PairPaths {
    public static let baseDir: URL = {
        let urls = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)
        let appSupport = urls.first!
        let base = appSupport.appendingPathComponent("StillMe").appendingPathComponent("pair")
        return base
    }()

    public static var profileURL: URL { baseDir.appendingPathComponent("pair_profile.json") }
    public static var myDailyURL: URL { baseDir.appendingPathComponent("my_daily_status.json") }
    public static var partnerDailyURL: URL { baseDir.appendingPathComponent("partner_daily_status.json") }

    public static func ensureDirs() {
        let fm = FileManager.default
        if !fm.fileExists(atPath: baseDir.path) {
            try? fm.createDirectory(at: baseDir, withIntermediateDirectories: true)
        }
    }
}

public extension Date {
    func dateKey() -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar.current
        formatter.timeZone = TimeZone.current
        formatter.dateFormat = "yyyyMMdd"
        return formatter.string(from: self)
    }
}

public extension Image {
    static var pairPlaceholder: Image {
        Image(systemName: "person.crop.square")
    }
}

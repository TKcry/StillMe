import Foundation
import UIKit

final class PartnerCacheStore {
    static let shared = PartnerCacheStore()
    private let fm = FileManager.default
    
    private var cacheDirectory: URL {
        let caches = fm.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        let dir = caches.appendingPathComponent("StillMe/partner", isDirectory: true)
        if !fm.fileExists(atPath: dir.path) {
            try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }
    
    private init() {}
    
    /// Caches partner's image and returns local URL
    func saveCachedImage(data: Data, for date: Date, uid: String) throws -> URL {
        let dayDir = cacheDirectory.appendingPathComponent(date.yyyyMMdd, isDirectory: true)
        try fm.createDirectory(at: dayDir, withIntermediateDirectories: true)
        
        let fileURL = dayDir.appendingPathComponent("\(uid)_front.jpg")
        try data.write(to: fileURL, options: [.atomic])
        return fileURL
    }
    
    /// Loads image from cache
    func loadCachedImage(for date: Date, uid: String) -> UIImage? {
        let fileURL = cacheDirectory.appendingPathComponent(date.yyyyMMdd).appendingPathComponent("\(uid)_front.jpg")
        guard fm.fileExists(atPath: fileURL.path) else { return nil }
        return UIImage(contentsOfFile: fileURL.path)
    }
    
    /// Deletes cache for dates other than today
    func cleanupOldCache() {
        let today = Date().yyyyMMdd
        do {
            let items = try fm.contentsOfDirectory(at: cacheDirectory, includingPropertiesForKeys: nil)
            for item in items {
                if item.lastPathComponent != today {
                    try? fm.removeItem(at: item)
                    print("[DEBUG][PartnerCache] Cleaned up old cache: \(item.lastPathComponent)")
                }
            }
        } catch {
            print("[ERROR][PartnerCache] Cleanup failed: \(error)")
        }
    }
}

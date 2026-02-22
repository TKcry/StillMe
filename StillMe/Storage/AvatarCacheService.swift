import Foundation
import UIKit

final class AvatarCacheService {
    static let shared = AvatarCacheService()
    private let fm = FileManager.default
    
    private var cacheDirectory: URL {
        let caches = fm.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        let dir = caches.appendingPathComponent("StillMe/avatars", isDirectory: true)
        if !fm.fileExists(atPath: dir.path) {
            try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }
    
    private init() {}
    
    /// Generate avatar cache URL: {uid}_{timestamp}.jpg
    func cacheURL(for uid: String, updatedAt: Date?) -> URL {
        let timestamp = Int(updatedAt?.timeIntervalSince1970 ?? 0)
        return cacheDirectory.appendingPathComponent("\(uid)_\(timestamp).jpg")
    }
    
    /// Clear old cache and save new image
    func saveAvatar(data: Data, for uid: String, updatedAt: Date?) throws -> URL {
        // Clear old cache for the same user
        cleanupOldAvatars(for: uid)
        
        let fileURL = cacheURL(for: uid, updatedAt: updatedAt)
        try data.write(to: fileURL, options: [.atomic])
        return fileURL
    }
    
    /// Load image from cache
    func loadAvatar(for uid: String, updatedAt: Date?) -> UIImage? {
        let fileURL = cacheURL(for: uid, updatedAt: updatedAt)
        guard fm.fileExists(atPath: fileURL.path) else { return nil }
        return UIImage(contentsOfFile: fileURL.path)
    }
    
    /// Delete old cache files for a specific user
    private func cleanupOldAvatars(for uid: String) {
        do {
            let items = try fm.contentsOfDirectory(at: cacheDirectory, includingPropertiesForKeys: nil)
            for item in items {
                if item.lastPathComponent.hasPrefix("\(uid)_") {
                    try? fm.removeItem(at: item)
                }
            }
        } catch {
            print("[AvatarCache] Cleanup failed: \(error)")
        }
    }
}

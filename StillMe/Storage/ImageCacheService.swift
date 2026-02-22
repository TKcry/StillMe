import Foundation
import UIKit

final class ImageCacheService {
    static let shared = ImageCacheService()
    
    private let memoryCache = NSCache<NSString, UIImage>()
    private let fileManager = FileManager.default
    
    private var diskCacheURL: URL {
        let caches = fileManager.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        let dir = caches.appendingPathComponent("StillMe/images", isDirectory: true)
        if !fileManager.fileExists(atPath: dir.path) {
            try? fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }
    
    private init() {
        memoryCache.countLimit = 100 // Cache up to 100 images in memory
    }
    
    // MARK: - Cache Buster (Version Control)
    private var cacheBuster: Int {
        get { UserDefaults.standard.integer(forKey: "ImageCache_Buster_v1") }
        set { UserDefaults.standard.set(newValue, forKey: "ImageCache_Buster_v1") }
    }
    
    func incrementCacheBuster() {
        cacheBuster += 1
        memoryCache.removeAllObjects()
        print("[ImageCache] Cache Buster updated to \(cacheBuster). Old caches invalidated.")
    }
    
    func cacheKey(for path: String) -> String {
        let base = path.replacingOccurrences(of: "/", with: "_")
        return "\(base)_v\(cacheBuster)"
    }
    
    func getImage(for path: String) -> UIImage? {
        let key = cacheKey(for: path)
        
        // 1. Memory Cache
        if let cached = memoryCache.object(forKey: key as NSString) {
            return cached
        }
        
        // 2. Disk Cache
        let fileURL = diskCacheURL.appendingPathComponent(key)
        if fileManager.fileExists(atPath: fileURL.path),
           let data = try? Data(contentsOf: fileURL),
           let image = UIImage(data: data) {
            // Save back to memory for faster access next time
            memoryCache.setObject(image, forKey: key as NSString)
            return image
        }
        
        return nil
    }
    
    func saveImage(_ image: UIImage, for path: String) {
        let key = cacheKey(for: path)
        
        // 1. Memory Cache
        memoryCache.setObject(image, forKey: key as NSString)
        
        // 2. Disk Cache (Background)
        Task {
            let fileURL = diskCacheURL.appendingPathComponent(key)
            if let data = image.jpegData(compressionQuality: 0.8) {
                try? data.write(to: fileURL)
            }
        }
    }
    
    func clearCache() {
        memoryCache.removeAllObjects()
        try? fileManager.removeItem(at: diskCacheURL)
    }
    
    func removeImage(for path: String) {
        let key = cacheKey(for: path)
        memoryCache.removeObject(forKey: key as NSString)
        
        let fileURL = diskCacheURL.appendingPathComponent(key)
        if fileManager.fileExists(atPath: fileURL.path) {
            try? fileManager.removeItem(at: fileURL)
        }
    }
    
    func removeImagePrefix(prefix: String) {
        let keyPrefix = prefix.replacingOccurrences(of: "/", with: "_")
        print("[ImageCache] Removing prefix: \(keyPrefix)")
        
        // 1. Memory Cleanup (Requires manual iteration or flushing)
        // Since NSCache doesn't support prefix search, we flush all or accept best effort.
        // For reliability, we flush memory cache.
        memoryCache.removeAllObjects() 
        
        // 2. Disk Cleanup
        if let items = try? fileManager.contentsOfDirectory(at: diskCacheURL, includingPropertiesForKeys: nil) {
            for item in items {
                if item.lastPathComponent.hasPrefix(keyPrefix) {
                    try? fileManager.removeItem(at: item)
                    print("[ImageCache] Deleted: \(item.lastPathComponent)")
                }
            }
        }
    }
}

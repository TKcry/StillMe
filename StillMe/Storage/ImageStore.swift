import Foundation
import UIKit

struct ImageStore {

    private let fm = FileManager.default

    // Application Support / StillMe/records
    private var baseDirectory: URL {
        let appSupport = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let dir = appSupport.appendingPathComponent("StillMe/records", isDirectory: true)
        if !fm.fileExists(atPath: dir.path) {
            try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }

    /// Saves and returns "relative path" for Avatar/Front
    func saveFront(image: UIImage, for date: Date) async throws -> String {
        let dayDirName = date.yyyyMMdd
        let dayDir = baseDirectory.appendingPathComponent(dayDirName, isDirectory: true)
        try fm.createDirectory(at: dayDir, withIntermediateDirectories: true)
        let fileURL = dayDir.appendingPathComponent("front.jpg")

        let data = try await Task.detached(priority: .userInitiated) {
            guard let converted = image.jpegData(compressionQuality: 0.8) else {
                throw NSError(domain: "StillMe", code: 1, userInfo: [NSLocalizedDescriptionKey: "JPEG conversion failed"])
            }
            return converted
        }.value

        try data.write(to: fileURL, options: [.atomic])
        return "\(dayDirName)/front.jpg"
    }

    func saveWindow(image: UIImage, for date: Date, captureId: String) async throws -> String {
        return try await savePhoto720(image: image, for: date, captureId: captureId)
    }

    func savePhoto720(image: UIImage, for date: Date, captureId: String) async throws -> String {
        return try await saveImage(image: image, for: date, captureId: captureId, filename: "photo_720.jpg")
    }

    func saveThumb320(image: UIImage, for date: Date, captureId: String) async throws -> String {
        return try await saveImage(image: image, for: date, captureId: captureId, filename: "thumb_320.jpg")
    }

    func saveMoment(sourceURL: URL, for date: Date, captureId: String) async throws -> String {
        let dayDirName = date.yyyyMMdd
        let captureDir = FileUtils.captureDirectoryURL(for: date, captureId: captureId)
        let filename = "moment_720.mp4"
        let destinationURL = captureDir.appendingPathComponent(filename)
        
        print("[AppVM] moment save: captureId=\(captureId) dest=\(destinationURL.path)")

        // 1. Ensure directory exists
        if !fm.fileExists(atPath: captureDir.path) {
            try fm.createDirectory(at: captureDir, withIntermediateDirectories: true)
        }

        // 2. Source == Destination check
        if sourceURL == destinationURL {
            return "\(dayDirName)/\(captureId)/\(filename)"
        }
        
        // 3. Move or Replace atomically
        if fm.fileExists(atPath: destinationURL.path) {
            _ = try fm.replaceItemAt(destinationURL, withItemAt: sourceURL)
        } else {
            try fm.moveItem(at: sourceURL, to: destinationURL)
        }
        
        print("[AppVM] ✅ moment save SUCCESS: \(captureId)/\(filename)")
        // Store modified date for diagnostics
        if let attrs = try? fm.attributesOfItem(atPath: destinationURL.path), let mod = attrs[.modificationDate] as? Date {
            print("[Capture] momentSaved path=\(destinationURL.path) size=\(attrs[.size] ?? 0) modifiedAt=\(mod)")
        }
        return "\(dayDirName)/\(captureId)/\(filename)"
    }


    func saveMeta(json: [String: Any], for date: Date, captureId: String) {
        let captureDir = FileUtils.captureDirectoryURL(for: date, captureId: captureId)
        let fileURL = captureDir.appendingPathComponent("meta.json")
        
        do {
            if !fm.fileExists(atPath: captureDir.path) {
                try fm.createDirectory(at: captureDir, withIntermediateDirectories: true)
            }
            
            // Phase 284: Merge with existing meta if present to avoid overwriting attributes
            var finalDict: [String: Any] = json
            if fm.fileExists(atPath: fileURL.path),
               let existingData = try? Data(contentsOf: fileURL),
               let existingJson = try? JSONSerialization.jsonObject(with: existingData) as? [String: Any] {
                // Merge strategies:
                // New values overwrite old ones for the SAME key, but old disparate keys are kept.
                var merged = existingJson
                for (k, v) in json {
                    merged[k] = v
                }
                finalDict = merged
            }
            
            let data = try JSONSerialization.data(withJSONObject: finalDict, options: [.prettyPrinted])
            try data.write(to: fileURL, options: [.atomic])
        } catch {
            print("[ERROR][ImageStore] Failed to save meta.json: \(error)")
        }
    }

    func saveSelectedInfo(date: Date, captureId: String) {
        let dayDir = baseDirectory.appendingPathComponent(date.yyyyMMdd)
        let fileURL = dayDir.appendingPathComponent("selected.json")
        let json: [String: Any] = ["selectedCaptureId": captureId, "updatedAt": Date().timeIntervalSince1970]
        
        do {
            if !fm.fileExists(atPath: dayDir.path) {
                try fm.createDirectory(at: dayDir, withIntermediateDirectories: true)
            }
            let data = try JSONSerialization.data(withJSONObject: json, options: [.prettyPrinted])
            try data.write(to: fileURL, options: [.atomic])
            print("[Capture] selected.json updated with captureId=\(captureId)")
        } catch {
            print("[ERROR][ImageStore] Failed to save selected.json: \(error)")
        }
    }

    private func saveImage(image: UIImage, for date: Date, captureId: String, filename: String) async throws -> String {
        let dayDirName = date.yyyyMMdd
        let captureDir = FileUtils.captureDirectoryURL(for: date, captureId: captureId)
        try fm.createDirectory(at: captureDir, withIntermediateDirectories: true)

        let fileURL = captureDir.appendingPathComponent(filename)

        let data = try await Task.detached(priority: .userInitiated) {
            guard let converted = image.jpegData(compressionQuality: 0.8) else {
                throw NSError(
                    domain: "StillMe",
                    code: 1,
                    userInfo: [NSLocalizedDescriptionKey: "JPEG conversion failed"]
                )
            }
            return converted
        }.value

        try data.write(to: fileURL, options: [.atomic])
        print("[Capture] photoSaved path=\(fileURL.path)")
        return "\(dayDirName)/\(captureId)/\(filename)"
    }

    /// Loads from relative path
    func loadImage(at relativePath: String) -> UIImage? {
        let url = baseDirectory.appendingPathComponent(relativePath)
        return UIImage(contentsOfFile: url.path)
    }

    /// Deletes specific front image file
    func deleteFrontFile(for date: Date) {
        let fileURL = baseDirectory.appendingPathComponent(date.yyyyMMdd).appendingPathComponent("front.jpg")
        try? fm.removeItem(at: fileURL)
        cleanupDirectoryIfEmpty(for: date)
    }

    /// Deletes specific window image file
    func deleteWindowFile(for date: Date) {
        let dayDir = baseDirectory.appendingPathComponent(date.yyyyMMdd)
        try? fm.removeItem(at: dayDir.appendingPathComponent("window.jpg"))
        try? fm.removeItem(at: dayDir.appendingPathComponent("moment_720.mp4")) // Phase 257
        try? fm.removeItem(at: dayDir.appendingPathComponent("moment.mov"))
        try? fm.removeItem(at: dayDir.appendingPathComponent("meta.json"))
        // cleanupDirectoryIfEmpty(for: date) // DISABLE cleanup to protect Moment recording
    }

    /// Deletes physical file on disk (backward compatibility wrapper)
    func deleteFront(for date: Date) {
        deleteFrontFile(for: date)
    }

    private func cleanupDirectoryIfEmpty(for date: Date) {
        let dayDir = baseDirectory.appendingPathComponent(date.yyyyMMdd, isDirectory: true)
        if let items = try? fm.contentsOfDirectory(atPath: dayDir.path), items.isEmpty {
            try? fm.removeItem(at: dayDir)
            print("[DEBUG][ImageStore] Cleanup: Deleted empty directory: \(dayDir.path)")
        }
    }

    func forceCleanupDayDirectory(for date: Date) {
        let dayDir = baseDirectory.appendingPathComponent(date.yyyyMMdd, isDirectory: true)
        try? fm.removeItem(at: dayDir)
        print("[DEBUG][ImageStore] Force cleanup: Deleted day directory: \(dayDir.path)")
    }

    /// For debugging (safe to keep)
    func fileExists(relativePath: String) -> Bool {
        let url = baseDirectory.appendingPathComponent(relativePath)
        return fm.fileExists(atPath: url.path)
    }

    /// Restores a downloaded photo to the standard records structure
    func saveDownloadedData(_ data: Data, for date: Date, captureId: String, filename: String = "window.jpg") throws -> String {
        let dayDirName = date.yyyyMMdd
        let captureDir = FileUtils.captureDirectoryURL(for: date, captureId: captureId)
        
        if !fm.fileExists(atPath: captureDir.path) {
            try fm.createDirectory(at: captureDir, withIntermediateDirectories: true)
        }
        
        let fileURL = captureDir.appendingPathComponent(filename)
        try data.write(to: fileURL, options: [.atomic])
        
        print("[ImageStore] Restored downloaded file: \(fileURL.path)")
        return "\(dayDirName)/\(captureId)/\(filename)"
    }

    /// Wipes all local records and captured photos on sign out
    func clearAllData() {
        let appSupport = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let recordsDir = appSupport.appendingPathComponent("StillMe", isDirectory: true)
        let logDir = appSupport.appendingPathComponent("StillMeLog", isDirectory: true)
        
        try? fm.removeItem(at: recordsDir)
        try? fm.removeItem(at: logDir)
        
        print("[ImageStore] 🗑️ All local data wiped.")
    }
}

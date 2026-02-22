import Foundation
import UIKit
import FirebaseStorage

final class CloudStorageService {
    static let shared = CloudStorageService()
    private let storage: Storage
    
    private init() {
        // Use default Storage instance
        self.storage = Storage.storage()
    }
    
    /// Upload image to Firebase Storage and return the full destination path
    func uploadImage(image: UIImage, path: String) async throws -> String {
        let data = try await Task.detached(priority: .userInitiated) {
            guard let converted = image.jpegData(compressionQuality: 0.8) else {
                throw NSError(domain: "CloudStorageService", code: 0, userInfo: [NSLocalizedDescriptionKey: "Failed to convert image to JPEG"])
            }
            return converted
        }.value
        
        let storageRef = storage.reference().child(path)
        let metadata = StorageMetadata()
        metadata.contentType = "image/jpeg"
        
        let bucket = storageRef.bucket
        #if DEBUG
        print("[DEBUG][CloudStorage] Using bucket: \(bucket)")
        print("[DEBUG][CloudStorage] Full child path: \(path)")
        print("[DEBUG][CloudStorage] putData starting...")
        #endif
        return try await withCheckedThrowingContinuation { continuation in
            storageRef.putData(data, metadata: metadata) { metadata, error in
                if let error = error {
                    let nsError = error as NSError
                    #if DEBUG
                    print("[ERROR][CloudStorage] putData FAIL: \(nsError.localizedDescription) (Code: \(nsError.code))")
                    if nsError.code == StorageErrorCode.objectNotFound.rawValue {
                        print("[IMPORTANT][CloudStorage] 'Object NotFound' during UPLOAD usually means Storage is not enabled in Firebase Console.")
                    }
                    #endif
                    continuation.resume(throwing: error)
                    return
                }
                #if DEBUG
                print("[DEBUG][CloudStorage] putData SUCCESS for \(path)")
                #endif
                continuation.resume(returning: path)
            }
        }
    }
    
    /// Get download URL for a cloud path
    func getDownloadURL(for path: String) async throws -> URL {
        let storageRef = storage.reference().child(path)
        return try await storageRef.downloadURL()
    }
    
    /// Upload file at URL to Firebase Storage and return the full destination path
    func uploadFile(localURL: URL, path: String, contentType: String) async throws -> String {
        let storageRef = storage.reference().child(path)
        let metadata = StorageMetadata()
        metadata.contentType = contentType
        
        return try await withCheckedThrowingContinuation { continuation in
            storageRef.putFile(from: localURL, metadata: metadata) { metadata, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                continuation.resume(returning: path)
            }
        }
    }
    
    /// Delete file at specified path
    func deleteImage(path: String) async throws {
        let storageRef = storage.reference().child(path)
        try await storageRef.delete()
        #if DEBUG
        print("[DEBUG][CloudStorage] deleteImage SUCCESS for \(path)")
        #endif
    }
    
    /// Upload avatar image (Full + Thumb)
    func uploadAvatar(image: UIImage, uid: String) async throws -> (String, String) {
        let pathBase = "avatars/\(uid)"
        let fullPath = "\(pathBase)_full.jpg"
        let thumbPath = "\(pathBase)_thumb.jpg"
        
        // 1. Generate thumbnail (smaller for avatar list)
        let thumbImage = await resizedImage(image, targetSize: CGSize(width: 128, height: 128))
        
        // 2. Upload both
        async let fullUpload = uploadImage(image: image, path: fullPath)
        async let thumbUpload = uploadImage(image: thumbImage, path: thumbPath)
        
        return try await (fullUpload, thumbUpload)
    }

    /// Upload both thumbnail and full-size images
    /// returns (fullPath, thumbPath)
    func uploadImagePair(image: UIImage, pathBase: String) async throws -> (String, String) {
        let fullPath = "\(pathBase)_full.jpg"
        let thumbPath = "\(pathBase)_thumb.jpg"
        
        // 1. Generate thumbnail
        let thumbImage = await resizedImage(image, targetSize: CGSize(width: 512, height: 512))
        
        // 2. Upload both in parallel
        async let fullUpload = uploadImage(image: image, path: fullPath)
        async let thumbUpload = uploadImage(image: thumbImage, path: thumbPath)
        
        return try await (fullUpload, thumbUpload)
    }

    private func resizedImage(_ image: UIImage, targetSize: CGSize) async -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        
        let widthRatio  = targetSize.width  / image.size.width
        let heightRatio = targetSize.height / image.size.height
        let ratio = min(widthRatio, heightRatio)
        
        let newSize = CGSize(width: image.size.width * ratio, height: image.size.height * ratio)
        let rect = CGRect(origin: .zero, size: newSize)
        
        let renderer = UIGraphicsImageRenderer(size: newSize, format: format)
        return renderer.image { _ in
            image.draw(in: rect)
        }
    }
}

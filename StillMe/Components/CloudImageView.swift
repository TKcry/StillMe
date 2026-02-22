import SwiftUI

/// A simple helper view to load images from Cloud Storage paths with a placeholder
struct CloudImageView: View {
    let path: String
    var contentMode: ContentMode = .fill
    var showSpinner: Bool = false
    var version: String? = nil // Optional version (e.g. updatedAt string) to trigger re-cache
    
    @State private var image: UIImage? = nil
    @State private var isLoading = false
    
    init(path: String, contentMode: ContentMode = .fill, showSpinner: Bool = false, version: String? = nil) {
        self.path = path
        self.contentMode = contentMode
        self.showSpinner = showSpinner
        self.version = version
        
        // Phase 270: Synchronous cache check to avoid skeleton flicker
        let cKey = (version != nil) ? "\(path)?v=\(version!)" : path
        if let cached = ImageCacheService.shared.getImage(for: cKey) {
            _image = State(initialValue: cached)
        }
    }

    // Compute effective cache key
    private var cacheKey: String {
        if let v = version {
            return "\(path)?v=\(v)"
        }
        return path
    }
    
    var body: some View {
        ZStack {
            if let uiImage = image {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: contentMode)
                    .clipped()
            } else {
                SkeletonCard()
                    .task(id: cacheKey) {
                        await loadImage()
                    }
            }
            
            if showSpinner && isLoading {
                ProgressView()
                    .tint(.white)
                    .scaleEffect(1.0)
            }
        }
    }
    
    private func loadImage() async {
        let startTime = Date()
        let currentKey = cacheKey
        
        // 0. Tombstone Guard: Block if path contains a deleted date key
        // paths: "pairs/PAIRID/daily/YYYY-MM-DD/..." or "users/UID/daily/YYYY-MM-DD/..."
        let components = path.split(separator: "/")
        if let dailyIndex = components.firstIndex(of: "daily"), dailyIndex + 1 < components.count {
            let dateKey = String(components[dailyIndex + 1])
            if PairStore.shared.isTombstoned(dateKey) {
                print("[Tombstone] Blocking image load for path: \(path) (Date: \(dateKey))")
                return
            }
        }
        
        // 1. Check Cache
        if let cached = ImageCacheService.shared.getImage(for: currentKey) {
            self.image = cached
            let elapsed = Int(Date().timeIntervalSince(startTime) * 1000)
            print("[PERF][Image] CACHE HIT for \(currentKey) in \(elapsed)ms")
            return
        }
        
        // 2. Download from Cloud/URL
        isLoading = true
        do {
            let downloadURL: URL
            if path.hasPrefix("http") {
                guard let u = URL(string: path) else { throw NSError(domain: "CloudImageView", code: 1, userInfo: nil) }
                downloadURL = u
            } else {
                downloadURL = try await CloudStorageService.shared.getDownloadURL(for: path)
            }
            
            let (data, _) = try await URLSession.shared.data(from: downloadURL)
            if let loaded = UIImage(data: data) {
                // Save to Cache with versioned key
                ImageCacheService.shared.saveImage(loaded, for: currentKey)
                let elapsed = Int(Date().timeIntervalSince(startTime) * 1000)
                print("[PERF][Image] DOWNLOADED \(currentKey) in \(elapsed)ms")
                
                await MainActor.run {
                    self.image = loaded
                    self.isLoading = false
                }
            }
        } catch {
            print("[PERF][Image] FAIL \(currentKey): \(error)")
            isLoading = false
        }
    }
}

struct SkeletonCard: View {
    var body: some View {
        ZStack {
            Color.dsCard // Static background base
        }
    }
}

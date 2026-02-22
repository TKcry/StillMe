import UIKit

extension UIImage {
    /// Resizes the image to fit within the specified maximum dimension while maintaining aspect ratio.
    /// This method is nonisolated to allow safe execution in background tasks without MainActor overhead.
    nonisolated func resized(to maxDimension: CGFloat) -> UIImage? {
        let aspectRatio = size.width / size.height
        var newSize: CGSize
        if aspectRatio > 1 {
            newSize = CGSize(width: maxDimension, height: maxDimension / aspectRatio)
        } else {
            newSize = CGSize(width: maxDimension * aspectRatio, height: maxDimension)
        }
        
        // Don't upscale
        if newSize.width >= size.width { return self }
        
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1.0 // Use the actual pixels
        let renderer = UIGraphicsImageRenderer(size: newSize, format: format)
        
        return renderer.image { _ in
            self.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }
}

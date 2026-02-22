import SwiftUI

struct CalibrationLayout {
    static let standardAspectRatio: CGFloat = 0.75 // 3:4
    
    /// Calculates the unified 3:4 rect within the container, matching the camera's visible area.
    static func overlayRect(in containerSize: CGSize) -> CGRect {
        let w = containerSize.width
        let h = containerSize.height
        
        // Target is 3:4. If container is wider than 3:4, use height as base.
        // If container is taller than 3:4, use width as base.
        if w / h > standardAspectRatio {
            let targetW = h * standardAspectRatio
            return CGRect(x: (w - targetW) / 2, y: 0, width: targetW, height: h)
        } else {
            let targetH = w / standardAspectRatio
            return CGRect(x: 0, y: (h - targetH) / 2, width: w, height: targetH)
        }
    }
}

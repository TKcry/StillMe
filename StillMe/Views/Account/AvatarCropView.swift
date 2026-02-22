import SwiftUI
import UIKit

/// A non-reactive controller to hold the UIScrollView reference.
/// Prevents SwiftUI re-render loops and freezes during interaction.
final class AvatarCropController {
    weak var scrollView: UIScrollView?
    
    var currentValues: (offset: CGPoint, scale: CGFloat)? {
        guard let sv = scrollView else { return nil }
        return (sv.contentOffset, sv.zoomScale)
    }
}

struct AvatarCropView: View {
    let image: UIImage
    let onCancel: () -> Void
    let onDone: (UIImage) -> Void
    
    @State private var controller = AvatarCropController()
    
    private let maskSize: CGFloat = UIScreen.main.bounds.width * 0.70
    
    var body: some View {
        GeometryReader { rootGeo in
            let systemSafeTop = rootGeo.safeAreaInsets.top
            let safeTop = calculateSafeTop(system: systemSafeTop)
            let useOverlayMode = systemSafeTop == 0
            
            ZStack {
                // 1. Full Screen Background
                Color.dsBackground.ignoresSafeArea()
                
                // 2. Image Display Area
                ZStack {
                    AvatarScrollView(
                        image: image,
                        maskSize: maskSize,
                        controller: controller
                    )
                    
                    CircleMaskOverlay(maskSize: maskSize, circleYRatio: 0.45)
                        .allowsHitTesting(false) // Let touches pass to ScrollView
                }
                .ignoresSafeArea()
            }
            // 3. Navigation Header (Exclusive Layout)
            .overlay(alignment: .top) {
                if useOverlayMode {
                    headerView
                        .padding(.top, safeTop)
                        .frame(maxWidth: .infinity)
                        .frame(height: safeTop + 52, alignment: .top)
                }
            }
            .safeAreaInset(edge: .top, spacing: 0) {
                if !useOverlayMode {
                    headerView
                }
            }
        }
    }
    
    // MARK: - Subviews
    
    private var headerView: some View {
        ZStack {
            // Solid black background to cover status bar content
            Color.dsBackground.frame(height: 52)
            
            Text("crop_title")
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(.white)
            
            HStack(spacing: 0) {
                Button(action: onCancel) {
                    Text("cancel_label")
                        .font(.system(size: 17))
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .frame(maxHeight: .infinity)
                        .contentShape(Rectangle())
                }
                
                Spacer()
                
                Button(action: {
                    if let cropped = renderCroppedImage() {
                        onDone(cropped)
                    }
                }) {
                    Text("done_label")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .frame(maxHeight: .infinity)
                        .contentShape(Rectangle())
                }
            }
        }
        .frame(height: 52)
        .overlay(
            Rectangle()
                .frame(height: 1)
                .foregroundColor(.white.opacity(0.12)),
            alignment: .bottom
        )
    }
    
    // MARK: - Logic
    
    private func calculateSafeTop(system: CGFloat) -> CGFloat {
        if system > 0 { return system }
        // UIKit Fallback if SwiftUI reports 0 (common in some modal contexts)
        let window = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first?.windows.first
        let uikitSafeTop = window?.safeAreaInsets.top ?? 0
        return uikitSafeTop > 0 ? uikitSafeTop : 44 // Last resort for notch devices
    }
    
    private func renderCroppedImage() -> UIImage? {
        guard let vals = controller.currentValues else { return nil }
        let contentOffset = vals.offset
        let zoomScale = vals.scale
        
        let screenW = UIScreen.main.bounds.width
        let screenH = UIScreen.main.bounds.height
        let circleX = (screenW - maskSize) / 2
        let circleY = (screenH * 0.45) - (maskSize / 2)
        
        // 1. Calculate the crop rectangle relative to the image in points
        let cropRectInPoints = CGRect(
            x: (contentOffset.x + circleX) / zoomScale,
            y: (contentOffset.y + circleY) / zoomScale,
            width: maskSize / zoomScale,
            height: maskSize / zoomScale
        )
        
        // 2. Render to a 512x512 square
        let targetSize = CGSize(width: 512, height: 512)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1.0 // Force 1x scale to get exactly 512px
        
        let renderer = UIGraphicsImageRenderer(size: targetSize, format: format)
        return renderer.image { context in
            // Draw the image such that the cropRectInPoints fills the 512x512 area
            let scaleRatio = targetSize.width / cropRectInPoints.width
            let drawRect = CGRect(
                x: -cropRectInPoints.origin.x * scaleRatio,
                y: -cropRectInPoints.origin.y * scaleRatio,
                width: image.size.width * scaleRatio,
                height: image.size.height * scaleRatio
            )
            
            // UIImage.draw(in:) automatically handles imageOrientation (EXIF)
            image.draw(in: drawRect)
        }
    }
}

// MARK: - Components

struct CircleMaskOverlay: View {
    let maskSize: CGFloat
    let circleYRatio: CGFloat
    
    var body: some View {
        GeometryReader { geo in
            let circleY = geo.size.height * circleYRatio
            
            ZStack {
                Color.dsBackground
                
                Circle()
                    .frame(width: maskSize, height: maskSize)
                    .position(x: geo.size.width / 2, y: circleY)
                    .blendMode(.destinationOut)
                
                Circle()
                    .stroke(Color.white.opacity(0.3), lineWidth: 1)
                    .frame(width: maskSize, height: maskSize)
                    .position(x: geo.size.width / 2, y: circleY)
            }
            .compositingGroup()
        }
    }
}

// MARK: - UIKit Bridge

struct AvatarScrollView: UIViewRepresentable {
    let image: UIImage
    let maskSize: CGFloat
    let controller: AvatarCropController
    
    func makeUIView(context: Context) -> UIScrollView {
        let sv = UIScrollView()
        sv.backgroundColor = UIColor(red: 31/255, green: 31/255, blue: 31/255, alpha: 1.0)
        sv.showsVerticalScrollIndicator = false
        sv.showsHorizontalScrollIndicator = false
        sv.alwaysBounceVertical = true
        sv.alwaysBounceHorizontal = true
        sv.contentInsetAdjustmentBehavior = .never
        sv.delegate = context.coordinator
        
        sv.isUserInteractionEnabled = true
        sv.delaysContentTouches = false
        
        let iv = UIImageView(image: image)
        iv.contentMode = .scaleAspectFill
        iv.clipsToBounds = true
        iv.isUserInteractionEnabled = true
        sv.addSubview(iv)
        context.coordinator.imageView = iv
        
        controller.scrollView = sv
        return sv
    }
    
    func updateUIView(_ uiView: UIScrollView, context: Context) {
        if context.coordinator.lastImage !== image {
            context.coordinator.setup(uiView, image: image, maskSize: maskSize)
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIScrollViewDelegate {
        var parent: AvatarScrollView
        var imageView: UIImageView?
        var lastImage: UIImage?
        
        init(_ parent: AvatarScrollView) { self.parent = parent }
        
        func setup(_ sv: UIScrollView, image: UIImage, maskSize: CGFloat) {
            lastImage = image
            guard let iv = imageView else { return }
            
            let imgW = image.size.width
            let imgH = image.size.height
            iv.frame = CGRect(x: 0, y: 0, width: imgW, height: imgH)
            sv.contentSize = image.size
            
            let svW = UIScreen.main.bounds.width
            let svH = UIScreen.main.bounds.height
            
            let minScale = max(maskSize / imgW, maskSize / imgH)
            sv.minimumZoomScale = minScale
            sv.maximumZoomScale = minScale * 12.0
            sv.zoomScale = minScale
            
            let circleX = (svW - maskSize) / 2
            let circleY = (svH * 0.45) - (maskSize / 2)
            
            sv.contentOffset = CGPoint(
                x: (imgW * minScale - svW) / 2,
                y: (imgH * minScale - svH) / 2 + (svH * 0.05)
            )
            
            sv.contentInset = UIEdgeInsets(
                top: circleY,
                left: circleX,
                bottom: svH - circleY - maskSize,
                right: circleX
            )
        }
        
        func viewForZooming(in scrollView: UIScrollView) -> UIView? { imageView }
    }
}

import SwiftUI
import AVFoundation

enum CaptureMode {
    case windowCapture
}

struct PreviewDraft: Identifiable {
    let id: String // draftCaptureId
    let image: UIImage
}

struct UnifiedCameraView: View {
    @EnvironmentObject var viewModel: AppViewModel
    @Environment(\.dismiss) var dismiss
    @StateObject private var camera: CameraService
    
    init(mode: CaptureMode, exportState: MomentExportState, onCaptured: ((UIImage) -> Void)? = nil) {
        self.mode = mode
        self.onCaptured = onCaptured
        self._camera = StateObject(wrappedValue: CameraService(exportState: exportState))
    }
    
    let mode: CaptureMode
    var onCaptured: ((UIImage) -> Void)? = nil
    
    @State private var isCapturing = false
    @State private var capturedImage: UIImage? = nil
    @State private var previewDraft: PreviewDraft? = nil // Replaces capturedImage & showPreview
    
    var body: some View {
        ZStack {
            Color.dsBackground.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header
                ZStack {
                    HStack {
                        Button {
                            viewModel.discardDraft(date: Date()) // Phase 211.0: Cleanup on cancel
                            dismiss()
                        } label: {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundColor(.white)
                        }
                        .padding(.leading, 20)
                        
                        Spacer()
                        
                        Button {
                            camera.switchCamera()
                        } label: {
                            Image(systemName: "arrow.triangle.2.circlepath")
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundColor(.white)
                        }
                        .padding(.trailing, 20)
                    }
                    
                    VStack(spacing: 4) {
                        Text(headerTitle)
                            .font(Typography.h2)
                            .foregroundColor(.white)
                        Text(headerSubtitle)
                            .font(Typography.small)
                            .foregroundColor(.white.opacity(0.6))
                    }
                }
                .padding(.top, 20)
                .padding(.bottom, 20)
                
                // Camera Preview Area (3:4) - FaceLog Layout
                ZStack {
                    GeometryReader { geo in
                        let rect = CalibrationLayout.overlayRect(in: geo.size)
                        
                        ZStack {
                            // Camera Preview
                            CameraPreviewView(camera: camera)
                                .onAppear { 
                                    camera.currentPosition = .back // StillMe Default
                                    camera.checkPermissions() 
                                }
                                .frame(width: rect.width, height: rect.height)
                                .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
                                .position(x: rect.midX, y: rect.midY)
                            
                            // Flash effect
                            if isCapturing {
                                Color.white
                                    .frame(width: rect.width, height: rect.height)
                                    .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
                                    .position(x: rect.midX, y: rect.midY)
                                    .transition(.opacity)
                            }
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                    }
                    .aspectRatio(3/4, contentMode: .fit)
                }
                .padding(.horizontal, 20)
                
                Spacer()
                
                // Bottom Controls
                HStack {
                    Spacer()
                    CaptureButton {
                        captureAction()
                    }
                    .disabled(isCapturing)
                    Spacer()
                }
                .padding(.bottom, 60)
            }
        }
        .navigationBarHidden(true)
        .onDisappear {
            // Phase 208.0: Cleanup any uncommitted drafts on exit
            viewModel.discardDraft(date: Date())
        }
        .onAppear {
            print("[UnifiedCameraView] onAppear. viewModelInstance=\(ObjectIdentifier(viewModel)) exportStateId=\(ObjectIdentifier(viewModel.exportState))")
            
            // Phase 213.10: Wire up Moment Capture for this local camera instance
            camera.onMomentCaptured = { url, context in
                var meta: [String: Any] = [
                    "sessionInstanceId": context.sessionInstanceId.uuidString,
                    "framesSinceSessionStart": camera.framesSinceSessionStart,
                    "freshnessAgeMs": camera.lastFrameTimestamp.timeIntervalSinceNow * -1000,
                    "cameraPosition": context.position == .front ? "front" : "back",
                    "captureId": context.activeCaptureId
                ]
                
                // Phase 284: Ensure targeted info is bundled if active
                if let tId = viewModel.targetedPairId {
                    meta["targetedPairId"] = tId
                }
                
                viewModel.saveMoment(url: url, date: context.date, metadata: meta)
            }
        }
        .onChange(of: viewModel.draftCaptureId) { _ in
            attemptShowPreview()
        }
        .sheet(item: $previewDraft) { draft in
            CapturePreviewSheet(
                image: draft.image,
                mode: mode,
                isFrontCamera: camera.currentPosition == .front,
                exportState: viewModel.exportState, // Phase 212.1: Unified State
                draftCaptureId: draft.id, // Phase 211.5: Pass strict value from item
                onRetake: {
                    viewModel.discardDraft(date: Date())
                    previewDraft = nil
                },
                onUse: {
                    handleUseImage(draft.image)
                    previewDraft = nil
                }
            )
        }
    }
    
    private var headerTitle: String { "Window" }
    private var headerSubtitle: String { "今の景色を記録しましょう" }
    
    private func captureAction() {
        withAnimation { isCapturing = true }
        viewModel.prepareCapture(date: Date()) // Phase 208.0: Prepare Draft ID before photo capture
        camera.capturePhoto(authoritativeId: viewModel.draftCaptureId) { image, thumb, authoritativeId in
            if let image = image {
                DispatchQueue.main.async {
                    // Phase 257: Sync thumbnail and authoritative ID immediately
                    if let thumb = thumb {
                        viewModel.capturedThumbnail = thumb
                    }
                    if !authoritativeId.isEmpty {
                        viewModel.draftCaptureId = authoritativeId
                        print("[UnifiedCameraView] Synced draftCaptureId to authoritativeId: \(authoritativeId)")
                    }
                    self.capturedImage = image
                    self.attemptShowPreview()
                }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                withAnimation { isCapturing = false }
            }
        }
    }
    
    private func attemptShowPreview() {
        guard let img = capturedImage, let draftId = viewModel.draftCaptureId else { return }
        
        // Prevent re-presenting same draft
        if previewDraft?.id == draftId { return }
        
        print("[UnifiedCameraView] present previewDraftId=\(draftId) vmDraft=\(viewModel.draftCaptureId ?? "nil")")
        self.previewDraft = PreviewDraft(id: draftId, image: img)
    }

    private func handleUseImage(_ image: UIImage) {
        // Phase 211.1: Pre-Commit Validation
        guard viewModel.draftCaptureId != nil else {
            print("[ERROR][CaptureFlow] No draftCaptureId found to commit. 'Use Photo' action blocked.")
            return
        }
        
        DispatchQueue.main.async {
            viewModel.addWindowEntry(image: image, camera: camera)
            dismiss()
        }
    }
}

struct CapturePreviewSheet: View {
    @EnvironmentObject var viewModel: AppViewModel
    let image: UIImage
    let mode: CaptureMode
    let isFrontCamera: Bool // Phase 207.2
    let exportState: MomentExportState // Phase 212.1
    let draftCaptureId: String // Phase 211.5: Non-optional strict value
    let onRetake: () -> Void
    let onUse: () -> Void

    var body: some View {
        ZStack {
            Color.dsBackground.ignoresSafeArea()
                .onAppear {
                    print("[PreviewSheet] appear draftCaptureId=\(draftCaptureId)")
                }
            
            VStack(spacing: 0) {
                // Header
                VStack(spacing: 4) {
                    Text(NSLocalizedString("capture_preview_title", comment: ""))
                        .font(Typography.h2)
                        .foregroundColor(.white)
                    Text(NSLocalizedString("capture_preview_subtitle", comment: ""))
                        .font(Typography.small)
                        .foregroundColor(.white.opacity(0.6))
                }
                .padding(.top, 20)
                .padding(.bottom, 20)
                
                // Image / Player (3:4)
                ZStack {
                    MomentPressPlayer(
                        date: Date(),
                        image: image,
                        momentPath: "\(Date().yyyyMMdd)/draft/moment_720.mp4", // Placeholder path for layout
                        cornerRadius: 24,
                        overrideCaptureId: draftCaptureId,
                        exportState: exportState
                    )
                    .onAppear {
                         print("[PreviewSheet] player overrideCaptureId=\(draftCaptureId)")
                    }
                    .aspectRatio(3/4, contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: 24))
                }
                .padding(.horizontal, 20)
                
                Spacer()

                HStack(spacing: 12) {
                    Button {
                        onRetake()
                    } label: {
                        Text("retake_label")
                            .font(Typography.bodyMedium)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.white.opacity(0.12))
                            .foregroundColor(.white)
                            .cornerRadius(12)
                    }

                    Button {
                        onUse()
                    } label: {
                        Text("button_use_photo")
                            .font(Typography.bodyMedium)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.white)
                            .foregroundColor(.black)
                            .cornerRadius(12)
                    }
                }
                .padding(20)
                .padding(.bottom, 40)
            }
        }
    }
}

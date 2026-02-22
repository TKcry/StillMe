import AVFoundation
import UIKit
import SwiftUI
import Combine

class CameraService: NSObject, ObservableObject {
    static let shared = CameraService() // Phase 213.0: Shared instance
    
    // Phase 213.0: Strict single-generation rule. 
    // All instances of CameraService share this same state object.
    private static let _sharedExportState = MomentExportState()
    var exportState: MomentExportState { CameraService._sharedExportState }
    
    override init() {
        super.init()
    }
    
    // Backwards compatibility for injection if needed
    init(exportState: MomentExportState) {
        super.init()
    }
    
    @Published var session = AVCaptureSession()
    @Published var photo: UIImage?
    @Published var currentPosition: AVCaptureDevice.Position = .front
    @Published var isReadyToCapture: Bool = true // Phase 209.2

    private let photoOutput = AVCapturePhotoOutput()
    private let videoOutput = AVCaptureVideoDataOutput()
    
    private var completion: ((UIImage?, UIImage?, String) -> Void)?
    
    // Phase 209.1: Direct hardware reference to prevent UI state lag
    private var activeCameraPosition: AVCaptureDevice.Position {
        return deviceInputPosition ?? currentPosition
    }
    
    private var deviceInputPosition: AVCaptureDevice.Position? {
        let input = session.inputs.compactMap { $0 as? AVCaptureDeviceInput }.first
        return input?.device.position
    }
    
    // Phase 209.0: Fixed state at the moment of shutter
    struct CaptureContext {
        let position: AVCaptureDevice.Position
        let date: Date
        let sessionInstanceId: UUID
        let activeCaptureId: String // Phase 213.3: Authoritative identity
    }
    var onMomentCaptured: ((URL?, CaptureContext) -> Void)?

    // Preview layer reference (used for cropping)
    weak var previewLayer: AVCaptureVideoPreviewLayer?
    
    // Moment Capture Logic
    private let videoQueue = DispatchQueue(label: "com.stillme.camera.videoQueue")
    
    /// Phase 206.5: Frame with temporal metadata
    struct RingBufferFrame {
        let buffer: CVPixelBuffer
        let monotonicTime: CFTimeInterval
    }
    
    private var ringBuffer: [RingBufferFrame] = []
    private var snapshotFrames: [RingBufferFrame] = [] // Phase 205: Immutable snapshot for export
    private let ringBufferLimit = 60 // Exactly 2.5s at 24fps (Phase 206.0)
    private var isCapturingMoment = false
    private var isExporting = false // Deprecated: replaced by momentState
    private var shouldTeardownAfterMoment = false
    private var momentStartDate: Date?

    // --- Phase 181 State Machine ---
    enum MomentCaptureState {
        case idle
        case capturingPost // Re-used for internal flow, but now means "processing pre-capture"
        case exporting
        case finished
    }
    @Published private(set) var momentState: MomentCaptureState = .idle
    
    // Phase 212.0: Public Accessor for Playback Guard
    var isMomentExporting: Bool {
        return momentState == .exporting || momentState == .capturingPost
    }
    
    // Phase 212.1: Reference-based gating helpers
    @MainActor
    private func beginExport(sessionId: String, captureId: String? = nil) {
        print("[ExportState] set TRUE (sessionId: \(sessionId), captureId: \(captureId ?? "nil")) exportStateId=\(ObjectIdentifier(self.exportState))")
        self.exportState.exportSessionId = sessionId
        if let cid = captureId {
            self.exportState.activeCaptureId = cid
        }
        self.exportState.isExporting = true
    }

    @MainActor
    private func endExport() {
        print("[ExportState] set FALSE exportStateId=\(ObjectIdentifier(self.exportState))")
        self.exportState.isExporting = false
        self.exportState.activeCaptureId = nil // Phase 213.3: ALWAYS clear on end
    }
    
    private let exportQueue = DispatchQueue(label: "com.stillme.camera.exportQueue", qos: .userInitiated)
    
    // --- Phase 192.0: Final Frame Injection ---
    private var pendingMomentFrames: [RingBufferFrame] = []
    private var pendingCaptureContext: CaptureContext? // Phase 209.0: Replaces pendingMomentDate
    
    // --- Phase 185 FPS Diagnostics ---
    private var fpsCount: Int = 0
    private var lastFpsLogTime: Date?
    
    // --- Phase 206.0: Session & Freshness Tracking ---
    private(set) var sessionInstanceId = UUID()
    private(set) var framesSinceSessionStart: Int = 0
    private(set) var lastFrameTimestamp: Date = Date()
    private var sessionStartMonotonicTime: CFTimeInterval = 0
    private var lastKnownFreshnessAgeMs: Int = 0
    
    // --- Phase 189.5: Teardown Coordination ---
    private var isTearingDown = false
    private let teardownQueue = DispatchQueue(label: "com.stillme.camera.teardownQueue")
    private let sessionQueue = DispatchQueue(label: "com.stillme.camera.sessionQueue") // Phase 244
    
    // --- Phase 189.6: Export Optimization ---
    private let ciContext = CIContext(options: [.useSoftwareRenderer: false])
    private var lastDropLogTime: TimeInterval = 0 // Phase 212.0: Log Throttling

    func checkPermissions() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            setupSession()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                if granted {
                    DispatchQueue.main.async { self?.setupSession() }
                }
            }
            default:
            break
        }
    }

    private func setupSession() {
        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            
            // Phase 247: Serialize setup and teardown via sessionQueue
            self.session.beginConfiguration()
            
            // Remove existing inputs
            for input in self.session.inputs {
                self.session.removeInput(input)
            }
            
            // Reset state
            self.isCapturingMoment = false
            self.shouldTeardownAfterMoment = false
            
            self.session.sessionPreset = .hd1280x720 // Phase 257: Use 720p for Moment stability

            guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: self.currentPosition) else {
                print("[Camera] 🚨 Failed to get device for position: \(self.currentPosition)")
                self.session.commitConfiguration()
                return
            }

            do {
                let input = try AVCaptureDeviceInput(device: device)
                if self.session.canAddInput(input) { self.session.addInput(input) }
                
                // Photo Output
                if self.session.canAddOutput(self.photoOutput) { self.session.addOutput(self.photoOutput) }
                
                if self.session.canAddOutput(self.videoOutput) {
                    self.session.addOutput(self.videoOutput)
                }
                
                // Photo Output configuration
                self.photoOutput.isHighResolutionCaptureEnabled = true // Final Policy: High-res storage
                
                // Phase 270: Always reconfigure Video Output settings and mirroring
                // This ensures that after a "Retake" (which calls setupSession), the mirroring property
                // is correctly applied to the connection for the new session configuration.
                self.videoOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32BGRA)]
                self.videoOutput.setSampleBufferDelegate(self, queue: self.videoQueue)
                self.videoOutput.alwaysDiscardsLateVideoFrames = true
                
                if let conn = self.videoOutput.connection(with: .video) {
                    if #available(iOS 17.0, *) {
                        if conn.isVideoRotationAngleSupported(90) { conn.videoRotationAngle = 90 }
                    } else {
                        if conn.isVideoOrientationSupported { conn.videoOrientation = .portrait }
                    }
                    if conn.isVideoMirroringSupported {
                        conn.isVideoMirrored = (self.currentPosition == .front)
                    }
                }

                self.session.commitConfiguration()
                
                // Phase 206.0/247: Rotate Session Identity & Serialize Start
                self.sessionInstanceId = UUID()
                self.framesSinceSessionStart = 0
                self.sessionStartMonotonicTime = CACurrentMediaTime()
                print("[Camera] 🆕 Session Instance Started (Serialized): \(self.sessionInstanceId.uuidString)")
                
                self.resetRingBuffer(reason: "Session setup startRunning")
                if !self.session.isRunning {
                    self.session.startRunning()
                }
            } catch {
                print("Camera setup error: \(error)")
                self.session.commitConfiguration()
            }
        }
    }

    func capturePhoto(authoritativeId: String? = nil, completion: @escaping (UIImage?, UIImage?, String) -> Void) {
        guard isReadyToCapture else {
            completion(nil, nil, "")
            return
        }
        
        guard let hwPos = deviceInputPosition else {
            print("[Guard] 🚨 Capture BLOCKED: active device input not found.")
            completion(nil, nil, "")
            return
        }
        
        self.completion = completion
        
        print("[Moment] capturePhoto CALLED. Triggering moment capture immediately.")
        
        // Trigger Moment Capture synchronously to prevent race condition with teardown
        triggerMomentCapture(authoritativeId: authoritativeId)
        
        let settings: AVCapturePhotoSettings
        if photoOutput.availablePhotoCodecTypes.contains(.hevc) {
            settings = AVCapturePhotoSettings(format: [AVVideoCodecKey: AVVideoCodecType.hevc])
        } else {
            settings = AVCapturePhotoSettings()
        }
        
        // Final Policy: Always use high-resolution for photos
        settings.isHighResolutionPhotoEnabled = true
    
        if let conn = photoOutput.connection(with: .video) {
            if #available(iOS 17.0, *) {
                if conn.isVideoRotationAngleSupported(90) {
                    conn.videoRotationAngle = 90
                }
            } else {
                if conn.isVideoOrientationSupported {
                    conn.videoOrientation = .portrait
                }
            }
            
            if conn.isVideoMirroringSupported {
                conn.isVideoMirrored = (currentPosition == .front)
            }
        }

        photoOutput.capturePhoto(with: settings, delegate: self)
    }
    
    // MARK: - Moment Capture
    
    // Watchdog for capture timeout
    private var momentTimeoutItem: DispatchWorkItem?



    private func triggerMomentCapture(authoritativeId: String? = nil) {
        if momentState != .idle {
            print("[Moment] ⚠️ Already in state \(momentState). Skipping trigger.")
            return
        }

        let t_shutter_mono = CACurrentMediaTime()
        let t_shutter_wall = Date()
        print("\n[Moment] shutter t_shutter_mono=\(t_shutter_mono) t_shutter_wall=\(t_shutter_wall)")
        print("[Moment] 📸 Shutter Pressed. Checking Freshness Gate...")
        
        let now = Date()
        let ageMs = Int(now.timeIntervalSince(lastFrameTimestamp) * 1000)
        let frameCount = videoQueue.sync { ringBuffer.count }
        
        // Phase 206.0: Freshness Gate Requirements
        let isMature = framesSinceSessionStart >= 30
        let isRecent = ageMs <= 200
        let isFull = frameCount >= ringBufferLimit
        
        let ok = isMature && isRecent && isFull
        lastKnownFreshnessAgeMs = ageMs
        
        print("[Moment] Freshness ok=\(ok) ageMs=\(ageMs) framesSinceStart=\(framesSinceSessionStart) buffer=\(frameCount)/\(ringBufferLimit) sessionId=\(sessionInstanceId.uuidString)")
        
        if !ok {
            print("[Moment] 🚨 Freshness Gate BLOCKED capture. isMature=\(isMature) isRecent=\(isRecent) isFull=\(isFull)")
            self.momentState = .idle
            self.onMomentCaptured?(nil, CaptureContext(
                position: currentPosition,
                date: now,
                sessionInstanceId: sessionInstanceId,
                activeCaptureId: authoritativeId ?? FileUtils.generateCaptureId(for: now)
            ))
            return
        }

        // Phase 213.3/213.10: Authoritative Identity Generation
        let activeId = authoritativeId ?? FileUtils.generateCaptureId(for: now)
        DispatchQueue.main.async {
            self.exportState.activeCaptureId = activeId
            self.exportState.startedAt = Date().timeIntervalSince1970
            print("[ExportState] set activeCaptureId=\(activeId)")
        }

        print("[Moment] ❄️ Freshness Gate PASSED. Freezing RingBuffer...")
        
        // Phase 205.2: Absolute Deep Copy for Snapshot
        videoQueue.sync {
            self.snapshotFrames = self.ringBuffer.compactMap { frame in
                if let copy = deepCopyPixelBuffer(frame.buffer) {
                    return RingBufferFrame(buffer: copy, monotonicTime: frame.monotonicTime)
                }
                return nil
            }
            self.ringBuffer.removeAll()
        }
        
        if let first = snapshotFrames.first, let last = snapshotFrames.last {
            let dur = last.monotonicTime - first.monotonicTime
            let latency = last.monotonicTime - t_shutter_mono
            print("[Moment] snapshotRange monoStart=\(first.monotonicTime) monoEnd=\(last.monotonicTime) duration=\(dur) latencyToShutter=\(latency)")
        }
        
        // Phase 209.1: Hardware-direct position to prevent state mismatch
        let hwPos = activeCameraPosition
        let uiPos = currentPosition
        // Phase 210.1: Fix mirroring at capture time
        let context = CaptureContext(
            position: hwPos,
            date: now,
            sessionInstanceId: sessionInstanceId,
            activeCaptureId: activeId // Phase 213.3
        )
        self.pendingCaptureContext = context
        self.momentState = .capturingPost
        
        print("[Moment] 📸 Snapshot state fixed: position=\(context.position == .front ? "front" : "back") date=\(context.date)")
        print("[Diagnostic] CapturePosition ui=\(uiPos == .front ? "front" : "back") hardware=\(hwPos == .front ? "front" : "back") context=\(context.position == .front ? "front" : "back")")
        
        if uiPos != hwPos {
            print("[WARNING][Moment] 🚨 CameraPosition mismatch detected at shutter! ui=\(uiPos == .front ? "front" : "back") hardware=\(hwPos == .front ? "front" : "back"). Using hardware value.")
        }
        
        let preFrames = snapshotFrames
        print("[Moment] Pre-capture frames saved: \(preFrames.count). Waiting for photo for final frame injection.")
        
        self.pendingMomentFrames = preFrames
        self.pendingCaptureContext = context
    }
    
    private func finalizeMomentLifecycle(url: URL?, context: CaptureContext) {
        let date = context.date
        Task { @MainActor in
            print("[Moment] >>> TRACE: State transition EXPORTING -> FINISHED")
            self.momentState = .finished
            if let url = url {
                print("[Moment] ✅ Export SUCCESS (MOV) path=\(url.lastPathComponent)")
            } else {
                print("[Moment] ⚠️ Export FAILED/ABORTED (Falling back to Level 3 frames or nil)")
            }
            self.onMomentCaptured?(url, context)
            
            // Clean up and reset to IDLE
            print("[Moment] Now checking for deferred stopAndTeardown.")
            
            // Restore discarding late frames
            self.videoQueue.async { [weak self] in
                self?.videoOutput.alwaysDiscardsLateVideoFrames = true
                print("[Moment] alwaysDiscardsLateVideoFrames = TRUE restored.")
            }
            
            // Phase 205.2 & 206.0: Fingerprint the saved video with session ID
            if let safeURL = url {
                // Phase 257: Move heavy image generation and SHA calculation off MainActor
                Task.detached(priority: .background) { [weak self] in
                    guard let self = self else { return }
                    let asset = AVAsset(url: safeURL)
                    let generator = AVAssetImageGenerator(asset: asset)
                    generator.appliesPreferredTrackTransform = true
                    if let cgImage = try? generator.copyCGImage(at: .zero, actualTime: nil) {
                        let sha = FileUtils.computeSHA256(for: UIImage(cgImage: cgImage))
                        print("[Capture] ✅ Fingerprint SUCCESS: frame0sha=\(sha) sessionId=\(self.sessionInstanceId.uuidString) camera=\(context.position == .front ? "front" : "back") freshnessAgeMs=\(self.lastKnownFreshnessAgeMs) framesSinceStart=\(self.framesSinceSessionStart)")
                    }
                }
            }

            // Phase 205: Clear snapshot after success
            self.videoQueue.async {
                self.snapshotFrames = []
            }

            // Reset to IDLE after a short delay to allow UI to settle
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                print("[Moment] >>> TRACE: State transition FINISHED -> IDLE")
                self.momentState = .idle
            }
        }
    }
    
    private func exportMoment(frames: [RingBufferFrame], context: CaptureContext, completion: @escaping (URL?) -> Void) {
        let date = context.date
        let captureId = context.activeCaptureId // Phase 213.3: Use authoritative ID
        
        // Phase 205: Use snapshotFrames explicitly for export safety
        let framesToUse = snapshotFrames.isEmpty ? frames : snapshotFrames
        guard !framesToUse.isEmpty else { completion(nil); return }
        
        // --- Phase 189: Robust Export Strategy ---
        // Level 1: Standard 720p / 24fps
        exportLevel1(frames: framesToUse, date: date, captureId: captureId) { [weak self] url in
            if let url = url {
                completion(url)
            } else {
                print("[Moment] Level 1 export FAILED. Retrying with Level 2 (480p/15fps)...")
                // Level 2: Low-res 480p / 15fps
                self?.exportLevel2(frames: frames, date: date, captureId: captureId) { url in
                    completion(url)
                }
            }
        }
    }

    private func exportLevel1(frames: [RingBufferFrame], date: Date, captureId: String, completion: @escaping (URL?) -> Void) {
        performVideoExport(frames: frames, date: date, width: 720, height: 1280, fps: 24, level: "L1", captureId: captureId, completion: completion)
    }

    private func exportLevel2(frames: [RingBufferFrame], date: Date, captureId: String, completion: @escaping (URL?) -> Void) {
        print("[Moment][L2] Preparing frames (Consolidated Pipeline)...")
        // Requirement: Maintain 720x1280 focus even in L2 to prevent rotation artifacts
        let targetW = 720
        let targetH = 1280
        
        let processedFrames = frames.enumerated().compactMap { index, frame -> RingBufferFrame? in
            if index % 2 != 0 { return nil } // Thinning (30fps -> 15fps approx)
            return frame
        }
        
        performVideoExport(frames: processedFrames, date: date, width: targetW, height: targetH, fps: 15, level: "L2", captureId: captureId, completion: completion)
    }


    private var isAppendingActive = false // Guard for re-entrancy

    private func performVideoExport(frames: [RingBufferFrame], date: Date, width: Int, height: Int, fps: Int, level: String, captureId: String, completion: @escaping (URL?) -> Void) {
        let outputURL = FileUtils.tempMomentURL()
        let fm = FileManager.default
        
        let logTag = "[Moment][\(level)]"
        let queueLabel = "com.stillme.camera.export.\(level)"
        print("\(logTag) EXPORT START: captureId=\(captureId) target=\(width)x\(height)@\(fps)fps queue=\(queueLabel)")
        
        // Phase 213.3: Reference-based gating - Use authoritative ID
        if Thread.isMainThread {
            beginExport(sessionId: level, captureId: captureId)
        } else {
            DispatchQueue.main.sync {
                self.beginExport(sessionId: level, captureId: captureId)
            }
        }
        
        guard !frames.isEmpty else {
            print("\(logTag) 🚨 ABORT: Frame list is empty")
            completion(nil); return
        }
        
        // Audit Input Buffer
        let firstFrame = frames[0].buffer
        let inW = CVPixelBufferGetWidth(firstFrame)
        let inH = CVPixelBufferGetHeight(firstFrame)
        let inFmt = CVPixelBufferGetPixelFormatType(firstFrame)
        if let first = frames.first, let last = frames.last {
            print("[Moment] exportRange monoStart=\(first.monotonicTime) monoEnd=\(last.monotonicTime)")
        }
        print("\(logTag) INPUT INFO: \(inW)x\(inH), format=\(inFmt), count=\(frames.count)")

        // Pixel-Upright: Target dimensions must be portrait
        let targetW = width // 720
        let targetH = height // 1280

        guard let writer = try? AVAssetWriter(outputURL: outputURL, fileType: .mov) else {
            print("\(logTag) 🚨 FAILED: Could not create AVAssetWriter")
            completion(nil); return
        }
        
        let videoCodec: AVVideoCodecType = .h264 // Final Policy: prioritized compatibility
        
        let settings: [String: Any] = [
            AVVideoCodecKey: videoCodec,
            AVVideoWidthKey: 720,
            AVVideoHeightKey: 1280,
            AVVideoCompressionPropertiesKey: [
                AVVideoAverageBitRateKey: Int(720 * 1280 * 2.1)
            ]
        ]
        
        print("\(logTag) Using Codec: H.264")
        
        // REQ: Insurance transform (Final Fallback)
        var preferredTransform: CGAffineTransform = .identity
        // We'll calculate the final transform after checking the first processed frame
        
        let input = AVAssetWriterInput(mediaType: .video, outputSettings: settings)
        input.expectsMediaDataInRealTime = false
        // PIXEL-UPRIGHT: Physical bytes are portrait. Meta transform initially identity.
        input.transform = .identity
        
        let sourceAttributes: [String: Any] = [
            kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32BGRA),
            kCVPixelBufferWidthKey as String: targetW,
            kCVPixelBufferHeightKey as String: targetH
        ]
        
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: input, sourcePixelBufferAttributes: sourceAttributes)
        
        if writer.canAdd(input) {
            writer.add(input)
        } else {
            print("\(logTag) 🚨 FAILED: canAdd(input) is false")
            completion(nil); return
        }
        
        if !writer.startWriting() {
            print("\(logTag) 🚨 FAILED: startWriting() status=\(writer.status) error=\(String(describing: writer.error))")
            completion(nil); return
        }
        
        writer.startSession(atSourceTime: .zero)
        
        // --- Requirement 1: Serial Append Protection ---
        isAppendingActive = false 
        var frameIndex = 0
        let totalCount = frames.count
        var lastAppendedPTS = CMTime.negativeInfinity
        
        input.requestMediaDataWhenReady(on: videoQueue) { [weak self] in
            guard let self = self else { return }
            
            if self.isAppendingActive {
                print("\(logTag) ⚠️ append already running, skip (idx=\(frameIndex))")
                return
            }
            self.isAppendingActive = true
            
            // Single loop to process frames sequentially
            while frameIndex < totalCount {
                if writer.status != .writing {
                    print("\(logTag) 🚨 writer.status=\(writer.status) (NOT writing) at idx=\(frameIndex) error=\(String(describing: writer.error))")
                    break
                }
                
                // Requirement 2: Handle Ready state with retry
                if !input.isReadyForMoreMediaData {
                    // Phase 212.0: Prevent Busy-Loop Starvation
                    // User Request: Yield only when not ready.
                    // Note: Task.sleep cannot be used here (DispatchQueue context). Thread.sleep is safe on private serial queue.
                    Thread.sleep(forTimeInterval: 0.002) // 2ms sleep to allow UI thread to breathe
                    self.isAppendingActive = false
                    return 
                }
                
                let frameMeta = frames[frameIndex]
                let frame = frameMeta.buffer
                let pts = CMTime(value: Int64(frameIndex), timescale: Int32(fps))
                
                // PHASE 202: Forced Physical Portrait Normalization
                let processed: CVPixelBuffer
                if let normalized = self.normalizePixelBufferToPortrait(frame, position: self.currentPosition) {
                    processed = normalized
                } else {
                    print("\(logTag) ⚠️ Failed to normalize frame \(frameIndex). Falling back.")
                    processed = frame
                }
                
                let pW = CVPixelBufferGetWidth(processed)
                let pH = CVPixelBufferGetHeight(processed)
                
                if frameIndex == 0 {
                    let sW = CVPixelBufferGetWidth(frame)
                    let sH = CVPixelBufferGetHeight(frame)
                    print("[MomentAppend] srcPB=\(sW)x\(sH) normalizedPB=\(pW)x\(pH)")
                }
                
                // Insurance: If still landscape, try final rotation meta
                if frameIndex == 0 && pW > pH {
                    print("\(logTag) ⚠️ Physics failed (Width > Height). Applying Insurance Transform.")
                    input.transform = CGAffineTransform(rotationAngle: .pi / 2)
                }
                
                // Force monotonic increase
                var safePTS = pts
                if safePTS <= lastAppendedPTS {
                    safePTS = CMTime(value: lastAppendedPTS.value + 1, timescale: lastAppendedPTS.timescale)
                    print("\(logTag) ⚠️ Corrected PTS tie: \(pts.seconds) -> \(safePTS.seconds)")
                }
                
                if adaptor.append(processed, withPresentationTime: safePTS) {
                    if frameIndex == 0 || frameIndex == totalCount - 1 || frameIndex % 30 == 0 {
                        print("\(logTag) ✅ index=\(frameIndex)/\(totalCount) pts=\(safePTS.seconds) status=\(writer.status)")
                    }
                    lastAppendedPTS = safePTS
                    frameIndex += 1
                } else {
                    print("\(logTag) 🚨 adaptor.append FAILED idx=\(frameIndex) pts=\(safePTS.seconds) status=\(writer.status) error=\(String(describing: writer.error))")
                    break // Exit loop on failure
                }
            }
            
            // Completion handling
            if frameIndex >= totalCount || writer.status != .writing {
                input.markAsFinished()
                writer.finishWriting {
                    print("\(logTag) finishWriting completed with status=\(writer.status) error=\(String(describing: writer.error))")
                    
                    // Phase 212.1: Reference-based gating
                    if Thread.isMainThread {
                        self.endExport()
                    } else {
                        DispatchQueue.main.sync {
                            self.endExport()
                        }
                    }
                    
                    self.isAppendingActive = false
                    if writer.status == .completed {
                        // REQ: Diagnostic Log for naturalSize
                        let asset = AVAsset(url: outputURL)
                        if let track = asset.tracks(withMediaType: .video).first {
                            let size = track.naturalSize
                            let transform = track.preferredTransform
                            print("\(logTag) ✅ VERIFIED: mov naturalSize=\(size.width)x\(size.height), transform=\(transform)")
                            
                            // PHASE 202: Extraction Verify
                            let generator = AVAssetImageGenerator(asset: asset)
                            generator.appliesPreferredTrackTransform = true
                            if let cgImage = try? generator.copyCGImage(at: .zero, actualTime: nil) {
                                print("\(logTag) ✅ EXTRACTION VERIFY: extracted image size=\(cgImage.width)x\(cgImage.height)")
                            }
                        }
                        completion(outputURL)
                    } else {
                        try? fm.removeItem(at: outputURL)
                        completion(nil)
                    }
                }
            } else {
                self.isAppendingActive = false // Allow next call from OS
            }
        }
    }

    private func resizePixelBuffer(_ pixelBuffer: CVPixelBuffer, width: Int, height: Int) -> CVPixelBuffer? {
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        let scaleX = CGFloat(width) / CGFloat(CVPixelBufferGetWidth(pixelBuffer))
        let scaleY = CGFloat(height) / CGFloat(CVPixelBufferGetHeight(pixelBuffer))
        let transformed = ciImage.transformed(by: CGAffineTransform(scaleX: scaleX, y: scaleY))
        
        var newBuffer: CVPixelBuffer?
        let attrs = [kCVPixelBufferIOSurfacePropertiesKey: [:]] as CFDictionary
        CVPixelBufferCreate(kCFAllocatorDefault, width, height, kCVPixelFormatType_32BGRA, attrs, &newBuffer)
        
        guard let outBuffer = newBuffer else { return nil }
        ciContext.render(transformed, to: outBuffer)
        return outBuffer
    }

    /// Phase 257.7: Orientation-safe 3:4 cropping and resizing
    private func resizeAndCropTo34(image: UIImage, targetWidth: CGFloat) -> UIImage {
        let targetRatio: CGFloat = 0.75 // 3:4
        let targetHeight = targetWidth / targetRatio
        let targetSize = CGSize(width: targetWidth, height: targetHeight)
        
        // 1. Calculate source-level crop rect (respecting image.size orientation)
        let srcSize = image.size
        let srcRatio = srcSize.width / srcSize.height
        
        var drawRect: CGRect
        if srcRatio > targetRatio {
            // Source is wider than 3:4 (e.g. 4:3 iPad or 16:9 Landscape)
            let drawW = targetHeight * srcRatio
            let offsetX = (targetWidth - drawW) / 2
            drawRect = CGRect(x: offsetX, y: 0, width: drawW, height: targetHeight)
        } else {
            // Source is taller than 3:4 (e.g. 16:9 Portrait)
            let drawH = targetWidth / srcRatio
            let offsetY = (targetHeight - drawH) / 2
            drawRect = CGRect(x: 0, y: offsetY, width: targetWidth, height: drawH)
        }
        
        // 2. Draw using UIGraphicsImageRenderer which correctly handles orientation
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1.0
        let renderer = UIGraphicsImageRenderer(size: targetSize, format: format)
        
        return renderer.image { _ in
            image.draw(in: drawRect)
        }
    }

    /// Phase 257.5: Forced 3:4 Aspect Ratio Unification
    private func cropToVisiblePreview(image: UIImage) -> UIImage {
        guard let cg = image.cgImage else { return image }
        guard let pl = previewLayer else { 
            // Fallback: Use new orientation-safe center crop to 3:4
            return resizeAndCropTo34(image: image, targetWidth: image.size.width)
        }

        // Normalized Rect 0-1 (corresponds to where preview bounds are in the output image)
        let norm = pl.metadataOutputRectConverted(fromLayerRect: pl.bounds)

        let w = CGFloat(cg.width)
        let h = CGFloat(cg.height)

        let rect = CGRect(
            x: norm.origin.x * w,
            y: norm.origin.y * h,
            width: norm.size.width * w,
            height: norm.size.height * h
        ).integral

        guard let out = cg.cropping(to: rect) else { return image }
        
        let croppedImage = UIImage(cgImage: out, scale: image.scale, orientation: image.imageOrientation)
        
        // Final sanity check: Ensure the result is indeed 3:4 (Portrait)
        // resizeAndCropTo34 will normalize orientation and fix any remaining ratio issues
        return resizeAndCropTo34(image: croppedImage, targetWidth: croppedImage.size.width)
    }
    
    // DEPRECATED: Replaced by resizeAndCropTo34
    private func centerCropTo34(image: UIImage) -> UIImage { return image }
    private func resizeTo34(image: UIImage, width: CGFloat) -> UIImage { return image }

    /// Phase 257: High-Quality Resize helper
    private func resize(image: UIImage, targetShortSide: CGFloat) -> UIImage {
        let size = image.size
        let isPortrait = size.height > size.width
        let scale = targetShortSide / (isPortrait ? size.width : size.height)
        
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)
        let renderer = UIGraphicsImageRenderer(size: newSize)
        
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }

    /// Phase 207.5: High-Quality horizontal flip and orientation normalization to .up
    /// Replaces flipImageHorizontally to avoid noise/artifacts from CIImage/PixelBuffer conversions.
    private func bakeMirrorFlip(image: UIImage) -> UIImage {
        let size = image.size
        let renderer = UIGraphicsImageRenderer(size: size)
        
        return renderer.image { context in
            let cgContext = context.cgContext
            
            // 1. Flip horizontally
            cgContext.translateBy(x: size.width, y: 0)
            cgContext.scaleBy(x: -1.0, y: 1.0)
            
            // 2. Draw the original image baked into the new coordinate system
            image.draw(in: CGRect(origin: .zero, size: size))
        }
    }

    /// Phase 210.3: High-Quality Noise Reduction for Front Camera
    private func applyFrontCameraEnhancement(image: CIImage, logPrefix: String) -> CIImage {
        let intensity: Double = 0.02
        let sharpness: Double = 0.4
        
        guard let filter = CIFilter(name: "CINoiseReduction") else {
            return image
        }
        
        filter.setValue(image, forKey: kCIInputImageKey)
        filter.setValue(intensity, forKey: "inputNoiseLevel")
        filter.setValue(sharpness, forKey: "inputSharpness")
        
        if let output = filter.outputImage {
            print("[\(logPrefix)] applied: CINoiseReduction intensity=\(intensity)")
            return output
        }
        return image
    }

    func switchCamera() {
        print("[Camera] 🔄 Switching camera... (isReadyToCapture = FALSE)")
        isReadyToCapture = false
        
        session.beginConfiguration()
        
        // Remove existing input
        if let currentInput = session.inputs.first {
            session.removeInput(currentInput)
        }
        
        // Toggle position
        let newPos: AVCaptureDevice.Position = (self.currentPosition == .front) ? .back : .front
        self.currentPosition = newPos // UI State
        
        // Setup new device
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: currentPosition),
              let input = try? AVCaptureDeviceInput(device: device) else {
            session.commitConfiguration()
            return
        }
        
        if session.canAddInput(input) {
            session.addInput(input)
        }
        
        // Re-configure orientation if needed (usually handled per capture)
        
        session.commitConfiguration()
        
        // Determine mirroring and rotation for VideoDataOutput (Phase 198.2 Guaranteed)
        if let conn = videoOutput.connection(with: .video) {
            if #available(iOS 17.0, *) {
                if conn.isVideoRotationAngleSupported(90) {
                    conn.videoRotationAngle = 90
                }
            } else {
                if conn.isVideoOrientationSupported {
                    conn.videoOrientation = .portrait
                }
            }
            
            if conn.isVideoMirroringSupported {
                conn.isVideoMirrored = (currentPosition == .front)
            }
        }
        
        // Phase 209.2: Hardware stabilization delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            self.isReadyToCapture = true
            let hwPos = self.activeCameraPosition
            print("[Camera] ✅ Switch complete. isReadyToCapture = TRUE (hardware=\(hwPos == .front ? "front" : "back"))")
            
            if hwPos != self.currentPosition {
                print("[WARNING][Camera] 🚨 Session Input mismatch after swap! ui=\(self.currentPosition == .front ? "front" : "back") hardware=\(hwPos == .front ? "front" : "back")")
            }
        }
    }

    func stopSession() {
        sessionQueue.sync {
            resetRingBuffer(reason: "stopSession before")
            if session.isRunning {
                session.stopRunning()
            }
            resetRingBuffer(reason: "stopSession after")
            isCapturingMoment = false
        }
    }
    
    func stopSessionAsync() {
        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            self.resetRingBuffer(reason: "stopSessionAsync before")
            if self.session.isRunning {
                self.session.stopRunning()
            }
            self.resetRingBuffer(reason: "stopSessionAsync after")
            self.isCapturingMoment = false
        }
    }

    // MARK: - Helpers
    
    private func getRingBufferFrames() -> [RingBufferFrame] {
        return videoQueue.sync {
            let frames = ringBuffer
            ringBuffer.removeAll()
            return frames
        }
    }

    // --- Phase 206.0: RingBuffer Control ---
    func resetRingBuffer(reason: String) {
        videoQueue.async { [weak self] in
            guard let self = self else { return }
            print("[Camera] 🧹 Resetting RingBuffer. Reason: \(reason)")
            self.ringBuffer.removeAll()
            // Note: We don't reset framesSinceSessionStart here necessarily, 
            // as it tracks the life of the captureSession. 
            // sessionInstanceId is rotated only on startRunning.
        }
    }

    
    
    func stopAndTeardown(source: String = "Unknown", callId: String = UUID().uuidString.prefix(4).lowercased()) {
        teardownQueue.sync {
            if isTearingDown {
                print("[CameraService] ⚠️ stopAndTeardown IGNORE callId=\(callId) source=\(source) (already tearing down)")
                return
            }
            
            // If we are currently capturing or exporting, do NOT teardown yet.
            // The finalizeMomentLifecycle will call this again once finished.
            if momentState == .capturingPost || momentState == .exporting {
                print("[Moment] ⚠️ stopAndTeardown DEFERRED callId=\(callId) source=\(source) State=\(momentState)")
                shouldTeardownAfterMoment = true
                return
            }
            
            isTearingDown = true
            print("[CameraService] 🅿️ stopAndTeardown START callId=\(callId) source=\(source)")
            
            DispatchQueue.main.async {
                self.performTeardown(callId: String(callId))
            }
        }
    }
    
    /// Forced stop for Debug Reset (ignores export safety)
    func forceStopForReset() {
        let callId = "reset-\(UUID().uuidString.prefix(4))"
        print("[DEBUG] 🚨 forceStopForReset CALLED. killing watchdog and state. callId=\(callId)")
        momentTimeoutItem?.cancel()
        momentTimeoutItem = nil
        DispatchQueue.main.async { 
            self.momentState = .idle 
            self.isTearingDown = false // Allow new teardown
            self.stopAndTeardown(source: "DebugReset", callId: String(callId))
        }
    }

    private func performTeardown(callId: String) {
        let dispatchGroup = DispatchGroup()
        dispatchGroup.enter()
        
        // Phase 257.6: Use sessionQueue to serialize with setupSession
        sessionQueue.async { [weak self] in
            guard let self = self else {
                dispatchGroup.leave()
                return
            }
            
            if self.session.isRunning {
                self.session.stopRunning()
            }
            
            // Remove inputs and outputs to ensure hardware release
            self.session.beginConfiguration()
            self.session.inputs.forEach { self.session.removeInput($0) }
            self.session.outputs.forEach { self.session.removeOutput($0) }
            self.session.commitConfiguration()
            
            self.isCapturingMoment = false
            
            dispatchGroup.leave()
        }
        
        // Wait for session stop before clearing UI (optional but safer)
        dispatchGroup.notify(queue: .main) { [weak self] in
            guard let self = self else { return }
            self.previewLayer?.removeFromSuperlayer()
            self.previewLayer = nil
            self.isTearingDown = false // Done
            print("[CameraService] ✅ stopAndTeardown END callId=\(callId)")
        }
    }
}

// MARK: - Delegates

extension CameraService: AVCapturePhotoCaptureDelegate {
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        if let error = error {
            print("Capture error: \(error)")
            completion?(nil, nil, "")
            return
        }

        guard let data = photo.fileDataRepresentation(),
              let image = UIImage(data: data) else {
            completion?(nil, nil, "")
            return
        }

        // Phase 257.5: WYSIWYG Crop (Strict 3:4)
        var fixed = cropToVisiblePreview(image: image)
        
        // Phase 210.3: Noise Reduction (Still)
        if pendingCaptureContext?.position == .front {
            let ciStill = CIImage(image: fixed)
            if let ciStill = ciStill {
                let enhanced = applyFrontCameraEnhancement(image: ciStill, logPrefix: "stillEnhance")
                if let cg = ciContext.createCGImage(enhanced, from: enhanced.extent) {
                    fixed = UIImage(cgImage: cg, scale: fixed.scale, orientation: fixed.imageOrientation)
                }
            }
        }
        
        // Phase 257.5: Unify resolution to exactly 720x960 (3:4)
        fixed = resizeAndCropTo34(image: fixed, targetWidth: 720)

        let isFront = pendingCaptureContext?.position == .front
        // Phase 210.2: (REMOVED: redundant with photoOutput connection in capturePhoto)
        // Manual baking results in "un-mirroring" the already mirrored hardware data.
        
        // Phase 210.2: Audit Log before final save
        let finalSha = FileUtils.computeSHA256(for: fixed) ?? "unknown"
        print("[Capture] stillSaved mirrorBaked=\(isFront) frame0sha=\(finalSha)")
        
        let tPhotoMono = CACurrentMediaTime()
        let tPhotoWall = Date()
        print("[Moment] photoCaptured tMonotonic=\(tPhotoMono) tWall=\(tPhotoWall)")

        // --- Phase 192.0: Final Frame Injection ---
        if momentState == .capturingPost, let context = pendingCaptureContext {
            print("[Moment] Photo captured. Injecting final frames to tail via NORMALIZE pipeline (Context Position: \(context.position == .front ? "front" : "back"))...")
            
            // PHASE 202/209.0: Use the FIXED position from context for normalization
            if let cgImage = fixed.cgImage {
                let tempCI = CIImage(cgImage: cgImage)
                var tempBuffer: CVPixelBuffer?
                let attrs = [kCVPixelBufferIOSurfacePropertiesKey: [:]] as CFDictionary
                CVPixelBufferCreate(kCFAllocatorDefault, Int(tempCI.extent.width), Int(tempCI.extent.height), kCVPixelFormatType_32BGRA, attrs, &tempBuffer)
                
                if let tb = tempBuffer {
                    ciContext.render(tempCI, to: tb)
                    if let photoBuffer = normalizePixelBufferToPortrait(tb, position: context.position) {
                        // Phase 206.0: 10 frames (0.4s) tail padding
                        for _ in 0..<10 {
                            pendingMomentFrames.append(RingBufferFrame(buffer: photoBuffer, monotonicTime: tPhotoMono))
                        }
                        print("[Moment] ✅ Photo frame normalized using context position (\(context.position == .front ? "front" : "back")) injected to tail")
                    }
                }
            }
            
            let framesToExport = pendingMomentFrames
            pendingMomentFrames = [] // Clear
            pendingCaptureContext = nil
            
            self.exportMoment(frames: framesToExport, context: context) { [weak self] url in
                guard let self = self else { return }
                self.finalizeMomentLifecycle(url: url, context: context)
            }
        }

        // Create 320p thumbnail (Strict 3:4)
        let thumb = resizeAndCropTo34(image: fixed, targetWidth: 320)

        // Return image AND ID to caller for immediate sync
        let authoritativeId = pendingCaptureContext?.activeCaptureId ?? ""
        completion?(fixed, thumb, authoritativeId)
    }
    
    /// Helper to convert UIImage to CVPixelBuffer for final frame injection
    private func uiImageToPixelBuffer(image: UIImage, width: Int, height: Int) -> CVPixelBuffer? {
        var pixelBuffer: CVPixelBuffer?
        let attrs = [kCVPixelBufferIOSurfacePropertiesKey: [:]] as CFDictionary
        let status = CVPixelBufferCreate(kCFAllocatorDefault, width, height, kCVPixelFormatType_32BGRA, attrs, &pixelBuffer)
        
        guard status == kCVReturnSuccess, let buffer = pixelBuffer else { return nil }
        
        let ciImage = CIImage(image: image)
        let context = CIContext()
        
        // Resize and render
        let scaleX = CGFloat(width) / image.size.width
        let scaleY = CGFloat(height) / image.size.height
        let transformed = ciImage?.transformed(by: CGAffineTransform(scaleX: scaleX, y: scaleY))
        
        if let transformed = transformed {
            context.render(transformed, to: buffer)
            return buffer
        }
        return nil
    }
}

extension CameraService: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        // Phase 206.0: Vital Tracking
        lastFrameTimestamp = Date()
        framesSinceSessionStart += 1
        
        if momentState == .idle {
            // Pre-capture ring buffer only in idle
            addToRingBuffer(sampleBuffer)
        }
    }
    
    private func addToRingBuffer(_ sampleBuffer: CMSampleBuffer) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer),
              let copy = deepCopyPixelBuffer(pixelBuffer) else { return }
        let monoTime = CACurrentMediaTime()
        let frame = RingBufferFrame(buffer: copy, monotonicTime: monoTime)
        
        videoQueue.async { [weak self] in
            guard let self = self else { return }
            self.ringBuffer.append(frame)
            if self.ringBuffer.count > self.ringBufferLimit {
                self.ringBuffer.removeFirst()
            }
        }
    }

    func captureOutput(_ output: AVCaptureOutput, didDrop sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        if momentState == .capturingPost {
            // Phase 212.0: Throttle spam logs (1/sec)
            let now = CACurrentMediaTime()
            if now - lastDropLogTime > 1.0 {
                print("[Moment] 🚨 FRAME DROPPED during post-capture. isRunning=\(session.isRunning) (Throttled)")
                lastDropLogTime = now
            }
        }
    }

    private func rotateAndResizePixelBuffer(_ buffer: CVPixelBuffer, targetW: Int, targetH: Int) -> CVPixelBuffer? {
        return normalizePixelBufferToPortrait(buffer, position: .back)
    }

    private func deepCopyPixelBuffer(_ pixelBuffer: CVPixelBuffer) -> CVPixelBuffer? {
        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)
        let format = CVPixelBufferGetPixelFormatType(pixelBuffer)
        
        var newPixelBuffer: CVPixelBuffer?
        let attrs = [kCVPixelBufferIOSurfacePropertiesKey: [:]] as CFDictionary
        let status = CVPixelBufferCreate(kCFAllocatorDefault, width, height, format, attrs, &newPixelBuffer)
        
        guard status == kCVReturnSuccess, let copy = newPixelBuffer else { return nil }
        
        CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
        CVPixelBufferLockBaseAddress(copy, [])
        defer {
            CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly)
            CVPixelBufferUnlockBaseAddress(copy, [])
        }
        
        let planeCount = CVPixelBufferGetPlaneCount(pixelBuffer)
        if planeCount == 0 {
            let dest = CVPixelBufferGetBaseAddress(copy)
            let src = CVPixelBufferGetBaseAddress(pixelBuffer)
            let bytes = CVPixelBufferGetDataSize(pixelBuffer)
            if let dest = dest, let src = src {
                memcpy(dest, src, bytes)
            }
        } else {
            for i in 0..<planeCount {
                let dest = CVPixelBufferGetBaseAddressOfPlane(copy, i)
                let src = CVPixelBufferGetBaseAddressOfPlane(pixelBuffer, i)
                let bytes = CVPixelBufferGetBytesPerRowOfPlane(pixelBuffer, i) * CVPixelBufferGetHeightOfPlane(pixelBuffer, i)
                if let dest = dest, let src = src {
                    memcpy(dest, src, bytes)
                }
            }
        }
        
        return copy
    }

    /// PHASE 202: Forced Physical Portrait Normalization (720x1280)
    private func normalizePixelBufferToPortrait(_ pb: CVPixelBuffer, position: AVCaptureDevice.Position) -> CVPixelBuffer? {
        let inW = CVPixelBufferGetWidth(pb)
        let inH = CVPixelBufferGetHeight(pb)
        let targetW = 720
        let targetH = 1280
        
        var ci = CIImage(cvPixelBuffer: pb)
        
        // 1. Physical Rotation if Landscape
        if inW > inH {
            ci = ci.oriented(.right) // 90 deg clockwise
        }
        
        // 2. Mirroring (Removed: redundant with videoOutput connection in setupSession)
        if position == .front {
            // Phase 210.3: Noise Reduction (Video/Moment)
            ci = applyFrontCameraEnhancement(image: ci, logPrefix: "videoEnhance")
        }
        
        // 3. Scale and Crop to 720x1280 (Aspect Fill)
        let curW = ci.extent.width
        let curH = ci.extent.height
        let scale = max(CGFloat(targetW) / curW, CGFloat(targetH) / curH)
        
        let scaled = ci.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
        let originX = (scaled.extent.width - CGFloat(targetW)) / 2
        let originY = (scaled.extent.height - CGFloat(targetH)) / 2
        let cropped = scaled.cropped(to: CGRect(x: scaled.extent.origin.x + originX, y: scaled.extent.origin.y + originY, width: CGFloat(targetW), height: CGFloat(targetH)))
        
        let finalImage = cropped.transformed(by: CGAffineTransform(translationX: -cropped.extent.origin.x, y: -cropped.extent.origin.y))
        
        var outBuffer: CVPixelBuffer?
        let attrs = [kCVPixelBufferIOSurfacePropertiesKey: [:]] as CFDictionary
        let status = CVPixelBufferCreate(kCFAllocatorDefault, targetW, targetH, kCVPixelFormatType_32BGRA, attrs, &outBuffer)
        
        if status == kCVReturnSuccess, let ob = outBuffer {
            self.ciContext.render(finalImage, to: ob)
            return ob
        }
        return nil
    }
}

struct CameraPreviewView: UIViewRepresentable {
    @ObservedObject var camera: CameraService

    class PreviewView: UIView {
        override func layoutSubviews() {
            super.layoutSubviews()
            if let layer = self.layer.sublayers?.first as? AVCaptureVideoPreviewLayer {
                layer.frame = self.bounds
            }
        }
    }

    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        view.backgroundColor = UIColor(red: 31/255, green: 31/255, blue: 31/255, alpha: 1.0)

        let previewLayer = AVCaptureVideoPreviewLayer(session: camera.session)
        previewLayer.videoGravity = .resizeAspectFill

        view.layer.addSublayer(previewLayer)

        // Pass to service
        camera.previewLayer = previewLayer

        return view
    }

    func updateUIView(_ uiView: PreviewView, context: Context) {
        if let layer = uiView.layer.sublayers?.first as? AVCaptureVideoPreviewLayer {
            layer.frame = uiView.bounds
        }
    }
}

import SwiftUI
import AVFoundation

enum TodayCardType: Equatable {
    case publicPhoto
    case targeted(pairId: String)
}

struct TodayFlipCardView: View {
    @EnvironmentObject var viewModel: AppViewModel
    @Binding var isFlipped: Bool
    let type: TodayCardType
    let mode: TodayCardMode
    @ObservedObject var camera: CameraService
    let capturedImage: UIImage?
    let momentRefresher: UUID
    
    var body: some View {
        ZStack {
            // Front: Photo / Camera
            TodayPhotoCardView(
                type: type,
                mode: mode,
                camera: camera,
                capturedImage: capturedImage,
                momentRefresher: momentRefresher
            )
            .opacity(isFlipped ? 0 : 1)
            .rotation3DEffect(.degrees(isFlipped ? 180 : 0), axis: (x: 0, y: 1, z: 0))
            
            // Back: Memo
            TodayMemoCardView(type: type)
                .opacity(isFlipped ? 1 : 0)
                .rotation3DEffect(.degrees(isFlipped ? 0 : -180), axis: (x: 0, y: 1, z: 0))
        }
        .aspectRatio(0.75, contentMode: .fit)
        .onTapGesture {
            // Only allow flip if today's photo exists and mode is idle
            let record = viewModel.records[Date().yyyyMMdd]
            let hasPhoto: Bool
            switch type {
            case .publicPhoto:
                hasPhoto = record?.hasWindow ?? false
            case .targeted(let pid):
                hasPhoto = record?.targetedStatus(for: pid)?.hasWindow ?? false
            }

            if mode == .idle && hasPhoto {
                withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                    isFlipped.toggle()
                }
            }
        }
    }
}

private struct TodayPhotoCardView: View {
    @EnvironmentObject var viewModel: AppViewModel
    let type: TodayCardType
    let mode: TodayCardMode
    @ObservedObject var camera: CameraService
    let capturedImage: UIImage?
    let momentRefresher: UUID
    
    var body: some View {
        let record = viewModel.records[Date().yyyyMMdd]
        let hasPhoto: Bool = {
            switch type {
            case .publicPhoto:
                return record?.hasWindow ?? false
            case .targeted(let pid):
                return record?.targetedStatus(for: pid)?.hasWindow ?? false
            }
        }()
        
        return ZStack {
            if mode == .camera {
                AppCard(padding: 0, cornerRadius: Radius.container) {
                    CameraPreviewView(camera: camera)
                }
            } else if mode == .preview, let image = capturedImage {
                AppCard(padding: 0, cornerRadius: Radius.container) {
                    MomentPressPlayer(
                        date: Date(),
                        image: image,
                        momentPath: "\(Date().yyyyMMdd)/draft/moment_720.mp4",
                        cornerRadius: Radius.container,
                        overrideCaptureId: viewModel.draftCaptureId,
                        exportState: viewModel.exportState
                    )
                }
            } else {
                if hasPhoto {
                    photoCard(isPublic: type == .publicPhoto)
                } else {
                    AppCard(padding: 0, cornerRadius: Radius.container) {
                        TodayNudgeView(type: type)
                    }
                }
            }
        }
    }
    
    private func photoCard(isPublic: Bool) -> some View {
        let record = viewModel.records[Date().yyyyMMdd]
        
        // Data Extraction
        let imagePath: String?
        let photoUrl: String?
        let momentPath: String?
        let captureId: String?
        
        switch type {
        case .publicPhoto:
            imagePath = record?.windowImagePath
            photoUrl = record?.windowPhotoUrl
            momentPath = record?.momentPath
            captureId = record?.selectedCaptureId
        case .targeted(let pid):
            let s = record?.targetedStatus(for: pid)
            imagePath = s?.windowImagePath
            photoUrl = s?.windowPhotoUrl
            momentPath = s?.momentPath
            captureId = nil // Targeted captures currently don't use global captureId for anchor
        }
        
        let localImage = imagePath.flatMap { viewModel.loadImage(path: $0) }
        
        return AppCard(padding: 0, cornerRadius: Radius.container) {
            MomentPressPlayer(
                date: Date(),
                image: localImage,
                cloudImagePath: localImage == nil ? photoUrl : nil,
                momentPath: momentPath,
                cornerRadius: Radius.container,
                overrideCaptureId: captureId,
                exportState: viewModel.exportState
            )
            .id(momentRefresher)
            .onAppear {
                viewModel.ensureImageDownloaded(for: Date())
                viewModel.ensureMomentDownloaded(for: Date())
            }
        }
    }
}

private struct TodayNudgeView: View {
    @EnvironmentObject var viewModel: AppViewModel
    let type: TodayCardType
    
    var body: some View {
        VStack(spacing: 8) { 
            ZStack {
                Circle()
                    .fill(Color.white.opacity(0.1))
                    .frame(width: 100, height: 100)
                    .blur(radius: 20)
                
                Image(systemName: "camera.fill")
                    .font(.system(size: 48))
                    .foregroundColor(.white.opacity(0.3))
            }
            
            Text(titleText)
                .font(.system(size: 20, weight: .black))
                .tracking(1.0)
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        .background(
            LinearGradient(
                colors: [Color.white.opacity(0.05), Color.clear],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
    }
    
    private var titleText: String {
        switch type {
        case .publicPhoto:
            return "今日の思い出を残そう"
        case .targeted(let pid):
            let name = viewModel.pairs.first(where: { $0.id == pid })?.name ?? "フレンド"
            return "「\(name)」に共有。"
        }
    }
}

private struct TodayMemoCardView: View {
    @EnvironmentObject var viewModel: AppViewModel
    let type: TodayCardType
    @State private var isEditing = false
    @State private var memoText = ""
    @FocusState private var isFocused: Bool
    
    var body: some View {
        AppCard(padding: Spacing.xl, cornerRadius: Radius.container) {
            VStack {
                Spacer()
                
                if isEditing {
                    TextField("コメントを入力...", text: $memoText)
                        .textFieldStyle(.plain)
                        .font(.system(size: 20, weight: .black))
                        .tracking(1.0)
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .focused($isFocused)
                        .submitLabel(.done)
                        .onSubmit {
                            saveMemo()
                        }
                } else {
                    HStack(spacing: 8) {
                        Text(memoText.isEmpty ? "コメントを入力" : memoText)
                            .font(.system(size: 20, weight: .black))
                            .tracking(1.0)
                            .foregroundColor(.white)
                        
                        if memoText.isEmpty {
                            Image(systemName: "pencil")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(.white.opacity(0.6))
                        }
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        isEditing = true
                        isFocused = true
                    }
                }
                
                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .onAppear {
            loadMemo()
        }
        .onChange(of: type) { _ in
            loadMemo()
        }
    }
    
    private func loadMemo() {
        let date = Date()
        let record = viewModel.records[date.yyyyMMdd]
        switch type {
        case .publicPhoto:
            memoText = record?.memo ?? ""
        case .targeted(let pid):
            memoText = record?.targetedStatus(for: pid)?.memo ?? ""
        }
    }
    
    private func saveMemo() {
        isEditing = false
        isFocused = false
        switch type {
        case .publicPhoto:
            viewModel.updateMemo(date: Date(), memo: memoText)
        case .targeted(let pid):
            viewModel.updateTargetedMemo(date: Date(), pairId: pid, memo: memoText)
        }
    }
}

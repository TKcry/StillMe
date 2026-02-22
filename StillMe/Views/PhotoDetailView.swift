import SwiftUI

struct PhotoDetailView: View {
    @EnvironmentObject var viewModel: AppViewModel
    private let sortedItems: [DayRecord]
    @Binding var isPresented: Bool
    let canDelete: Bool
    
    @State private var selectedIndex: Int
    @State private var showingDeleteAlert = false
    init(context: PhotoViewerContext, isPresented: Binding<Bool>, canDelete: Bool = true) {
        // 1. Filter items that have windows and Sort Oldest -> Newest
        let items = context.allEntries
            .filter { $0.hasWindow }
            .sorted { $0.id < $1.id }
        
        self.sortedItems = items
        self._isPresented = isPresented
        self.canDelete = canDelete
        
        // 2. Identify the index of the tapped date
        let initialIndex = items.firstIndex(where: { $0.id == context.id || $0.id.hasPrefix(context.id) }) ?? 0
        self._selectedIndex = State(initialValue: initialIndex)
    }
    
    var body: some View {
        ZStack {
            Color.dsBackground.ignoresSafeArea()
            
            TabView(selection: $selectedIndex) {
                ForEach(0..<sortedItems.count, id: \.self) { index in
                    PhotoDetailItem(entry: sortedItems[index])
                        .tag(index)
                }
            }
            .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
            
            // Close button
            VStack {
                HStack {
                    if canDelete {
                        let currentEntry = sortedItems[selectedIndex]
                        let isPrivate = currentEntry.isPrivate ?? false
                        
                        Menu {
                            Button {
                                togglePrivacy()
                            } label: {
                                Label(isPrivate ? "フレンドに公開する" : "非公開にする", systemImage: isPrivate ? "eye" : "eye.slash")
                            }
                            
                            Button(role: .destructive) {
                                showingDeleteAlert = true
                            } label: {
                                Label("削除", systemImage: "trash")
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                                .font(.system(size: 22))
                                .foregroundColor(.white.opacity(0.8))
                                .padding(12)
                                .background(.ultraThinMaterial)
                                .clipShape(Circle())
                        }
                        .padding(.top, 20)
                        .padding(.leading, 20)
                    }
                    
                    Spacer()
                    
                    Button {
                        isPresented = false
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.white)
                            .padding(12)
                            .background(.ultraThinMaterial)
                            .clipShape(Circle())
                    }
                    .padding(.top, 20)
                    .padding(.trailing, 20)
                }
                
                Spacer()
            }
        }
        .alert("delete_photo_title", isPresented: $showingDeleteAlert) {
            Button("cancel_label", role: .cancel) {}
            Button("delete_label", role: .destructive) {
                deleteCurrentPhoto()
            }
        } message: {
            Text("delete_photo_message")
        }
    }
    
    private func deleteCurrentPhoto() {
        let currentEntry = sortedItems[selectedIndex]
        guard let date = DateFormatter.yyyyMMdd.date(from: currentEntry.id) else { return }
        
        Task {
            do {
                try await viewModel.deletePhoto(date: date)
                DispatchQueue.main.async {
                    self.isPresented = false // Close detail view on success
                }
            } catch {
                print("[ERROR][DeletePhoto] Failed: \(error)")
            }
        }
    }
    
    private func togglePrivacy() {
        let currentEntry = sortedItems[selectedIndex]
        guard let date = DateFormatter.yyyyMMdd.date(from: currentEntry.id) else { return }
        
        let newPrivacy = !(currentEntry.isPrivate ?? false)
        
        Task {
            await viewModel.updatePhotoPrivacy(date: date, isPrivate: newPrivacy)
            // Local state update in AppViewModel will reflect via EnvironmentObject/Binding if lucky, 
            // but sortedItems is local to this view's init. 
            // We should probably rely on the fact that AppViewModel's records update and this view will re-render if it observes it.
        }
    }
}

// Individual item view
struct PhotoDetailItem: View {
    @EnvironmentObject var viewModel: AppViewModel
    let entry: DayRecord
    
    @State private var isFlipped = false
    
    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            
            // Photo Area
            ZStack {
                // Phase 294: Unified Stack/Single Display in Detail View
                if entry.hasWindow && entry.hasTargetedWindow {
                    PhotoStackView(
                        date: DateFormatter.yyyyMMdd.date(from: String(entry.id.prefix(10))) ?? Date(),
                        publicStatus: (thumb: entry.windowThumbPath, full: entry.windowFullPath, photoUrl: entry.windowPhotoUrl, moment: entry.momentPath),
                        targetedStatus: (thumb: entry.targetedWindowThumbPath, full: entry.targetedWindowFullPath, photoUrl: entry.targetedWindowPhotoUrl, moment: entry.targetedMomentPath),
                        showBorder: true,
                        onTap: { _ in
                            // For stack, we use a single flip action for the whole day's record
                            withAnimation(.spring(response: 0.6, dampingFraction: 0.8, blendDuration: 0)) {
                                isFlipped.toggle()
                            }
                        }
                    )
                    .opacity(isFlipped ? 0 : 1)
                    .rotation3DEffect(.degrees(isFlipped ? 180 : 0), axis: (x: 0, y: 1, z: 0))
                } else {
                    // Front: Photo (Single)
                    DetailPhotoCard(entry: entry)
                        .opacity(isFlipped ? 0 : 1)
                        .rotation3DEffect(.degrees(isFlipped ? 180 : 0), axis: (x: 0, y: 1, z: 0))
                }
                
                // Back: Memo
                DetailMemoCard(memo: entry.memo ?? "")
                    .opacity(isFlipped ? 1 : 0)
                    .rotation3DEffect(.degrees(isFlipped ? 0 : -180), axis: (x: 0, y: 1, z: 0))
                
                // Phase 300: Private Indicator
                if entry.isPrivate == true {
                    VStack {
                        HStack {
                            Spacer()
                            Image(systemName: "lock.fill")
                                .font(.system(size: 14))
                                .foregroundColor(.white)
                                .padding(8)
                                .background(.black.opacity(0.4))
                                .clipShape(Circle())
                                .padding(16)
                        }
                        Spacer()
                    }
                }
            }
            .onTapGesture {
                if !(entry.hasWindow && entry.hasTargetedWindow) {
                    // For single photos, tap flips
                    withAnimation(.spring(response: 0.6, dampingFraction: 0.8, blendDuration: 0)) {
                        isFlipped.toggle()
                    }
                }
            }
            .aspectRatio(0.75, contentMode: .fit)
            .shadow(color: .black.opacity(0.5), radius: 20, x: 0, y: 10)
            
            // Info Area
            VStack(spacing: 8) {
                if let date = DateFormatter.yyyyMMdd.date(from: String(entry.id.prefix(10))) {
                    Text(DateFormatter.displayDateJST.string(from: date))
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white)
                }
                
                if let capturedAt = entry.windowCapturedAt {
                    Text(DateFormatter.displayTimeJST.string(from: capturedAt))
                        .font(.system(size: 14))
                        .foregroundColor(.white.opacity(0.6))
                }
            }
            
            Spacer()
        }
        .padding(.horizontal, 24)
    }
}

private struct DetailPhotoCard: View {
    @EnvironmentObject var viewModel: AppViewModel
    let entry: DayRecord
    
    var body: some View {
        ZStack {
            Color.dsCard
            
            // Hybrid local/cloud playback (Phase 257.1)
            if let date = DateFormatter.yyyyMMdd.date(from: String(entry.id.prefix(10))) {
                let localPath = entry.windowImagePath
                let localImage = localPath.flatMap { viewModel.loadImage(path: $0) }
                
                MomentPressPlayer(
                    date: date,
                    image: localImage,
                    cloudImagePath: localImage == nil ? (entry.windowImagePath ?? entry.windowPhotoUrl) : nil,
                    momentPath: entry.momentPath,
                    cornerRadius: 32,
                    overrideCaptureId: entry.selectedCaptureId,
                    exportState: viewModel.exportState
                )
                .id(entry.id)
            } else {
                // Fallback for invalid record dates
                Image(systemName: "photo")
                    .foregroundColor(.white.opacity(0.1))
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
    }
}

private struct DetailMemoCard: View {
    let memo: String
    
    var body: some View {
        ZStack {
            Color.dsCard
            
            VStack(spacing: 20) {
                Spacer()
                
                if memo.isEmpty {
                    Text("コメントなし")
                        .font(.system(size: 17, weight: .medium))
                        .foregroundColor(.white.opacity(0.3))
                        .multilineTextAlignment(.center)
                        .lineSpacing(6)
                } else {
                    Text(memo)
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(.white.opacity(0.9))
                        .multilineTextAlignment(.center)
                        .lineSpacing(8)
                        .padding(.horizontal, 30)
                }
                
                Spacer()
            }
            .padding(40)
        }
        .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .strokeBorder(Color.white.opacity(0.3), lineWidth: 1)
        )
    }
}

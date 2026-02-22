import SwiftUI

struct GalleryTabView: View {
    @EnvironmentObject var viewModel: AppViewModel
    @State private var viewerContext: PhotoViewerContext? = nil
    @State private var selectedPairId: String? = nil // nil = All Public, non-nil = Targeted for a specific friend
    
    // columns for the grid (Responsive for iPad)
    private var columns: [GridItem] {
        let count = UIDevice.current.userInterfaceIdiom == .pad ? 5 : 3
        return Array(repeating: GridItem(.flexible(), spacing: 1), count: count)
    }
    
    var filteredEntries: [DayRecord] {
        if let pid = selectedPairId {
            // Friend Page: Only show if targeted status exists for THIS specific friend
            return viewModel.sortedEntries.filter { $0.targetedStatus(for: pid) != nil }
        } else {
            // Public Page: Only show if public photo exists
            return viewModel.sortedEntries.filter { $0.hasWindow }
        }
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Friend Selection Bar
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: Spacing.md) {
                        // Public Filter (Globe)
                        filterButton(pid: nil, name: NSLocalizedString("filter_public", comment: "Public"), systemIcon: "globe")
                        
                        // Pair Filters
                        ForEach(viewModel.pairs) { pair in
                            filterButton(pid: pair.id, name: pair.name, avatarPath: pair.partnerUid, avatarUpdatedAt: pair.avatarUpdatedAt)
                        }
                    }
                    .padding(.horizontal, Spacing.md)
                    .padding(.vertical, Spacing.sm)
                }
                .background(Color.dsBackground)
                
                Divider().background(Color.dsSeparator)
                
                ZStack {
                    Color.dsBackground.ignoresSafeArea()
                    
                    if filteredEntries.isEmpty {
                        VStack(spacing: Spacing.md) {
                            Image(systemName: "photo.on.rectangle")
                                .font(.system(size: 48))
                                .foregroundColor(.dsMutedDeep)
                            Text("no_photos_yet")
                                .font(Typography.body)
                                .foregroundColor(.dsMuted)
                        }
                    } else {
                        ScrollView {
                            LazyVGrid(columns: columns, spacing: 1) {
                                ForEach(filteredEntries) { entry in
                                    GalleryGridCell(entry: entry, selectedPairId: selectedPairId) {
                                        openPhotoViewer(at: entry.id)
                                    }
                                }
                            }
                            .padding(.bottom, 150) // Extra padding for tab bar
                        }
                    }
                }
            }
            .navigationTitle(NSLocalizedString("tab_gallery", comment: "Gallery"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    NavigationLink(destination: CalendarTabView()) {
                        Image(systemName: "calendar")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.dsForeground)
                    }
                }
            }
            .fullScreenCover(item: $viewerContext) { context in
                PhotoDetailView(context: context, isPresented: Binding(
                    get: { self.viewerContext != nil },
                    set: { if !$0 { self.viewerContext = nil } }
                ))
            }
        }
    }
    
    @ViewBuilder
    private func filterButton(pid: String?, name: String, systemIcon: String? = nil, avatarPath: String? = nil, avatarUpdatedAt: Date? = nil) -> some View {
        let isSelected = (selectedPairId == pid)
        
        Button(action: {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                selectedPairId = pid
            }
        }) {
            VStack(spacing: 4) {
                ZStack {
                    Circle()
                        .fill(isSelected ? Color.dsAccent.opacity(0.15) : Color.white.opacity(0.05))
                        .frame(width: 52, height: 52)
                    
                    if let icon = systemIcon {
                        Image(systemName: icon)
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(isSelected ? Color.dsAccent : .white)
                    } else if let uid = avatarPath {
                        CircleAvatarView(uid: uid, updatedAt: avatarUpdatedAt, size: 52, isSelected: isSelected)
                    }
                    
                    if isSelected {
                        Circle()
                            .stroke(Color.dsAccent, lineWidth: 2)
                            .frame(width: 52, height: 52)
                    }
                }
                
                Text(name)
                    .font(.system(size: 10, weight: isSelected ? .bold : .regular))
                    .foregroundColor(isSelected ? Color.dsAccent : .dsMuted)
                    .lineLimit(1)
                    .frame(width: 60)
            }
        }
        .buttonStyle(.plain)
    }
    
    private func openPhotoViewer(at id: String) {
        let pid = selectedPairId
        
        // Phase 295: Strip opposing photo data to ensure "Pure" view in Gallery Tab viewer
        let entriesToPass = filteredEntries.map { entry -> DayRecord in
            var e = entry
            if let targetId = pid {
                // Friend Page: Map targeted to primary fields and STRIP public data
                if let targeted = entry.targetedStatus(for: targetId) {
                    e.windowImagePath = targeted.windowImagePath
                    e.windowPhotoUrl = targeted.windowPhotoUrl
                    e.windowThumbPath = targeted.windowThumbPath
                    e.windowFullPath = targeted.windowFullPath
                    e.windowCapturedAt = targeted.windowCapturedAt
                    e.momentPath = targeted.momentPath
                    e.memo = targeted.memo
                }
                // Clear all targeted info to avoid PhotoDetailView stacking
                e.targetedCaptures = [:]
                e.targetedWindowImagePath = nil
                e.targetedWindowPhotoUrl = nil
                e.targetedWindowThumbPath = nil
                e.targetedWindowFullPath = nil
                e.targetedWindowCapturedAt = nil
                e.targetedMomentPath = nil
                e.targetedMemo = nil
            } else {
                // Public Page: STRIP all targeted data to avoid stacking
                e.targetedCaptures = [:]
                e.targetedWindowImagePath = nil
                e.targetedWindowPhotoUrl = nil
                e.targetedWindowThumbPath = nil
                e.targetedWindowFullPath = nil
                e.targetedWindowCapturedAt = nil
                e.targetedMomentPath = nil
                e.targetedMemo = nil
            }
            return e
        }
        
        self.viewerContext = PhotoViewerContext(id: id, allEntries: entriesToPass)
    }
}

private struct CircleAvatarView: View {
    @EnvironmentObject var viewModel: AppViewModel
    let uid: String
    let updatedAt: Date?
    let size: CGFloat
    let isSelected: Bool
    
    var body: some View {
        ZStack {
            if let image = viewModel.loadAvatar(uid: uid, updatedAt: updatedAt) {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: size, height: size)
                    .clipShape(Circle())
            } else {
                Image(systemName: "person.crop.circle.fill")
                    .resizable()
                    .scaledToFit()
                    .frame(width: size - 8, height: size - 8)
                    .foregroundColor(isSelected ? Color.dsAccent.opacity(0.6) : .dsMutedDeep)
            }
        }
    }
}

private struct GalleryGridCell: View {
    @EnvironmentObject var viewModel: AppViewModel
    let entry: DayRecord
    let selectedPairId: String?
    let action: () -> Void
    
    var displayThumbPath: String? {
        if let pid = selectedPairId {
            return entry.targetedStatus(for: pid)?.windowThumbPath
        }
        return entry.windowThumbPath
    }
    
    var displayPhotoUrl: String? {
        if let pid = selectedPairId {
            let status = entry.targetedStatus(for: pid)
            return status?.windowPhotoUrl ?? status?.windowImagePath
        }
        return entry.windowPhotoUrl ?? entry.windowImagePath
    }
    
    var body: some View {
        Button(action: action) {
            ZStack {
                Color.dsCard
                
                // 1. Try local load first (優先的にローカルのサムネイル/写真を探す)
                if let thumb = displayThumbPath, let uiImage = viewModel.loadImage(path: thumb) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(minWidth: 0, maxWidth: .infinity)
                        .clipped()
                } else if let photo = displayPhotoUrl, !photo.hasPrefix("http"), let uiImage = viewModel.loadImage(path: photo) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(minWidth: 0, maxWidth: .infinity)
                        .clipped()
                }
                // 2. Fallback to Cloud load (ローカルにない場合はCloudから取得)
                else if let path = displayThumbPath ?? displayPhotoUrl {
                    CloudImageView(path: path, contentMode: .fill)
                        .frame(minWidth: 0, maxWidth: .infinity)
                        .aspectRatio(0.75, contentMode: .fill)
                        .clipped()
                } else {
                    // Placeholder
                    Image(systemName: "photo")
                        .foregroundColor(.white.opacity(0.1))
                }
            }
            .aspectRatio(0.75, contentMode: .fit)
        }
        .buttonStyle(.plain)
    }
}

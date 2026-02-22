import SwiftUI
import FirebaseFirestore
import FirebaseAuth

struct PairDetailView: View {
    @Environment(\.dismiss) var dismiss
    let pairId: String
    @EnvironmentObject var store: PairStore
    @EnvironmentObject var appViewModel: AppViewModel // Added for image loading
    
    @StateObject private var viewModel: PairStatusViewModel
    @State private var showPhotos: Bool = false
    @State private var showingBlockAlert = false
    @State private var selectedStatus: TodayStatusModel? = nil
    
    @State private var viewerContext: PhotoViewerContext? = nil
    
    init(pairId: String) {
        self.pairId = pairId
        let myUid = Auth.auth().currentUser?.uid ?? ""
        _viewModel = StateObject(wrappedValue: PairStatusViewModel(pairId: pairId, myUid: myUid))
    }

    var body: some View {
        VStack(spacing: Spacing.md) {
            // 1.5 Partner Info & Relationship (Now includes Calendar)
            partnerRelationshipRow
                
            // 2. Today's Activity Card
            todayAchievementCard
                
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 24)
        .padding(.top, Spacing.sm)
        .frame(maxWidth: 600) // Phase 257: Limit content width on iPad
        .frame(maxHeight: .infinity)
        .navigationTitle("nav_title_pair_status")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button(action: {
                        Task { try? await store.toggleMuteUser(uid: pairId.components(separatedBy: "_").first(where: { $0 != viewModel.myUid }) ?? "") }
                    }) {
                        Label(store.mutedUids.contains(pairId.components(separatedBy: "_").first(where: { $0 != viewModel.myUid }) ?? "") ? "unmute_success" : "menu_mute", systemImage: "bell.slash")
                    }
                    
                    Button(action: {
                        Task {
                            try? await store.hidePair(pairId: pairId)
                            dismiss()
                        }
                    }) {
                        Label("menu_hide_pair", systemImage: "eye.slash")
                    }
                    
                    Button(role: .destructive, action: {
                        showingBlockAlert = true
                    }) {
                        Label("menu_block", systemImage: "person.slash")
                    }
                    
                    Button(action: {
                        // Report logic usually needs a sub-picker or alert
                        Task { try? await store.reportUser(uid: pairId.components(separatedBy: "_").first(where: { $0 != viewModel.myUid }) ?? "", reason: "Reported from Detail View") }
                    }) {
                        Label("menu_report", systemImage: "exclamationmark.bubble")
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.dsForeground)
                        .padding(8)
                }
            }
        }
        .background(Color.dsBackground.ignoresSafeArea())
        .alert("block_confirm_title", isPresented: $showingBlockAlert) {
            Button("cancel", role: .cancel) { }
            Button("menu_block", role: .destructive) {
                Task {
                    let partnerUid = pairId.components(separatedBy: "_").first(where: { $0 != viewModel.myUid }) ?? ""
                    try? await store.blockUser(uid: partnerUid)
                    dismiss()
                }
            }
        } message: {
            Text("block_confirm_message")
        }
        .sheet(isPresented: $showPhotos) {
            photosSheetContent
        }
        .fullScreenCover(item: $viewerContext) { context in
            PhotoDetailView(context: context, isPresented: Binding(
                get: { self.viewerContext != nil },
                set: { if !$0 { self.viewerContext = nil } }
            ), canDelete: false)
        }
    }
    
    private func showPhotosFor(status: TodayStatusModel) {
        self.selectedStatus = status
        self.showPhotos = true
    }
    
    @ViewBuilder
    private var photosSheetContent: some View {
        if let ts = selectedStatus ?? viewModel.currentTodayStatus {
            let partnerUid = pairId.components(separatedBy: "_").first(where: { $0 != viewModel.myUid }) ?? ""
            TodayPhotosView(status: ts, myUid: viewModel.myUid, partnerUid: partnerUid, viewModel: viewModel)
                .environmentObject(appViewModel)
                .onDisappear { selectedStatus = nil }
        } else {
            // Fallback display in case data is missing
            VStack {
                Text("no_data_available")
                    .font(Typography.bodyMedium)
                Button("close") { showPhotos = false }
                    .padding()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.dsBackground)
        }
    }

    // Removed miniCalendarSection as it's now integrated into partnerRelationshipRow

    @State private var calendarPage = 1 // 1 is current week if 2 weeks total

    private func calendarDayCell(_ day: PairStatusViewModel.DayStatus) -> some View {
        let isFuture = day.date > Date()
        
        return VStack(spacing: 4) {
            Text(day.date.dayString)
                .font(Typography.extraSmall)
                .foregroundColor(day.isToday ? .dsForeground : .dsMuted)
                .padding(.bottom, 2)
            
            // Phase 289: Dual Horizontal Lamp Display (Targeted blue, Public green)
            VStack(spacing: 4) {
                // 1. Targeted Lamp (Blue)
                Capsule()
                    .fill(day.targetedDone && !isFuture ? Color.blue : Color.white.opacity(0.1))
                    .frame(width: 20, height: 6)
                    .shadow(color: day.targetedDone && !isFuture ? Color.blue.opacity(0.4) : Color.clear, radius: 4)
                
                // 2. Public Lamp (Green)
                Capsule()
                    .fill(day.publicDone && !isFuture ? Color.dsSuccess : Color.white.opacity(0.1))
                    .frame(width: 20, height: 6)
                    .shadow(color: day.publicDone && !isFuture ? Color.dsSuccess.opacity(0.4) : Color.clear, radius: 4)
            }
            .frame(height: 28)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(
            day.isToday ? Color.white.opacity(0.05) : Color.clear
        )
        .cornerRadius(Radius.sm)
    }
    
    private var partnerRelationshipRow: some View {
        AppCard(padding: Spacing.sm, backgroundColor: .black, borderColor: .black, showGlow: false) {
            VStack(spacing: Spacing.sm) {
                HStack(spacing: Spacing.sm) {
                    if let avatarPath = viewModel.partnerAvatarPath {
                        CloudImageView(path: avatarPath, showSpinner: false, version: viewModel.partnerAvatarUpdatedAt?.description)
                            .frame(width: 40, height: 40)
                            .clipShape(Circle())
                    } else {
                        Image(systemName: "person.circle.fill")
                            .font(.system(size: 40))
                            .foregroundColor(.dsMutedDeep)
                    }
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(viewModel.partnerName)
                            .font(Typography.bodyBold)
                            .foregroundColor(.white)
                            .lineLimit(1)
                        
                        if !viewModel.partnerHandle.isEmpty {
                            Text("@\(viewModel.partnerHandle)")
                                .font(Typography.extraSmall)
                                .foregroundColor(.dsMuted)
                        }
                    }
                    Spacer()
                    NavigationLink(destination: PairCalendarView(pairId: pairId, partnerName: viewModel.partnerName)) {
                        Image(systemName: "calendar")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(width: 32, height: 32)
                            .background(Color.white.opacity(0.1))
                            .clipShape(Circle())
                    }
                }
                
                // Phase 289/293: Simplified single week display (Removed paging history)
                let columns = Array(repeating: GridItem(.flexible(), spacing: 10), count: 7)
                if let week = viewModel.calendarWeeks.last {
                    LazyVGrid(columns: columns, alignment: .leading, spacing: 8) {
                        ForEach(week) { day in
                            calendarDayCell(day)
                        }
                    }
                    .padding(.horizontal, 4)
                    .frame(height: 64)
                    .padding(.top, 4)
                }
                
                // Legend and Counter
                HStack(spacing: Spacing.lg) {
                    HStack(spacing: 6) {
                        Capsule()
                            .fill(Color.blue)
                            .frame(width: 14, height: 5)
                        Text("限定: \(viewModel.targetedCount(for: 0))")
                            .font(Typography.extraSmall)
                            .foregroundColor(.white)
                    }
                    
                    HStack(spacing: 6) {
                        Capsule()
                            .fill(Color.dsSuccess)
                            .frame(width: 14, height: 5)
                        Text("公開: \(viewModel.publicCount(for: 0))")
                            .font(Typography.extraSmall)
                            .foregroundColor(.white)
                    }
                    
                    Spacer()
                }
                .padding(.horizontal, 8)
                .padding(.top, 4)
            }
        }
        .padding(.vertical, Spacing.xs)
    }


    private var todayAchievementCard: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            let partnerUid = pairId.components(separatedBy: "_").first(where: { $0 != viewModel.myUid }) ?? ""
            let ts = viewModel.currentTodayStatus
            let partnerStatus = ts?.statusByUid[partnerUid] ?? .init(windowDidCapture: false, windowThumbPath: nil)
            
            HStack {
                Spacer()
                photoBox(title: viewModel.partnerName, status: partnerStatus, isMe: false)
                    .frame(maxWidth: 480) // Phase 285: Increased from 360 to make photo larger
                Spacer()
            }
        }
        .padding(.vertical, Spacing.sm)
    }

    private func photoBox(title: String, status: TodayStatusModel.TodayUserStatus, isMe: Bool) -> some View {
        let hasPublic = status.windowDidCapture || status.windowPhotoUrl != nil
        let hasTargeted = status.targetedWindowDidCapture || status.targetedWindowPhotoUrl != nil
        
        return VStack(alignment: .center, spacing: Spacing.md) {
            // Phase 285: Added title back as requested
            Text(NSLocalizedString("nav_title_todays_photos", comment: "Today's Photos"))
                .font(Typography.bodyBold)
                .foregroundColor(.dsForeground)
            
            if hasPublic || hasTargeted {
                // Phase 285: Always show PhotoStackView with forceStack: true for testing purposes
                PhotoStackView(
                    date: Date(),
                    publicStatus: hasPublic ? (thumb: status.windowThumbPath, full: status.windowFullPath, photoUrl: status.windowPhotoUrl, moment: status.momentPath) : nil,
                    targetedStatus: hasTargeted ? (thumb: status.targetedWindowThumbPath, full: status.targetedWindowFullPath, photoUrl: status.targetedWindowPhotoUrl, moment: status.targetedMomentPath) : nil,
                    showBorder: true, // Phase 288: White border for Activity tab
                    onTap: { isPublic in
                        // Only open viewer if real data exists
                        if hasPublic || hasTargeted {
                            openPhotoViewer(for: status, dateId: Date().yyyyMMdd, isPublicPrefered: isPublic)
                        }
                    }
                )
            } else {
                // Phase 289: Placeholder when no photos yet
                TodayPhotoPlaceholder()
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func openPhotoViewer(for status: TodayStatusModel.TodayUserStatus, dateId: String, isPublicPrefered: Bool) {
        var records: [DayRecord] = []
        
        let targetedId = "\(dateId)_0_targeted"
        let publicId = "\(dateId)_1_public"

        if status.targetedWindowDidCapture || status.targetedWindowPhotoUrl != nil {
            var targetedRecord = DayRecord(id: targetedId)
            targetedRecord.windowPhotoUrl = status.targetedWindowPhotoUrl
            targetedRecord.windowThumbPath = status.targetedWindowThumbPath
            targetedRecord.windowFullPath = status.targetedWindowFullPath
            targetedRecord.momentPath = status.targetedMomentPath
            records.append(targetedRecord)
        }
        
        if status.windowDidCapture || status.windowPhotoUrl != nil {
            var publicRecord = DayRecord(id: publicId)
            publicRecord.windowPhotoUrl = status.windowPhotoUrl
            publicRecord.windowThumbPath = status.windowThumbPath
            publicRecord.windowFullPath = status.windowFullPath
            publicRecord.momentPath = status.momentPath
            records.append(publicRecord)
        }
        
        guard !records.isEmpty else { return }
        
        // Start with the preferred photo
        let startId = isPublicPrefered ? publicId : (status.targetedWindowDidCapture ? targetedId : publicId)
        self.viewerContext = PhotoViewerContext(id: startId, allEntries: records)
    }

}


// MARK: - Subviews (Photo Viewer)

struct TodayPhotosView: View {
    @EnvironmentObject var appViewModel: AppViewModel
    @Environment(\.dismiss) var dismiss
    let status: TodayStatusModel
    let myUid: String
    let partnerUid: String
    @ObservedObject var viewModel: PairStatusViewModel
    @State private var viewerContext: PhotoViewerContext? = nil
    
    var myStatus: TodayStatusModel.TodayUserStatus {
        status.statusByUid[myUid] ?? .init(windowDidCapture: false, windowThumbPath: nil)
    }
    var partnerStatus: TodayStatusModel.TodayUserStatus {
        status.statusByUid[partnerUid] ?? .init(windowDidCapture: false, windowThumbPath: nil)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Spacing.xl) {
                    HStack {
                        Spacer()
                        // Use unified stack display
                        let hPub = partnerStatus.windowDidCapture || partnerStatus.windowPhotoUrl != nil
                        let hTar = partnerStatus.targetedWindowDidCapture || partnerStatus.targetedWindowPhotoUrl != nil
                        
                        VStack(spacing: Spacing.md) {
                            // Phase 285: Added title back as requested
                            Text(NSLocalizedString("nav_title_todays_photos", comment: "Today's Photos"))
                                .font(Typography.bodyBold)
                                .foregroundColor(.dsForeground)

                                if hPub || hTar {
                                    PhotoStackView(
                                        date: Date(),
                                        publicStatus: hPub ? (thumb: partnerStatus.windowThumbPath, full: partnerStatus.windowFullPath, photoUrl: partnerStatus.windowPhotoUrl, moment: partnerStatus.momentPath) : nil,
                                        targetedStatus: hTar ? (thumb: partnerStatus.targetedWindowThumbPath, full: partnerStatus.targetedWindowFullPath, photoUrl: partnerStatus.targetedWindowPhotoUrl, moment: partnerStatus.targetedMomentPath) : nil,
                                        showBorder: true, // Phase 288: White border for Activity tab
                                        onTap: { isPublic in
                                            if hPub || hTar {
                                                openPhotoViewer(for: partnerStatus, dateId: Date().yyyyMMdd, isPublicPrefered: isPublic)
                                            }
                                        }
                                    )
                                } else {
                                    TodayPhotoPlaceholder()
                                }
                        }
                        .frame(maxWidth: 520) // Phase 285: Increased from 400 to make photo larger
                        Spacer()
                    }
                    
                    Text("today_shared_hint")
                        .font(Typography.extraSmall)
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .padding(.top, Spacing.md)
                }
                .padding(.horizontal, 16) // Phase 285: Reduced from xl to make photo larger
                .padding(.vertical, Spacing.xl)
            }
            .navigationTitle("nav_title_todays_photos")
            .navigationBarTitleDisplayMode(.inline)
            .background(Color.dsBackground)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { dismiss() }) {
                        Text("done")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(minWidth: 44, minHeight: 44, alignment: .trailing)
                            .contentShape(Rectangle())
                    }
                }
            }
            .fullScreenCover(item: $viewerContext) { context in
                PhotoDetailView(context: context, isPresented: Binding(
                    get: { self.viewerContext != nil },
                    set: { if !$0 { self.viewerContext = nil } }
                ), canDelete: false)
            }
        }
    }

    private func openPhotoViewer(for s: TodayStatusModel.TodayUserStatus, dateId: String, isPublicPrefered: Bool) {
        var records: [DayRecord] = []
        let targetedId = "\(dateId)_0_targeted"
        let publicId = "\(dateId)_1_public"

        if s.targetedWindowDidCapture || s.targetedWindowPhotoUrl != nil {
            var targetedRecord = DayRecord(id: targetedId)
            targetedRecord.windowPhotoUrl = s.targetedWindowPhotoUrl
            targetedRecord.windowThumbPath = s.targetedWindowThumbPath
            targetedRecord.windowFullPath = s.targetedWindowFullPath
            targetedRecord.momentPath = s.targetedMomentPath
            records.append(targetedRecord)
        }
        
        if s.windowDidCapture || s.windowPhotoUrl != nil {
            var publicRecord = DayRecord(id: publicId)
            publicRecord.windowPhotoUrl = s.windowPhotoUrl
            publicRecord.windowThumbPath = s.windowThumbPath
            publicRecord.windowFullPath = s.windowFullPath
            publicRecord.momentPath = s.momentPath
            records.append(publicRecord)
        }
        
        guard !records.isEmpty else { return }
        let startId = isPublicPrefered ? publicId : (s.targetedWindowDidCapture ? targetedId : publicId)
        self.viewerContext = PhotoViewerContext(id: startId, allEntries: records)
    }
    
}

// MARK: - Components

struct TodayPhotoPlaceholder: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: Radius.xl)
                .fill(Color.black.opacity(0.3))
                .overlay(
                    RoundedRectangle(cornerRadius: Radius.xl)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )
            VStack(spacing: Spacing.sm) {
                Image(systemName: "camera.shutter.button")
                    .font(.title3)
                    .foregroundColor(.dsMutedDeep)
                Text("no_entry")
                    .font(Typography.extraSmall)
                    .foregroundColor(.dsMutedDeep)
            }
        }
        .aspectRatio(0.75, contentMode: .fit)
    }
}

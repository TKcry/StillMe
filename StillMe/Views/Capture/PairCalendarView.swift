import SwiftUI

struct PairCalendarView: View {
    @StateObject private var calendarViewModel: PairCalendarViewModel
    @EnvironmentObject var appViewModel: AppViewModel
    @Environment(\.dismiss) var dismiss
    
    @State private var viewerContext: PhotoViewerContext? = nil
    
    // Unified calendar configuration (Sunday start, JST)
    private let calendar: Calendar = {
        var cal = Calendar(identifier: .gregorian)
        cal.locale = Locale(identifier: "en_US_POSIX")
        cal.timeZone = TimeZone(secondsFromGMT: 9 * 3600)! 
        cal.firstWeekday = 1 // Sunday
        return cal
    }()
    
    let daysOfWeek = ["S", "M", "T", "W", "T", "F", "S"]
    let partnerName: String

    init(pairId: String, partnerName: String) {
        _calendarViewModel = StateObject(wrappedValue: PairCalendarViewModel(pairId: pairId))
        self.partnerName = partnerName
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Day Headers
            HStack(spacing: 0) {
                ForEach(0..<daysOfWeek.count, id: \.self) { index in
                    Text(daysOfWeek[index])
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.dsMuted)
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 16)
            .background(Color.dsBackground)
            
            Divider().background(Color.white.opacity(0.05))
            
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 40) {
                        // Display months from the start of the pair (createdAt) to now
                        ForEach(monthOffsets, id: \.self) { offset in
                            if let month = getMonth(for: offset) {
                                VStack(alignment: .leading, spacing: 12) {
                                    Text(DateFormatter.monthTitleJST.string(from: month))
                                        .font(Typography.bodyBold)
                                        .foregroundColor(.dsForeground.opacity(0.9))
                                        .padding(.horizontal, 16)
                                    
                                    PairMonthGridView(
                                        month: month,
                                        calendar: calendar,
                                        viewModel: calendarViewModel,
                                        onSelect: { date in
                                            openPhotoViewer(at: date)
                                        }
                                    )
                                    .padding(.horizontal, 16)
                                }
                                .id(month)
                            }
                        }
                    }
                    .padding(.top, 20)
                    .padding(.bottom, 100)
                }
                .onAppear {
                    // Scroll to current month on open
                    if let currentMonth = getMonth(for: 0) {
                        proxy.scrollTo(currentMonth, anchor: .top)
                    }
                }
            }
        }
        .navigationTitle("\(partnerName)の活動")
        .navigationBarTitleDisplayMode(.inline)
        .background(Color.dsBackground.ignoresSafeArea())
        .fullScreenCover(item: $viewerContext) { context in
            PhotoDetailView(context: context, isPresented: Binding(
                get: { self.viewerContext != nil },
                set: { if !$0 { self.viewerContext = nil } }
            ), canDelete: false)
            // PhotoDetailView internally uses EnvironmentObject appViewModel
        }
    }
    
    private func getMonth(for offset: Int) -> Date? {
        let now = Date()
        var comps = calendar.dateComponents([.year, .month], from: now)
        comps.day = 1
        guard let startOfThisMonth = calendar.date(from: comps) else { return nil }
        return calendar.date(byAdding: .month, value: offset, to: startOfThisMonth)
    }
    
    /// Phase 298: Dynamic monthly range based on pair history
    private var monthOffsets: [Int] {
        let now = Date()
        let start = calendarViewModel.startMonth ?? now
        let components = calendar.dateComponents([.month], from: start.startOfMonth(using: calendar), to: now.startOfMonth(using: calendar))
        let diff = components.month ?? 0
        return Array((-diff)...0)
    }
    
    private func openPhotoViewer(at date: Date) {
        let dateId = date.yyyyMMdd
        // Pass the partner-specific day records to the viewer
        self.viewerContext = PhotoViewerContext(id: dateId, allEntries: calendarViewModel.sortedEntries)
    }
}

private struct PairMonthGridView: View {
    let month: Date
    let calendar: Calendar
    @ObservedObject var viewModel: PairCalendarViewModel
    let onSelect: (Date) -> Void
    
    var body: some View {
        let firstDayOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: month))!
        let dayOfWeek = calendar.component(.weekday, from: firstDayOfMonth) 
        let leading = dayOfWeek - 1
        let startDate = calendar.date(byAdding: .day, value: -leading, to: firstDayOfMonth)!
        
        let gridSpacing: CGFloat = 1
        
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: gridSpacing), count: 7), spacing: gridSpacing) {
            ForEach(0..<42, id: \.self) { idx in
                if let cellDate = calendar.date(byAdding: .day, value: idx, to: startDate) {
                    let isCurrentMonth = calendar.isDate(cellDate, equalTo: firstDayOfMonth, toGranularity: .month)
                    let dayNum = calendar.component(.day, from: cellDate)
                    let entry = viewModel.entry(on: cellDate)
                    let hPublic = isCurrentMonth && (entry?.hasWindow ?? false)
                    let hTargeted = isCurrentMonth && (entry?.hasTargetedWindow ?? false)
                    
                    PairCalendarDayCell(
                        day: dayNum,
                        hasPublic: hPublic,
                        hasTargeted: hTargeted,
                        publicPath: hPublic ? entry?.windowThumbPath ?? entry?.windowPhotoUrl : nil,
                        targetedPath: hTargeted ? entry?.targetedWindowThumbPath ?? entry?.targetedWindowPhotoUrl : nil,
                        isToday: calendar.isDateInToday(cellDate),
                        isCurrentMonth: isCurrentMonth
                    ) {
                        if isCurrentMonth && (hPublic || hTargeted) {
                            onSelect(cellDate)
                        }
                    }
                }
            }
        }
    }
}

private struct PairCalendarDayCell: View {
    @EnvironmentObject var appViewModel: AppViewModel
    let day: Int
    let hasPublic: Bool
    let hasTargeted: Bool
    let publicPath: String?
    let targetedPath: String?
    let isToday: Bool
    let isCurrentMonth: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                Rectangle()
                    .fill(isCurrentMonth ? Color.dsCard : Color.clear)
                    .overlay(
                        Rectangle()
                            .stroke(Color.white.opacity(1.0), lineWidth: (isToday && isCurrentMonth && !(hasPublic || hasTargeted)) ? 3 : 0)
                    )

                if isCurrentMonth {
                    if hasPublic && hasTargeted {
                        // Stack Effect (Phase 280/294: Enhanced overlap)
                        ZStack {
                            // Secondary (Public) in background
                            if let p = publicPath {
                                CloudImageView(path: p, contentMode: .fill)
                                    .scaleEffect(0.9)
                                    .rotationEffect(.degrees(-6))
                                    .offset(x: -6, y: -4)
                                    .opacity(0.5)
                            }
                            
                            // Primary (Targeted) in foreground
                            if let t = targetedPath {
                                CloudImageView(path: t, contentMode: .fill)
                                    .overlay(Color.black.opacity(0.05))
                                    .shadow(color: .black.opacity(0.3), radius: 4, x: 2, y: 2)
                            }
                        }
                        .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity)
                        .clipped()
                    } else if let path = targetedPath ?? publicPath {
                        CloudImageView(path: path, contentMode: .fill)
                            .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity)
                            .clipped()
                    }

                    Text("\(day)")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor((hasPublic || hasTargeted) ? .white : (isToday ? Color.white.opacity(1.0) : .dsMuted))
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                        .padding(4)
                        .background(
                            Group {
                                if hasPublic || hasTargeted {
                                    Color.black.opacity(0.3)
                                        .blur(radius: 6)
                                }
                            }
                        )
                    
                    // Phase 289: Dual Horizontal Lamp Display in Full Calendar
                    VStack(spacing: 2) {
                        Capsule()
                            .fill(hasTargeted ? Color.blue : Color.white.opacity(0.1))
                            .frame(width: 12, height: 4)
                            .shadow(color: hasTargeted ? Color.blue.opacity(0.4) : Color.clear, radius: 2)
                        
                        Capsule()
                            .fill(hasPublic ? Color.dsSuccess : Color.white.opacity(0.1))
                            .frame(width: 12, height: 4)
                            .shadow(color: hasPublic ? Color.dsSuccess.opacity(0.4) : Color.clear, radius: 2)
                    }
                    .padding(4)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)

                    // Phase 295: 2-Photo Badge (❷)
                    if hasPublic && hasTargeted {
                        Text("❷")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(Color(hex: "CCFF00")) // Neon Lime
                            .padding(4)
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                    }
                }
            }
            .aspectRatio(0.75, contentMode: .fill)
        }
        .buttonStyle(.plain)
        .disabled(!isCurrentMonth) // Phase 289: Allow tapping even without photo if current month
    }
}

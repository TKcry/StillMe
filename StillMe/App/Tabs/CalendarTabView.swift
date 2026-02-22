import SwiftUI

struct CalendarTabView: View {
    @EnvironmentObject var viewModel: AppViewModel
    // @State private var selectedDate: Date? = nil // Removed (Phase 224)
    @State private var currentMonth: Date
    
    // For preview display
    @State private var viewerContext: PhotoViewerContext? = nil
    
    // Unified calendar configuration (Sunday start, JST, POSIX)
    private let calendar: Calendar = {
        var cal = Calendar(identifier: .gregorian)
        cal.locale = Locale(identifier: "en_US_POSIX")
        cal.timeZone = TimeZone(secondsFromGMT: 9 * 3600)! 
        cal.firstWeekday = 1 // Sunday
        return cal
    }()
    
    let daysOfWeek = ["S", "M", "T", "W", "T", "F", "S"]

    init() {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(secondsFromGMT: 9 * 3600)!
        cal.firstWeekday = 1 // Ensure consistency
        let now = Date()
        let comps = cal.dateComponents([.year, .month], from: now)
        let start = cal.date(from: comps) ?? now
        _currentMonth = State(initialValue: start)
    }
    
    var body: some View {
        VStack(spacing: 0) {
                // Day Headers (S M T W T F S)
                HStack(spacing: 0) {
                    ForEach(0..<daysOfWeek.count, id: \.self) { index in
                        Text(daysOfWeek[index])
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.dsMuted)
                            .frame(maxWidth: .infinity)
                    }
                }
                .padding(.vertical, 8)
                .padding(.horizontal, 16) // Consistent horizontal padding
                .background(Color.dsBackground)
                Divider().background(Color.white.opacity(0.05))
                
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 40) {
                            ForEach(monthOffsets, id: \.self) { offset in
                                if let month = getMonth(for: offset) {
                                    VStack(alignment: .leading, spacing: 12) {
                                        // Specific month title for vertical scroll
                                        Text(DateFormatter.monthTitleJST.string(from: month))
                                            .font(Typography.bodyBold)
                                            .foregroundColor(.dsForeground.opacity(0.9))
                                            .padding(.horizontal, 16) // Match header
                                        
                                        MonthGridView(
                                            month: month,
                                            onSelect: { date in
                                                openPhotoViewer(at: date)
                                            },
                                            calendar: calendar
                                        )
                                        .padding(.horizontal, 16) // Match header
                                    }
                                    .id(month)
                                }
                            }
                        }
                        .padding(.top, 20)
                        .padding(.bottom, 150)
                    }
                    .onChange(of: scrollTargetMonth) { _, newVal in
                        if let target = newVal {
                            withAnimation { proxy.scrollTo(target, anchor: .top) }
                        }
                    }
                }
            }
            .background(Color.dsBackground)
            // .toolbar(.hidden, for: .navigationBar) // Navigation will be handled by parent
            .fullScreenCover(item: $viewerContext) { context in
                PhotoDetailView(context: context, isPresented: Binding(
                    get: { self.viewerContext != nil },
                    set: { if !$0 { self.viewerContext = nil } }
                ))
            }
            .onAppear {
                if scrollTargetMonth == nil {
                    // Set to current month by default (offset 0)
                    scrollTargetMonth = getMonth(for: 0)
                }
            }
    }
    
    private func getMonth(for offset: Int) -> Date? {
        let now = Date()
        var comps = calendar.dateComponents([.year, .month], from: now)
        comps.day = 1
        guard let startOfThisMonth = calendar.date(from: comps) else { return nil }
        return calendar.date(byAdding: .month, value: offset, to: startOfThisMonth)
    }

    /// Phase 298: Dynamic monthly range based on usage history
    private var monthOffsets: [Int] {
        let now = Date()
        guard let firstDate = DateFormatter.yyyyMMdd.date(from: viewModel.firstRecordDate) else { return [0] }
        
        let components = calendar.dateComponents([.month], from: firstDate.startOfMonth(using: calendar), to: now.startOfMonth(using: calendar))
        let diff = components.month ?? 0
        
        // Show from first record month to current month
        return Array((-diff)...0)
    }

    
    @State private var scrollTargetMonth: Date? = nil
    
    private func changeMonthAction(offset: Int) {
        if let newMonth = calendar.date(byAdding: .month, value: offset, to: currentMonth) {
            scrollTargetMonth = newMonth
        }
    }
    
    private func openPhotoViewer(at date: Date) {
        self.viewerContext = PhotoViewerContext(id: date.yyyyMMdd, allEntries: viewModel.sortedEntries)
    }
}

struct CalendarDayCell: View {
    @EnvironmentObject var viewModel: AppViewModel
    let day: Int
    let hasPhoto: Bool
    let imagePath: String?
    let isToday: Bool
    let isCurrentMonth: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                // Background Color
                Rectangle()
                    .fill(isCurrentMonth ? Color.dsCard : Color.clear)
                    .overlay(
                        Rectangle()
                            .stroke(Color.white.opacity(1.0), lineWidth: (isToday && isCurrentMonth && !hasPhoto) ? 3 : 0)
                    )

                if isCurrentMonth {
                    // Thumbnail
                    if hasPhoto, let path = imagePath {
                        if let image = viewModel.loadImage(path: path) {
                            Image(uiImage: image)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity)
                                .clipped()
                        } else {
                            // Phase 255: Fallback to Cloud Storage for restored records
                            CloudImageView(path: path, contentMode: .fill)
                                .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity)
                                .clipped()
                        }
                    }

                    // Day text overlay
                    Text("\(day)")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(hasPhoto ? .white : (isToday ? Color.white.opacity(1.0) : .dsMuted))
                        .frame(maxWidth: .infinity, maxHeight: .infinity) // Fill and center by default
                        .background(
                            Group {
                                if hasPhoto {
                                    Color.black.opacity(0.2)
                                        .blur(radius: 8)
                                }
                            }
                        )
                }
            }
            .aspectRatio(0.75, contentMode: .fill) // Constant 3:4 ratio
        }
        .buttonStyle(.plain)
        .disabled(!isCurrentMonth || !hasPhoto)
    }
}



struct MonthGridView: View {
    @EnvironmentObject var viewModel: AppViewModel
    let month: Date
    let onSelect: (Date) -> Void
    let calendar: Calendar // Passed from parent for perfect sync
    
    var body: some View {
        let firstDayOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: month))!
        let dayOfWeek = calendar.component(.weekday, from: firstDayOfMonth) // 1=Sun, 2=Mon...7=Sat
        
        // Explicitly calculate leading spaces for Sunday-start (1=Sun -> 0, 2=Mon -> 1, ...)
        let leading = dayOfWeek - 1
        let startDate = calendar.date(byAdding: .day, value: -leading, to: firstDayOfMonth)!
        
        let gridSpacing: CGFloat = 1
        
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: gridSpacing), count: 7), spacing: gridSpacing) {
                ForEach(0..<42, id: \.self) { idx in
                    if let cellDate = calendar.date(byAdding: .day, value: idx, to: startDate) {
                        let isCurrentMonth = calendar.isDate(cellDate, equalTo: firstDayOfMonth, toGranularity: .month)
                        let dayNum = calendar.component(.day, from: cellDate)
                        let entry = viewModel.entry(on: cellDate)
                        
                        CalendarDayCell(
                            day: dayNum,
                            hasPhoto: isCurrentMonth && (entry?.hasWindow ?? false),
                            imagePath: isCurrentMonth ? entry?.windowImagePath : nil,
                            isToday: calendar.isDateInToday(cellDate),
                            isCurrentMonth: isCurrentMonth
                        ) {
                            if isCurrentMonth && (entry?.hasWindow ?? false) {
                                onSelect(cellDate)
                            }
                        }
                    }
                }
        }
        .frame(maxWidth: .infinity)
    }
}


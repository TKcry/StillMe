import SwiftUI

struct HomeTabView: View {
    @EnvironmentObject var viewModel: AppViewModel
    @State private var showingRatingReview = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.dsBackground.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: Spacing.xl) {
                        // 1. Review Banner (Nudge)
                        // 1. Review Banner (Nudge) (Hidden)
                        /*
                        if viewModel.unratedCount > 0 {
                            ReviewNudgeSection(count: viewModel.unratedCount) {
                                showingRatingReview = true
                            }
                        }
                        */
                        
                        // 2. Main Stats (Streak & Photo Count)
                        HStack(spacing: Spacing.md) {
                            StatCard(
                                title: NSLocalizedString("streak_title", comment: ""),
                                value: "\(viewModel.currentStreak)",
                                unit: NSLocalizedString("progress_days_label", comment: ""),
                                icon: "flame.fill",
                                color: .orange
                            )
                            
                            StatCard(
                                title: NSLocalizedString("progress_total_photos", comment: "Total Photos"),
                                value: "\(viewModel.totalPhotos)",
                                unit: NSLocalizedString("progress_photos_label", comment: "Photos"),
                                icon: "photo.stack.fill",
                                color: .dsAccent
                            )
                        }
                        
                        // 3. Pair Function (Middle) (Removed)
                        
                        // 4. Visualization (Bottom)
                        // Monthly Heatmap
                        MonthlyHeatmapCard()
                        
                        Spacer(minLength: 100)
                    }
                    .padding(.horizontal, Spacing.lg)
                    .padding(.top, Spacing.md)
                    .frame(maxWidth: 600) // Phase 257: Limit content width on iPad
                    .frame(maxWidth: .infinity) // Center the bounded content
                }
            }
            .navigationTitle(NSLocalizedString("progress_tab_title", comment: ""))
            .navigationBarTitleDisplayMode(.inline)
            /*
            .sheet(isPresented: $showingRatingReview) {
                RatingReviewView()
                    .environmentObject(viewModel)
            }
            */
        }
    }
}

// MARK: - Components



private struct MonthlyHeatmapCard: View {
    @EnvironmentObject var viewModel: AppViewModel
    
    // Calendar math
    private let calendar = Calendar.current
    private let today = Date()
    private var days: [Date] {
        guard let range = calendar.range(of: .day, in: .month, for: today),
              let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: today)) else {
            return []
        }
        return range.compactMap { day -> Date? in
            calendar.date(byAdding: .day, value: day - 1, to: startOfMonth)
        }
    }
    
    var body: some View {
        PhysicsAppCard(padding: Spacing.lg) {
            VStack(alignment: .leading, spacing: Spacing.md) {
                Text(today.formatted(.dateTime.month(.wide).year()))
                    .font(Typography.bodyBold)
                    .foregroundColor(.dsForeground)
                
                // Weekday Headers
                HStack(spacing: 0) {
                    let weekdays = ["S", "M", "T", "W", "T", "F", "S"]
                    ForEach(0..<weekdays.count, id: \.self) { index in
                        Text(weekdays[index])
                            .font(Typography.extraSmall)
                            .foregroundColor(.dsMuted)
                            .frame(maxWidth: .infinity)
                    }
                }
                
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 8) {
                    // Leading padding (blanks)
                    if let first = days.first {
                        let weekday = calendar.component(.weekday, from: first) // 1=Sun, 2=Mon...
                         // For Sunday start, padding is weekday - 1
                        ForEach(0..<(weekday - 1), id: \.self) { _ in
                             Color.clear
                        }
                    }
                    
                    ForEach(days, id: \.self) { date in
                        HeatmapCell(date: date, entry: viewModel.entry(on: date))
                    }
                }
                
                // Legend
                HStack(spacing: 12) {
                    LegendItem(color: .dsSuccess, label: NSLocalizedString("legend_captured", comment: ""))
                    LegendItem(color: .dsMuted, label: NSLocalizedString("legend_missed", comment: ""))
                }
                .padding(.top, 8)
            }
        }
    }
    
    private struct LegendItem: View {
        let color: Color
        let label: String
        
        var body: some View {
            HStack(spacing: 4) {
                Circle()
                    .fill(color)
                    .frame(width: 8, height: 8)
                Text(label)
                    .font(Typography.caption)
                    .foregroundColor(.white)
            }
        }
    }
    
    private struct HeatmapCell: View {
        let date: Date
        let entry: DayRecord?
        
        var body: some View {
            let isCaptured = entry?.hasWindow ?? false
            let isToday = Calendar.current.isDateInToday(date)
            let color: Color = {
                if !isCaptured { return .dsMuted.opacity(0.3) }
                return .dsSuccess
            }()
            
            VStack {
                 Circle()
                    .fill(color)
                    .frame(width: 24, height: 24) // Small dot
                    .overlay(
                        Text("\(Calendar.current.component(.day, from: date))")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(isToday ? .white : (isCaptured ? .black.opacity(0.7) : .white.opacity(0.3)))
                    )
            }
        }
    }
}

// Reuse existing components where possible or redefine locally if simple

private struct StatCard: View {
    let title: String
    let value: String
    let unit: String
    let icon: String
    let color: Color
    
    var body: some View {
        AppCard(padding: Spacing.lg) {
            VStack(alignment: .leading, spacing: Spacing.md) {
                HStack {
                    Image(systemName: icon)
                        .font(.system(size: 14))
                        .foregroundColor(color)
                    Text(title)
                        .font(Typography.extraSmall)
                        .foregroundColor(.white)
                }
                
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(value)
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                    Text(unit)
                        .font(Typography.caption)
                        .foregroundColor(.white)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

private struct ReviewNudgeSection: View {
    let count: Int
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(String(format: NSLocalizedString("progress_review_unrated_format", comment: ""), count))
                        .font(Typography.bodyBold)
                        .foregroundColor(.dsForeground)
                    Text("progress_all_caught_up") // Fallback / placeholder for subtext
                        .font(Typography.extraSmall)
                        .foregroundColor(.white)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white)
            }
            .padding(Spacing.lg)
            .background(
                RoundedRectangle(cornerRadius: Radius.lg)
                    .fill(Color.orange.opacity(0.15))
            )
            .overlay(
                RoundedRectangle(cornerRadius: Radius.lg)
                    .stroke(Color.orange.opacity(0.3), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

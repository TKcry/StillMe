import SwiftUI

struct RatingReviewView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var viewModel: AppViewModel
    
    // Initialize unrated entries (rating == -1) sorted from oldest to newest
    @State private var unratedEntries: [DayRecord] = []
    @State private var currentIndex: Int = 0
    @State private var historyStack: [String] = [] // Stack of rated date IDs (for Undo)
    
    var body: some View {
        VStack(spacing: 0) {
            if !unratedEntries.isEmpty && currentIndex < unratedEntries.count {
                // Header (Only shown during active review)
                HStack {
                    Button(action: handleBack) {
                        Image(systemName: "arrow.uturn.left")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.dsForeground.opacity(0.8))
                            .frame(width: 44, height: 44)
                            .contentShape(Rectangle())
                    }
                    
                    Spacer()
                    
                    if let currentEntry = currentEntry, let date = DateFormatter.yyyyMMdd.date(from: currentEntry.id) {
                        Text(date.formatted(.dateTime.year().month().day()))
                            .font(Typography.small)
                            .foregroundColor(.dsMuted)
                    }
                    
                    Spacer()
                    
                    Button {
                        dismiss()
                    } label: {
                        Text("done_label")
                            .font(Typography.bodyMedium)
                            .foregroundColor(.dsSuccess)
                            .padding(.horizontal, Spacing.sm)
                            .frame(height: 44)
                    }
                }
                .padding(.horizontal, Spacing.lg)
                .padding(.top, Spacing.md)
            }
            
            if unratedEntries.isEmpty {
                emptyState
            } else if currentIndex < unratedEntries.count {
                reviewContent(entry: unratedEntries[currentIndex])
            } else {
                completionState
            }
        }
        .background(Color.dsBackground.ignoresSafeArea())
        .onAppear(perform: loadUnrated)
    }
    
    private var currentEntry: DayRecord? {
        guard currentIndex < unratedEntries.count else { return nil }
        return unratedEntries[currentIndex]
    }
    
    private func loadUnrated() {
        // Sort from oldest to newest and filter for unrated entries only
        self.unratedEntries = viewModel.sortedEntriesAsc.filter { $0.hasWindow && $0.rating == -1 }
        self.currentIndex = 0
        self.historyStack = []
    }
    
    private func handleBack() {
        if let lastDateId = historyStack.popLast() {
            // Revert the previous rating to unrated (-1)
            viewModel.updateRating(dateId: lastDateId, rating: -1)
            // Move index back by one. If already at completion, currentIndex is count, so adjustment is needed.
            // Since history exists, at least one photo has been rated, so currentIndex > 0.
            if currentIndex > 0 {
                currentIndex -= 1
            }
            // unratedEntries itself will be updated to rating=-1 (locally) via updateRating, 
            // but this view uses the initial unratedEntries array, so we can navigate back just by index.
        } else {
            dismiss()
        }
    }
    private func submitRating(_ rating: Int) {
        guard let entry = currentEntry else { return }
        
        // Push to history
        historyStack.append(entry.id)
        
        // Update data
        viewModel.updateRating(dateId: entry.id, rating: rating)
        
        // Next entry
        withAnimation(.easeInOut(duration: 0.2)) {
            currentIndex += 1
        }
    }
    
    @ViewBuilder
    private func reviewContent(entry: DayRecord) -> some View {
        VStack(spacing: Spacing.xxxl) {
            Spacer()
            
            // Photo
            ZStack {
                if let path = entry.windowImagePath, let image = viewModel.loadImage(path: path) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: .infinity)
                        .clipShape(RoundedRectangle(cornerRadius: Radius.xl))
                } else {
                    AppCard {
                        Text("no_image_available")
                            .foregroundColor(.dsMuted)
                    }
                }
            }
            .padding(.horizontal, Spacing.xxl)
            
            Spacer()
            
            // Quiet Block-style Rating UI
            HStack(spacing: Spacing.md) {
                ratingButton(rating: 0, icon: "hand.thumbsdown.fill", color: .red)
                ratingButton(rating: 1, icon: "equal", color: .gray)
                ratingButton(rating: 2, icon: "hand.thumbsup.fill", color: Color.dsSuccess)
            }
            .padding(.horizontal, Spacing.lg)
            .padding(.bottom, 40)
        }
    }
    
    @ViewBuilder
    private func ratingButton(rating: Int, icon: String, color: Color) -> some View {
        let isNeutral = (rating == 1)
        
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            submitRating(rating)
        } label: {
            ZStack {
                Image(systemName: icon)
                    .font(.system(size: 24, weight: .semibold))
            }
            .foregroundColor(color.opacity(0.6))
            .frame(maxWidth: .infinity)
            .frame(height: 72)
            .background(
                Group {
                    if isNeutral {
                        RoundedRectangle(cornerRadius: Radius.lg)
                            .stroke(color.opacity(0.2), lineWidth: 1.5)
                            .background(RoundedRectangle(cornerRadius: Radius.lg).fill(Color.white.opacity(0.001)))
                    } else {
                        RoundedRectangle(cornerRadius: Radius.lg)
                            .fill(color.opacity(0.12))
                    }
                }
            )
            .contentShape(RoundedRectangle(cornerRadius: Radius.lg))
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private var emptyState: some View {
        VStack(spacing: Spacing.lg) {
            Spacer()
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 60))
                .foregroundColor(Color.dsSuccess.opacity(0.6))
            Text("no_unrated_photos")
                .font(Typography.bodyMedium)
                .foregroundColor(.dsForeground.opacity(0.8))
            
            AppButton(NSLocalizedString("close_label", comment: "")) {
                dismiss()
            }
            .frame(width: 160)
            .padding(.top, Spacing.xl)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var completionState: some View {
        VStack(spacing: Spacing.lg) {
            Spacer()
            Image(systemName: "sparkles")
                .font(.system(size: 60))
                .foregroundColor(.orange.opacity(0.6))
            Text("all_ratings_complete")
                .font(Typography.bodyMedium)
                .foregroundColor(.dsForeground.opacity(0.8))
            
            AppButton(NSLocalizedString("close_label", comment: "")) {
                dismiss()
            }
            .frame(width: 160)
            .padding(.top, Spacing.xl)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

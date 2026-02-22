import SwiftUI

struct PhotoStackView: View {
    @EnvironmentObject var appViewModel: AppViewModel
    let date: Date
    let publicStatus: (thumb: String?, full: String?, photoUrl: String?, moment: String?)?
    let targetedStatus: (thumb: String?, full: String?, photoUrl: String?, moment: String?)?
    let showBorder: Bool // Phase 288: Control border visibility from outside
    let onTap: (Bool) -> Void // isPublic
    
    @State private var selection = 0 // 0: Targeted front, 1: Public front
    @State private var dragOffset: CGFloat = 0
    @State private var isSwapping = false
    
    init(
        date: Date,
        publicStatus: (thumb: String?, full: String?, photoUrl: String?, moment: String?)?,
        targetedStatus: (thumb: String?, full: String?, photoUrl: String?, moment: String?)?,
        showBorder: Bool = false, // Default to false
        onTap: @escaping (Bool) -> Void
    ) {
        self.date = date
        self.publicStatus = publicStatus
        self.targetedStatus = targetedStatus
        self.showBorder = showBorder
        self.onTap = onTap
    }
    
    var body: some View {
        let hasPublic = publicStatus != nil
        let hasTargeted = targetedStatus != nil
        
        ZStack {
            if hasPublic && hasTargeted {
                // Stack of 2
                let frontIsPublic = selection == 1
                let frontData = frontIsPublic ? publicStatus! : targetedStatus!
                let backData = frontIsPublic ? targetedStatus! : publicStatus!
                
                ZStack {
                    // 1. The Back Card (Sync rotation with swipe)
                    let progress = min(abs(dragOffset) / 200.0, 1.0) // Phase 288: Calculate swap progress
                    let backRotation = 3.0 * (1.0 - progress)
                    let backOffsetX = 6.0 * (1.0 - progress)
                    let backOffsetY = -4.0 * (1.0 - progress)
                    
                    cardView(status: backData, isPublic: !frontIsPublic)
                        .scaleEffect(0.96)
                        .rotationEffect(.degrees(backRotation))
                        .offset(x: backOffsetX, y: backOffsetY)
                        .opacity(0.9 + (0.1 * progress)) // Subtle opacity gain
                    
                    // 2. The Front Card (Active)
                    cardView(status: frontData, isPublic: frontIsPublic)
                        .offset(x: dragOffset, y: -abs(dragOffset) / 40.0)
                        .rotationEffect(.degrees(Double(dragOffset) / 20.0))
                        .shadow(color: Color.black.opacity(0.4), radius: 15, x: 0, y: 10)
                        .highPriorityGesture(
                            DragGesture(minimumDistance: 5)
                                .onChanged { value in
                                    isSwapping = false
                                    withAnimation(.interactiveSpring(response: 0.25, dampingFraction: 0.85)) {
                                        dragOffset = value.translation.width
                                    }
                                }
                                .onEnded { value in
                                    let threshold: CGFloat = 65 // Threshold for intentional swap
                                    if abs(value.translation.width) > threshold {
                                        swapCards(toRight: value.translation.width > 0)
                                    } else {
                                        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                                            dragOffset = 0
                                        }
                                    }
                                }
                        )
                }
                .aspectRatio(0.75, contentMode: .fit)
            } else if let status = targetedStatus ?? publicStatus {
                // Single Card
                cardView(status: status, isPublic: targetedStatus == nil)
                    .aspectRatio(0.75, contentMode: .fit)
                    .shadow(color: Color.black.opacity(0.4), radius: 10, x: 0, y: 5)
            }
        }
    }
    
    private func swapCards(toRight: Bool) {
        isSwapping = true
        // Phase 288: Simple throw animation
        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
            dragOffset = toRight ? 800 : -800
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            selection = (selection == 0) ? 1 : 0
            
            // Instantly reset position (hidden behind back card which is now front)
            var transaction = Transaction()
            transaction.disablesAnimations = true
            withTransaction(transaction) {
                dragOffset = 0
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                isSwapping = false
            }
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        }
    }
    
    private func cardView(status: (thumb: String?, full: String?, photoUrl: String?, moment: String?), isPublic: Bool) -> some View {
        AppCard(padding: 0, cornerRadius: Radius.container) {
            ZStack(alignment: .bottomTrailing) {
                MomentPressPlayer(
                    date: date,
                    image: nil,
                    cloudImagePath: status.thumb ?? status.photoUrl,
                    momentPath: status.moment,
                    cornerRadius: Radius.container,
                    exportState: appViewModel.exportState
                )
                
                // Badge
                Text(isPublic ? NSLocalizedString("privacy_mode_public", comment: "Public") : NSLocalizedString("partner_label_targeted", comment: "Friend Only"))
                    .font(.system(size: 10, weight: .bold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(
                        Capsule()
                            .fill(isPublic ? Color.dsChart2.opacity(0.9) : Color.dsAccent.opacity(0.9))
                            .overlay(Capsule().stroke(Color.white.opacity(0.3), lineWidth: 1))
                    )
                    .foregroundColor(.white)
                    .padding(14)
            }
            .onTapGesture {
                onTap(isPublic)
            }
        }
        .overlay(
            // Phase 288: Optional thin white border for specific contexts (e.g., Activity tab)
            Group {
                if showBorder {
                    RoundedRectangle(cornerRadius: Radius.container)
                        .stroke(Color.white.opacity(0.8), lineWidth: 1.2)
                }
            }
        )
        .id(isPublic) // Phase 288: Force view identity change to trigger fresh updates
    }
}

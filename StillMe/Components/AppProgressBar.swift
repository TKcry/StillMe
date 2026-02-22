import SwiftUI

struct AppCircularProgress: View {
    let totalCount: Int
    let size: CGFloat
    let strokeWidth: CGFloat
    
    private let lapSize = 365
    
    // Lap Colors: White -> Green -> Blue -> Purple -> Orange -> Red -> Gold
    private let lapColors: [Color] = [
        .white,
        Color(hex: "34C759"), // Green
        Color(hex: "007AFF"), // Blue
        Color(hex: "AF52DE"), // Purple
        Color(hex: "FF9500"), // Orange
        Color(hex: "FF3B30"), // Red
        Color(hex: "FFD700")  // Gold
    ]
    
    private var lapInfo: (lap: Int, progress: Double) {
        let lap = totalCount / lapSize
        let progress = Double(totalCount % lapSize) / Double(lapSize)
        return (lap, progress)
    }
    
    private var currentColor: Color {
        let index = min(lapInfo.lap, lapColors.count - 1)
        return lapColors[index]
    }
    
    private var previousColor: Color {
        if lapInfo.lap == 0 { return .white }
        let index = min(lapInfo.lap - 1, lapColors.count - 1)
        return lapColors[index]
    }
    
    var body: some View {
        ZStack {
            // Background Circle (Previous Lap Color or default gray)
            Circle()
                .stroke(previousColor.opacity(0.1), lineWidth: strokeWidth)
            
            // Progress Circle (Current Lap)
            Circle()
                .trim(from: 0, to: CGFloat(lapInfo.progress))
                .stroke(
                    currentColor.opacity(0.9),
                    style: StrokeStyle(lineWidth: strokeWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(Motion.slow, value: lapInfo.progress)
        }
        .frame(width: size, height: size)
    }
}

struct AppProgressBar: View {
    let progress: Double // 0.0 to 1.0
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: Radius.sm)
                    .fill(Color.white.opacity(0.2))
                    .frame(height: 2)
                
                RoundedRectangle(cornerRadius: Radius.sm)
                    .fill(Color.dsPrimary)
                    .frame(width: geometry.size.width * CGFloat(progress), height: 2)
            }
        }
        .frame(height: 2)
    }
}

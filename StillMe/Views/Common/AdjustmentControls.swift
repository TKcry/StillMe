import SwiftUI

struct VerticalHeightSlider: View {
    @Binding var value: CGFloat // Normalized 0...1
    
    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .bottom) {
                // Track
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.white.opacity(0.1))
                    .frame(width: 8)
                
                // Active Track
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.blue.opacity(0.5))
                    .frame(width: 8, height: geo.size.height * (1.0 - value))
                
                // Thumb
                ZStack {
                    Circle()
                        .fill(Color.white)
                        .frame(width: 28, height: 28)
                        .shadow(radius: 4)
                    
                    Image(systemName: "arrow.up.and.down")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.blue)
                }
                .offset(y: -geo.size.height * (1.0 - value) + 14)
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { val in
                            let delta = val.location.y / geo.size.height
                            value = max(0, min(1.0, delta))
                        }
                )
            }
            .frame(width: 44) // Wider hit area
        }
        .frame(width: 44, height: 280)
    }
}

enum SpacingSide {
    case left, right
}

struct SpacingHandle: View {
    @Binding var spacing: CGFloat
    let side: SpacingSide
    
    var body: some View {
        VStack {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.white.opacity(0.1))
                    .frame(width: 44, height: 80)
                
                VStack(spacing: 4) {
                    Image(systemName: side == .left ? "arrow.left" : "arrow.right")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.blue)
                    
                    Text("label_spacing")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundColor(.white.opacity(0.6))
                }
            }
            .gesture(
                DragGesture()
                    .onChanged { val in
                        // Sensitivity adjustment for spacing
                        let delta = val.translation.width / 100.0
                        let multiplier: CGFloat = (side == .left) ? -1.0 : 1.0
                        spacing = max(0.1, min(0.8, spacing + delta * multiplier * 0.05))
                    }
            )
        }
    }
}

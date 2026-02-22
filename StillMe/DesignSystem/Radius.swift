import SwiftUI

struct Radius {
    static let sm: CGFloat = 4
    static let md: CGFloat = 6
    static let lg: CGFloat = 8
    static let xl: CGFloat = 12
    static let xxl: CGFloat = 16 // Sharper, modern cards
    static let container: CGFloat = 32
}

extension View {
    func dsCornerRadius(_ radius: CGFloat) -> some View {
        self.cornerRadius(radius)
    }
}

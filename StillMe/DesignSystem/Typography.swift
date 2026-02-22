import SwiftUI

struct Typography {
    static let baseSize: CGFloat = 16
    
    static let h1 = Font.system(size: 24, weight: .semibold)
    static let h2 = Font.system(size: 20, weight: .semibold)
    static let body = Font.system(size: 16, weight: .medium)
    static let bodyMedium = Font.system(size: 16, weight: .semibold)
    static let bodyBold = Font.system(size: 16, weight: .bold)
    static let small = Font.system(size: 14, weight: .medium)
    static let smallBold = Font.system(size: 14, weight: .bold)
    static let extraSmall = Font.system(size: 12, weight: .medium)
    static let caption = Font.system(size: 10, weight: .medium)
    static let large = Font.system(size: 36, weight: .medium)
}

extension View {
    func dsFont(_ font: Font) -> some View {
        self.font(font)
    }
}

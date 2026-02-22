import SwiftUI

extension Color {
    // Backgrounds
    static let dsBackground = Color.black
    static let dsBackgroundOuter = Color.black
    static let dsBackgroundLight = Color(red: 28/255, green: 28/255, blue: 30/255) // secondary background for sheets
    
    // Components
    static let dsCard = Color(hex: "1F1F1F")
    static let dsCardHover = Color.white.opacity(0.02)
    static let dsCardActive = Color.white.opacity(0.04)
    
    // Text
    static let dsForeground = Color.white
    static let dsMuted = Color.white.opacity(0.4)
    static let dsMutedLight = Color.white.opacity(0.6)
    static let dsMutedDeep = Color.white.opacity(0.3)
    static let dsMutedHighlight = Color.white.opacity(0.2)
    
    // Brand / Primary
    static let dsPrimary = Color.white
    static let dsAccent = Color(hex: "A3E635") // Phase 286: Vibrant Neon Lime for Targeted/Special indicators
    
    // Chart Colors (Standard shadcn dark defaults as fallback)
    static let dsChart1 = Color(red: 225/255, green: 29/255, blue: 72/255) // rose-600
    static let dsChart2 = Color(red: 37/255, green: 99/255, blue: 235/255) // blue-600
    static let dsChart3 = Color(red: 13/255, green: 148/255, blue: 136/255) // teal-600
    static let dsChart4 = Color(red: 202/255, green: 138/255, blue: 4/255) // yellow-600
    static let dsChart5 = Color(red: 217/255, green: 70/255, blue: 239/255) // fuchsia-600
    
    static let dsSuccess = Color(red: 34/255, green: 197/255, blue: 94/255) // green-500
    static let dsError = Color(red: 239/255, green: 68/255, blue: 68/255) // red-500
    
    // UI Elements
    static let dsBorder = Color(hex: "262626")
    static let dsInput = Color.white.opacity(0.05)
    static let dsRing = Color.white.opacity(0.4)
    static let dsSeparator = Color.white.opacity(0.05)
    
    // Hex Support
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

import SwiftUI

enum TabType: String, CaseIterable {
    case today = "Today"
    case home = "Home"
    case gallery = "Gallery"
    case pair = "Pair"
    case account = "Account"
    
    static var visibleTabs: [TabType] {
        return [.home, .gallery, .today, .pair, .account]
    }
    
    var displayName: String {
        switch self {
        case .today: return ""
        case .home: return NSLocalizedString("tab_home", comment: "Home")
        case .gallery: return NSLocalizedString("tab_gallery", comment: "Gallery")
        case .pair: return NSLocalizedString("tab_pair", comment: "Pair")
        case .account: return NSLocalizedString("tab_account", comment: "Account")
        }
    }

    var iconName: String {
        switch self {
        case .today: return "camera.fill"
        case .home: return "house.fill"
        case .gallery: return "photo.on.rectangle"
        case .pair: return "person.2"
        case .account: return "person"
        }
    }
}

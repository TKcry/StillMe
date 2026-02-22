import SwiftUI
import Combine

class OnboardingDraft: ObservableObject {
    @Published var nickname: String = ""
    @Published var handle: String = ""
    @Published var avatarImage: UIImage? = nil
    @Published var birthday: Date = Calendar.current.date(byAdding: .year, value: -25, to: Date()) ?? Date()
    
    // No calibration needed in StillMe
}

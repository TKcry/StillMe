import SwiftUI

struct TodayTabView: View {
    @EnvironmentObject var viewModel: AppViewModel // Phase 212.1
    var body: some View {
        TodayView()
    }
}

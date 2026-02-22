import Foundation
import Combine

@MainActor
final class MomentExportState: ObservableObject {
    @Published var isExporting: Bool = false
    @Published var activeCaptureId: String? = nil // Phase 213.3: Authoritative identity
    @Published var startedAt: TimeInterval = 0     // For diagnostics

    // 任意：デバッグ用（どのexportが生きてるか）
    @Published var exportSessionId: String = ""
}

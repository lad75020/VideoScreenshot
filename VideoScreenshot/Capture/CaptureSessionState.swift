import Foundation

enum CaptureSessionState: String, Equatable, Codable, CaseIterable {
    case idle, areaSelected, validating, recording, stopping, finalizing, completed, completedWithWarning, error

    func canTransition(to next: CaptureSessionState) -> Bool {
        switch (self, next) {
        case (.idle, .areaSelected), (.areaSelected, .validating), (.areaSelected, .idle): return true
        case (.validating, .recording), (.validating, .error), (.validating, .areaSelected): return true
        case (.recording, .stopping), (.recording, .error): return true
        case (.stopping, .finalizing), (.finalizing, .completed), (.finalizing, .error): return true
        case (.error, .idle), (.error, .areaSelected): return true
        case (.completed, .idle), (.completedWithWarning, .idle): return true
        default: return false
        }
    }
}

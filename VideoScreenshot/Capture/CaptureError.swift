import Foundation

struct CaptureError: Error, Equatable, Identifiable {
    var id: String { code }
    let code: String
    let message: String
    let recoveryAction: String
    let isRecoverable: Bool
    let preservedArtifacts: [URL]

    static func invalidArea() -> CaptureError { .init(code: "invalid_area", message: "Select an area before starting capture.", recoveryAction: "Use Select Area and drag a non-empty rectangle.", isRecoverable: true, preservedArtifacts: []) }
    static func permissionDenied(_ message: String) -> CaptureError { .init(code: "permission_denied", message: message, recoveryAction: "Open System Settings, grant capture permission, then restart the app if macOS asks.", isRecoverable: true, preservedArtifacts: []) }
    static func writerUnsupported(_ message: String) -> CaptureError { .init(code: "writer_unsupported", message: message, recoveryAction: "Choose another output or run on a Mac that supports the requested Apple media writer combination.", isRecoverable: true, preservedArtifacts: []) }
}

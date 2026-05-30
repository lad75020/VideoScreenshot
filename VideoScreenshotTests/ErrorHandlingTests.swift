import AVFoundation
import XCTest
@testable import VideoScreenshot

final class ErrorHandlingTests: XCTestCase {
    func testPermissionErrorHasRecoveryAction() {
        let error = CaptureError.permissionDenied("Denied")
        XCTAssertFalse(error.recoveryAction.isEmpty); XCTAssertTrue(error.isRecoverable)
    }

    @MainActor
    func testMP4AudioSettingsUseAACForAppleWriterCompatibility() {
        let settings = MP4ExportService.mp4AudioSettings(sampleRate: 48_000, channelCount: 2)
        XCTAssertEqual(settings[AVFormatIDKey] as? AudioFormatID, kAudioFormatMPEG4AAC)
    }

    func testFinalizationErrorCanPreserveArtifacts() {
        let url = URL(fileURLWithPath: "/tmp/raw.mov")
        let error = CaptureError(code: "finalize_failed", message: "Failed", recoveryAction: "Retry", isRecoverable: true, preservedArtifacts: [url])
        XCTAssertEqual(error.preservedArtifacts, [url])
    }
}

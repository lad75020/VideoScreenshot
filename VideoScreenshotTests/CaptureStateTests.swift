import XCTest
@testable import VideoScreenshot

final class CaptureStateTests: XCTestCase {
    func testValidCaptureStateTransitions() {
        XCTAssertTrue(CaptureSessionState.idle.canTransition(to: .areaSelected))
        XCTAssertTrue(CaptureSessionState.areaSelected.canTransition(to: .validating))
        XCTAssertTrue(CaptureSessionState.validating.canTransition(to: .recording))
        XCTAssertTrue(CaptureSessionState.recording.canTransition(to: .stopping))
        XCTAssertTrue(CaptureSessionState.stopping.canTransition(to: .finalizing))
        XCTAssertTrue(CaptureSessionState.finalizing.canTransition(to: .completed))
    }
    func testRejectsOverlappingRecordingTransition() { XCTAssertFalse(CaptureSessionState.recording.canTransition(to: .recording)); XCTAssertFalse(CaptureSessionState.recording.canTransition(to: .validating)) }
    func testStopIsOnlyValidFromRecording() { XCTAssertTrue(CaptureSessionState.recording.canTransition(to: .stopping)); XCTAssertFalse(CaptureSessionState.idle.canTransition(to: .stopping)) }
}

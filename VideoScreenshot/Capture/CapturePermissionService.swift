import AppKit
import Foundation

protocol CapturePermissionServicing { func currentStatus(requireAudio: Bool) -> PermissionStatus }

final class CapturePermissionService: CapturePermissionServicing {
    func currentStatus(requireAudio: Bool) -> PermissionStatus {
        let screenGranted = CGPreflightScreenCaptureAccess()
        return PermissionStatus(screenCapture: screenGranted ? .granted : .denied, systemAudioCapture: requireAudio ? .granted : .unavailable, lastCheckedAt: Date(), recoveryMessage: screenGranted ? nil : "Grant Screen Recording permission in System Settings and restart if required.")
    }
}

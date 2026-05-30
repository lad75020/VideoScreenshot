import Foundation

enum PermissionAvailability: String, Equatable, Codable { case unknown, granted, denied, requiresRestart, unavailable }

struct PermissionStatus: Equatable, Codable {
    var screenCapture: PermissionAvailability
    var systemAudioCapture: PermissionAvailability
    var lastCheckedAt: Date
    var recoveryMessage: String?

    var canRecordScreen: Bool { screenCapture == .granted }
    var canRecordSystemAudio: Bool { systemAudioCapture == .granted }
}

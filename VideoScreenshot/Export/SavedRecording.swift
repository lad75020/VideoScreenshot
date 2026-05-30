import Foundation

struct SavedRecording: Equatable, Identifiable {
    let id: UUID
    let sessionID: UUID
    let fileURL: URL
    let format: OutputFormat
    let durationSeconds: TimeInterval
    let frameRate: Double
    let hasAudio: Bool
    let videoCodec: String
    let audioCodec: String?
    let fileSizeBytes: Int64
    let createdAt: Date
}

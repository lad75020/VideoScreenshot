import CoreGraphics
import CoreImage
import CoreMedia
import Foundation
import ImageIO
import UniformTypeIdentifiers

protocol GIFExportServicing: AnyObject, Sendable {
    func begin(sessionID: UUID, settings: OutputSettings, startedAt: Date) async throws
    func appendVideoFrame(_ frame: CapturedVideoFrame) async throws
    func finalize(sessionID: UUID, settings: OutputSettings, startedAt: Date, stoppedAt: Date) async throws -> SavedRecording
    func cancel() async
}

actor GIFExportService: GIFExportServicing {
    private let imageContext = CIContext(options: [.useSoftwareRenderer: false])
    private var activeSessionID: UUID?
    private var activeOutputURL: URL?
    private var activeTemporaryOutputURL: URL?
    private var activeStartedAt: Date?
    private var outputFolderAccess: SecurityScopedFolderAccess?
    private var temporaryFolderAccess: SecurityScopedFolderAccess?
    private var frames: [CGImage] = []
    private var bufferedPixelCount = 0

    static let frameDelaySeconds = 1.0 / 24.0
    static let maximumBufferedFrames = 1_440
    static let maximumBufferedPixels = 128_000_000

    func begin(sessionID: UUID, settings: OutputSettings, startedAt: Date) async throws {
        guard settings.format == .gif else { return }
        reset(removeTemporaryFile: true)
        let outputFolderAccess = settings.startFinalOutputFolderAccess()
        let temporaryFolderAccess = settings.startTemporaryFolderAccess()
        let namer = OutputFileNamer()
        do {
            let outputURL = try namer.resolvedURL(for: settings)
            activeSessionID = sessionID
            activeOutputURL = outputURL
            activeTemporaryOutputURL = namer.temporaryURL(for: outputURL, in: settings.temporaryFolderURL)
            activeStartedAt = startedAt
            self.outputFolderAccess = outputFolderAccess
            self.temporaryFolderAccess = temporaryFolderAccess
        } catch {
            outputFolderAccess.stop()
            temporaryFolderAccess.stop()
            throw error
        }
    }

    func appendVideoFrame(_ frame: CapturedVideoFrame) async throws {
        guard activeSessionID != nil else { return }
        guard let imageBuffer = CMSampleBufferGetImageBuffer(frame.sampleBuffer) else {
            throw CaptureError(
                code: "gif_frame_unavailable",
                message: "A captured video frame could not be converted for GIF export.",
                recoveryAction: "Retry the capture or choose MP4 output.",
                isRecoverable: true,
                preservedArtifacts: activeTemporaryOutputURL.map { [$0] } ?? []
            )
        }
        let ciImage = CIImage(cvPixelBuffer: imageBuffer)
        guard let cgImage = imageContext.createCGImage(ciImage, from: ciImage.extent) else {
            throw CaptureError(
                code: "gif_frame_unavailable",
                message: "A captured video frame could not be rendered for GIF export.",
                recoveryAction: "Retry the capture or choose MP4 output.",
                isRecoverable: true,
                preservedArtifacts: activeTemporaryOutputURL.map { [$0] } ?? []
            )
        }

        let nextPixelCount = cgImage.width * cgImage.height
        guard frames.count < Self.maximumBufferedFrames,
              bufferedPixelCount + nextPixelCount <= Self.maximumBufferedPixels else {
            throw CaptureError(
                code: "gif_buffer_limit_exceeded",
                message: "The GIF recording is too large to keep safely in memory.",
                recoveryAction: "Stop sooner, capture a smaller area, or choose MP4 output for longer recordings.",
                isRecoverable: true,
                preservedArtifacts: activeTemporaryOutputURL.map { [$0] } ?? []
            )
        }

        frames.append(cgImage)
        bufferedPixelCount += nextPixelCount
    }

    func finalize(sessionID: UUID, settings: OutputSettings, startedAt: Date, stoppedAt: Date) async throws -> SavedRecording {
        if activeOutputURL == nil {
            try await begin(sessionID: sessionID, settings: settings, startedAt: startedAt)
        }
        guard let outputURL = activeOutputURL, let temporaryURL = activeTemporaryOutputURL else {
            throw CaptureError(
                code: "gif_writer_unavailable",
                message: "Animated GIF writer is unavailable.",
                recoveryAction: "Choose MP4 or another destination.",
                isRecoverable: true,
                preservedArtifacts: []
            )
        }

        let images = frames.isEmpty ? [Self.emptyPlaceholderFrame()] : frames
        guard let destination = CGImageDestinationCreateWithURL(temporaryURL as CFURL, UTType.gif.identifier as CFString, images.count, nil) else {
            throw CaptureError(
                code: "gif_writer_unavailable",
                message: "Animated GIF writer is unavailable.",
                recoveryAction: "Choose MP4 or another destination.",
                isRecoverable: true,
                preservedArtifacts: []
            )
        }

        let fileProperties: [CFString: Any] = [
            kCGImagePropertyGIFDictionary: [
                kCGImagePropertyGIFLoopCount: 0
            ]
        ]
        CGImageDestinationSetProperties(destination, fileProperties as CFDictionary)

        let frameProperties: [CFString: Any] = [
            kCGImagePropertyGIFDictionary: [
                kCGImagePropertyGIFDelayTime: Self.frameDelaySeconds,
                kCGImagePropertyGIFUnclampedDelayTime: Self.frameDelaySeconds
            ]
        ]
        for image in images {
            CGImageDestinationAddImage(destination, image, frameProperties as CFDictionary)
        }

        guard CGImageDestinationFinalize(destination) else {
            throw CaptureError(
                code: "gif_finalize_failed",
                message: "The animated GIF could not be finalized.",
                recoveryAction: "Check disk space and destination folder, then retry.",
                isRecoverable: true,
                preservedArtifacts: [temporaryURL]
            )
        }

        try OutputFileNamer().commitTemporaryFile(temporaryURL, to: outputURL)
        defer { reset(removeTemporaryFile: false) }
        let size = (try? FileManager.default.attributesOfItem(atPath: outputURL.path)[.size] as? Int64) ?? 0
        return SavedRecording(
            id: UUID(),
            sessionID: sessionID,
            fileURL: outputURL,
            format: .gif,
            durationSeconds: max(0, stoppedAt.timeIntervalSince(startedAt)),
            frameRate: 24,
            hasAudio: false,
            videoCodec: "gif",
            audioCodec: nil,
            fileSizeBytes: size,
            createdAt: Date()
        )
    }

    func cancel() async {
        reset(removeTemporaryFile: true)
    }

    private func reset(removeTemporaryFile: Bool) {
        if removeTemporaryFile, let activeTemporaryOutputURL {
            try? FileManager.default.removeItem(at: activeTemporaryOutputURL)
        }
        activeSessionID = nil
        activeOutputURL = nil
        activeTemporaryOutputURL = nil
        activeStartedAt = nil
        outputFolderAccess?.stop()
        outputFolderAccess = nil
        temporaryFolderAccess?.stop()
        temporaryFolderAccess = nil
        frames.removeAll(keepingCapacity: true)
        bufferedPixelCount = 0
    }

    private static func emptyPlaceholderFrame() -> CGImage {
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue
        let context = CGContext(data: nil, width: 1, height: 1, bitsPerComponent: 8, bytesPerRow: 4, space: colorSpace, bitmapInfo: bitmapInfo)!
        context.setFillColor(CGColor(red: 0, green: 0, blue: 0, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: 1, height: 1))
        return context.makeImage()!
    }
}

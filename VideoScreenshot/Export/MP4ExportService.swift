import AVFoundation
import CoreAudioTypes
import CoreGraphics
import Foundation

protocol MP4ExportServicing: AnyObject, Sendable {
    func validateCapabilities(for settings: OutputSettings) async throws
    func begin(sessionID: UUID, settings: OutputSettings, startedAt: Date, videoSize: CGSize) async throws
    func appendVideoFrame(_ frame: CapturedVideoFrame) async throws
    func appendAudioSample(_ sample: CapturedAudioSample) async throws
    func finalize(sessionID: UUID, settings: OutputSettings, startedAt: Date, stoppedAt: Date) async throws -> SavedRecording
    func cancel() async
}

actor MP4ExportService: MP4ExportServicing {
    private var writer: AVAssetWriter?
    private var videoInput: AVAssetWriterInput?
    private var audioInput: AVAssetWriterInput?
    private var activeSessionID: UUID?
    private var activeOutputURL: URL?
    private var activeTemporaryOutputURL: URL?
    private var activeStartedAt: Date?
    private var outputFolderAccess: SecurityScopedFolderAccess?
    private var temporaryFolderAccess: SecurityScopedFolderAccess?
    private var didStartSession = false
    private var appendedVideoFrames = 0
    private var appendedAudioSamples = 0

    func validateCapabilities(for settings: OutputSettings) async throws {
        guard settings.format == .mp4 else { return }

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("mp4")
        defer { try? FileManager.default.removeItem(at: url) }

        let writer = try AVAssetWriter(outputURL: url, fileType: .mp4)
        let videoSettings = Self.hevcVideoSettings(width: 64, height: 64)
        let audioSettings = Self.mp4AudioSettings(sampleRate: 48_000, channelCount: 2)

        guard writer.canApply(outputSettings: videoSettings, forMediaType: .video) else {
            throw CaptureError.writerUnsupported("HEVC/H.265 MP4 video writing is unavailable on this Mac.")
        }
        if settings.shouldCaptureSystemAudio() {
            guard writer.canApply(outputSettings: audioSettings, forMediaType: .audio) else {
                throw CaptureError.writerUnsupported("AAC audio in an MP4 file is unavailable through Apple media writers on this Mac.")
            }
        }

        let videoInput = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
        guard writer.canAdd(videoInput) else {
            throw CaptureError.writerUnsupported("HEVC/H.265 video cannot be added to the MP4 writer on this Mac.")
        }
        if settings.shouldCaptureSystemAudio() {
            let audioInput = AVAssetWriterInput(mediaType: .audio, outputSettings: audioSettings)
            guard writer.canAdd(audioInput) else {
                throw CaptureError.writerUnsupported("AAC audio cannot be added to the MP4 writer on this Mac.")
            }
        }
    }

    func begin(sessionID: UUID, settings: OutputSettings, startedAt: Date, videoSize: CGSize) async throws {
        guard settings.format == .mp4 else { return }
        try await validateCapabilities(for: settings)
        resetWriterState(removeTemporaryFile: true)
        let outputFolderAccess = settings.startFinalOutputFolderAccess()
        let temporaryFolderAccess = settings.startTemporaryFolderAccess()
        let namer = OutputFileNamer()

        do {
            let outputURL = try namer.resolvedURL(for: settings)
            let temporaryURL = namer.temporaryURL(for: outputURL, in: settings.temporaryFolderURL)
            let writer = try AVAssetWriter(outputURL: temporaryURL, fileType: .mp4)
            let width = max(1, Int(videoSize.width.rounded(.toNearestOrAwayFromZero)))
            let height = max(1, Int(videoSize.height.rounded(.toNearestOrAwayFromZero)))
            let videoSettings = Self.hevcVideoSettings(width: width, height: height)
            let audioSettings = Self.mp4AudioSettings(sampleRate: 48_000, channelCount: 2)

            guard writer.canApply(outputSettings: videoSettings, forMediaType: .video) else {
                throw CaptureError.writerUnsupported("HEVC/H.265 MP4 video writing is unavailable on this Mac.")
            }
            if settings.shouldCaptureSystemAudio() {
                guard writer.canApply(outputSettings: audioSettings, forMediaType: .audio) else {
                    throw CaptureError.writerUnsupported("AAC audio in an MP4 file is unavailable through Apple media writers on this Mac.")
                }
            }

            let videoInput = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
            videoInput.expectsMediaDataInRealTime = true
            guard writer.canAdd(videoInput) else {
                throw CaptureError.writerUnsupported("HEVC/H.265 video cannot be added to the MP4 writer on this Mac.")
            }
            writer.add(videoInput)

            let audioInput: AVAssetWriterInput?
            if settings.shouldCaptureSystemAudio() {
                let input = AVAssetWriterInput(mediaType: .audio, outputSettings: audioSettings)
                input.expectsMediaDataInRealTime = true
                guard writer.canAdd(input) else {
                    throw CaptureError.writerUnsupported("AAC audio cannot be added to the MP4 writer on this Mac.")
                }
                writer.add(input)
                audioInput = input
            } else {
                audioInput = nil
            }

            guard writer.startWriting() else {
                throw CaptureError.writerUnsupported(writer.error?.localizedDescription ?? "The MP4 writer could not start.")
            }

            self.writer = writer
            self.videoInput = videoInput
            self.audioInput = audioInput
            self.activeSessionID = sessionID
            self.activeOutputURL = outputURL
            self.activeTemporaryOutputURL = temporaryURL
            self.activeStartedAt = startedAt
            self.outputFolderAccess = outputFolderAccess
            self.temporaryFolderAccess = temporaryFolderAccess
            didStartSession = false
            appendedVideoFrames = 0
            appendedAudioSamples = 0
        } catch {
            outputFolderAccess.stop()
            temporaryFolderAccess.stop()
            throw error
        }
    }

    func appendVideoFrame(_ frame: CapturedVideoFrame) async throws {
        guard let writer, let videoInput else { return }
        try ensureSessionStarted(at: frame.presentationTime)
        guard writer.status == .writing else { throw writerError(writer, fallback: "MP4 writer is not accepting video frames.") }
        guard videoInput.isReadyForMoreMediaData else { return }
        guard videoInput.append(frame.sampleBuffer) else { throw writerError(writer, fallback: "Failed to append an HEVC/H.265 video frame.") }
        appendedVideoFrames += 1
    }

    func appendAudioSample(_ sample: CapturedAudioSample) async throws {
        guard let writer, let audioInput else { return }
        guard didStartSession else { return }
        guard writer.status == .writing else { throw writerError(writer, fallback: "MP4 writer is not accepting AAC audio samples.") }
        guard audioInput.isReadyForMoreMediaData else { return }
        guard audioInput.append(sample.sampleBuffer) else { throw writerError(writer, fallback: "Failed to append an AAC audio sample.") }
        appendedAudioSamples += 1
    }

    func finalize(sessionID: UUID, settings: OutputSettings, startedAt: Date, stoppedAt: Date) async throws -> SavedRecording {
        if writer == nil {
            try await begin(sessionID: sessionID, settings: settings, startedAt: startedAt, videoSize: CGSize(width: 64, height: 64))
        }
        guard let writer, let outputURL = activeOutputURL, let temporaryURL = activeTemporaryOutputURL else {
            throw CaptureError(code: "writer_unavailable", message: "MP4 writer is unavailable.", recoveryAction: "Retry the capture or choose GIF output.", isRecoverable: true, preservedArtifacts: [])
        }

        if !didStartSession {
            writer.startSession(atSourceTime: .zero)
            didStartSession = true
        }
        videoInput?.markAsFinished()
        audioInput?.markAsFinished()

        await finishWriting(writer)

        defer { resetWriterState(removeTemporaryFile: false) }
        guard writer.status == .completed else { throw writerError(writer, fallback: "Failed to finalize the MP4 file.") }

        try OutputFileNamer().commitTemporaryFile(temporaryURL, to: outputURL)
        let size = (try? FileManager.default.attributesOfItem(atPath: outputURL.path)[.size] as? Int64) ?? 0
        return SavedRecording(
            id: UUID(),
            sessionID: sessionID,
            fileURL: outputURL,
            format: .mp4,
            durationSeconds: max(0, stoppedAt.timeIntervalSince(startedAt)),
            frameRate: 24,
            hasAudio: appendedAudioSamples > 0,
            videoCodec: "hevc",
            audioCodec: appendedAudioSamples > 0 ? "aac" : nil,
            fileSizeBytes: size,
            createdAt: Date()
        )
    }

    func cancel() async {
        resetWriterState(removeTemporaryFile: true)
    }

    private func ensureSessionStarted(at time: CMTime) throws {
        guard let writer else { return }
        guard writer.status == .writing else { throw writerError(writer, fallback: "MP4 writer is not ready.") }
        if !didStartSession {
            writer.startSession(atSourceTime: time.isValid ? time : .zero)
            didStartSession = true
        }
    }

    private func finishWriting(_ writer: AVAssetWriter) async {
        await withCheckedContinuation { continuation in
            writer.finishWriting {
                continuation.resume()
            }
        }
    }

    private func writerError(_ writer: AVAssetWriter, fallback: String) -> CaptureError {
        CaptureError(
            code: "writer_unsupported",
            message: writer.error?.localizedDescription ?? fallback,
            recoveryAction: "Choose a supported destination or GIF output, then retry.",
            isRecoverable: true,
            preservedArtifacts: activeTemporaryOutputURL.map { [$0] } ?? []
        )
    }

    private func resetWriterState(removeTemporaryFile: Bool) {
        if removeTemporaryFile, let activeTemporaryOutputURL {
            try? FileManager.default.removeItem(at: activeTemporaryOutputURL)
        }
        writer = nil
        videoInput = nil
        audioInput = nil
        activeSessionID = nil
        activeOutputURL = nil
        activeTemporaryOutputURL = nil
        activeStartedAt = nil
        outputFolderAccess?.stop()
        outputFolderAccess = nil
        temporaryFolderAccess?.stop()
        temporaryFolderAccess = nil
        didStartSession = false
        appendedVideoFrames = 0
        appendedAudioSamples = 0
    }

    private static func hevcVideoSettings(width: Int, height: Int) -> [String: Any] {
        [
            AVVideoCodecKey: AVVideoCodecType.hevc,
            AVVideoWidthKey: width,
            AVVideoHeightKey: height,
            AVVideoCompressionPropertiesKey: [
                AVVideoAverageBitRateKey: max(1_000_000, width * height * 6),
                AVVideoExpectedSourceFrameRateKey: 24,
                AVVideoMaxKeyFrameIntervalKey: 24,
                AVVideoAllowFrameReorderingKey: false
            ]
        ]
    }

    static func mp4AudioSettings(sampleRate: Double, channelCount: Int) -> [String: Any] {
        [
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVSampleRateKey: sampleRate,
            AVNumberOfChannelsKey: channelCount,
            AVEncoderBitRateKey: 128_000
        ]
    }
}

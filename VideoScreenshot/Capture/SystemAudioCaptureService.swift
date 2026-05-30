import AVFAudio
import CoreMedia
import Foundation
import ScreenCaptureKit

struct CapturedAudioSample: @unchecked Sendable {
    let sampleBuffer: CMSampleBuffer
    let presentationTime: CMTime
    let sampleRate: Double?
    let channelCount: UInt32?
}

@MainActor
protocol SystemAudioCaptureServicing {
    func setAudioSampleHandler(_ handler: (@Sendable (CapturedAudioSample) -> Void)?)
    func startIfNeeded(shouldCaptureAudio: Bool) async throws
    func stop() async
}

@MainActor
final class SystemAudioCaptureService: SystemAudioCaptureServicing {
    private(set) var isRunning = false
    private(set) var capturedSampleCount = 0

    var onAudioSample: (@Sendable (CapturedAudioSample) -> Void)?

    func setAudioSampleHandler(_ handler: (@Sendable (CapturedAudioSample) -> Void)?) {
        onAudioSample = handler
    }

    private var stream: SCStream?
    private var streamOutput: AudioStreamOutput?
    private let audioSampleQueue = DispatchQueue(label: "fr.dubertrand.VideoScreenshot.audio-samples", qos: .userInitiated)
    private let audioDeliveryGate = SampleDeliveryGate()

    func startIfNeeded(shouldCaptureAudio: Bool) async throws {
        guard shouldCaptureAudio else {
            await stop()
            return
        }
        guard !isRunning else {
            throw CaptureError(
                code: "audio_capture_busy",
                message: "System audio capture is already active.",
                recoveryAction: "Stop the current capture before starting another one.",
                isRecoverable: true,
                preservedArtifacts: []
            )
        }

        let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
        guard let display = content.displays.first(where: { $0.displayID == CGMainDisplayID() }) else {
            throw CaptureError(
                code: "display_unavailable",
                message: "The main screen is not available for system audio capture.",
                recoveryAction: "Verify Screen Recording permission and keep the capture on the main screen, then retry.",
                isRecoverable: true,
                preservedArtifacts: []
            )
        }

        let configuration = audioConfiguration(for: display)
        let filter = SCContentFilter(display: display, excludingWindows: [])
        let sampleHandler = onAudioSample
        let output = AudioStreamOutput { [weak self, audioDeliveryGate, sampleHandler] sample in
            guard audioDeliveryGate.tryBegin() else { return }
            Task { @MainActor in self?.capturedSampleCount += 1 }
            sampleHandler?(sample)
            audioDeliveryGate.end()
        }
        let newStream = SCStream(filter: filter, configuration: configuration, delegate: nil)
        try newStream.addStreamOutput(output, type: .audio, sampleHandlerQueue: audioSampleQueue)
        try await newStream.startCapture()

        stream = newStream
        streamOutput = output
        capturedSampleCount = 0
        isRunning = true
    }

    func stop() async {
        guard isRunning || stream != nil else { return }
        do {
            try await stream?.stopCapture()
        } catch {
            // Stopping is best-effort; the coordinator owns user-facing error reporting.
        }
        stream = nil
        streamOutput = nil
        isRunning = false
        audioDeliveryGate.reset()
    }

    private func audioConfiguration(for display: SCDisplay) -> SCStreamConfiguration {
        let configuration = SCStreamConfiguration()
        configuration.width = max(1, display.width)
        configuration.height = max(1, display.height)
        configuration.minimumFrameInterval = CMTime(value: 1, timescale: 24)
        configuration.queueDepth = 3
        configuration.capturesAudio = true
        configuration.excludesCurrentProcessAudio = true
        configuration.captureMicrophone = false
        configuration.sampleRate = 48_000
        configuration.channelCount = 2
        return configuration
    }
}

private final class AudioStreamOutput: NSObject, SCStreamOutput {
    private let sampleHandler: @Sendable (CapturedAudioSample) -> Void

    init(sampleHandler: @escaping @Sendable (CapturedAudioSample) -> Void) {
        self.sampleHandler = sampleHandler
    }

    func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of outputType: SCStreamOutputType) {
        guard outputType == .audio, sampleBuffer.isValid else { return }
        let description = sampleBuffer.formatDescription?.audioStreamBasicDescription
        sampleHandler(CapturedAudioSample(
            sampleBuffer: sampleBuffer,
            presentationTime: CMSampleBufferGetPresentationTimeStamp(sampleBuffer),
            sampleRate: description?.mSampleRate,
            channelCount: description?.mChannelsPerFrame
        ))
    }
}

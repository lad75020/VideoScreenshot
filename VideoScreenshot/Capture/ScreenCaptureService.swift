import CoreGraphics
import CoreMedia
import Foundation
import ScreenCaptureKit

final class SampleDeliveryGate: @unchecked Sendable {
    private let lock = NSLock()
    private var isPending = false

    func tryBegin() -> Bool {
        lock.lock()
        defer { lock.unlock() }
        guard !isPending else { return false }
        isPending = true
        return true
    }

    func end() {
        lock.lock()
        isPending = false
        lock.unlock()
    }

    func reset() {
        end()
    }
}

struct CapturedVideoFrame: @unchecked Sendable {
    let sampleBuffer: CMSampleBuffer
    let presentationTime: CMTime
    let attachments: [SCStreamFrameInfo: Any]
}

@MainActor
protocol ScreenCaptureServicing {
    func setVideoFrameHandler(_ handler: (@Sendable (CapturedVideoFrame) -> Void)?)
    func start(area: CaptureArea) async throws
    func stop() async
}

@MainActor
final class ScreenCaptureService: ScreenCaptureServicing {
    private(set) var isRunning = false
    private(set) var activeArea: CaptureArea?
    private(set) var droppedFrameCount = 0
    private(set) var capturedFrameCount = 0

    var onVideoFrame: (@Sendable (CapturedVideoFrame) -> Void)?

    func setVideoFrameHandler(_ handler: (@Sendable (CapturedVideoFrame) -> Void)?) {
        onVideoFrame = handler
    }

    private var stream: SCStream?
    private var streamOutput: VideoStreamOutput?
    private let videoSampleQueue = DispatchQueue(label: "fr.dubertrand.VideoScreenshot.screen-samples", qos: .userInitiated)
    private let videoDeliveryGate = SampleDeliveryGate()

    func start(area: CaptureArea) async throws {
        guard area.isValid else { throw CaptureError.invalidArea() }
        guard !isRunning else {
            throw CaptureError(
                code: "capture_busy",
                message: "A capture is already active.",
                recoveryAction: "Stop the active capture before starting another one.",
                isRecoverable: true,
                preservedArtifacts: []
            )
        }

        let display = try await displayForArea(area)
        let configuration = streamConfiguration(for: area)
        let filter = SCContentFilter(display: display, excludingWindows: [])
        let frameHandler = onVideoFrame
        let output = VideoStreamOutput { [weak self, videoDeliveryGate, frameHandler] frame in
            guard videoDeliveryGate.tryBegin() else {
                Task { @MainActor in self?.droppedFrameCount += 1 }
                return
            }
            Task { @MainActor in self?.capturedFrameCount += 1 }
            frameHandler?(frame)
            videoDeliveryGate.end()
        } droppedFrameHandler: { [weak self] in
            Task { @MainActor in self?.droppedFrameCount += 1 }
        }

        let newStream = SCStream(filter: filter, configuration: configuration, delegate: nil)
        try newStream.addStreamOutput(output, type: .screen, sampleHandlerQueue: videoSampleQueue)
        try await newStream.startCapture()

        stream = newStream
        streamOutput = output
        activeArea = area
        capturedFrameCount = 0
        droppedFrameCount = 0
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
        activeArea = nil
        isRunning = false
        videoDeliveryGate.reset()
    }

    private func streamConfiguration(for area: CaptureArea) -> SCStreamConfiguration {
        let pixelRect = area.pixelRect.integral
        let configuration = SCStreamConfiguration()
        configuration.sourceRect = pixelRect
        configuration.width = max(1, Int(pixelRect.width))
        configuration.height = max(1, Int(pixelRect.height))
        configuration.minimumFrameInterval = CMTime(value: 1, timescale: 24)
        configuration.queueDepth = 5
        configuration.scalesToFit = false
        configuration.preservesAspectRatio = true
        configuration.capturesAudio = false
        return configuration
    }

    private func displayForArea(_ area: CaptureArea) async throws -> SCDisplay {
        let mainDisplayID = CGMainDisplayID()
        guard area.displayID == mainDisplayID else {
            throw CaptureError(
                code: "secondary_display_unsupported",
                message: "Capture is currently limited to the main screen.",
                recoveryAction: "Move the content to the main screen and select the area again.",
                isRecoverable: true,
                preservedArtifacts: []
            )
        }

        let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
        if let mainDisplay = content.displays.first(where: { $0.displayID == mainDisplayID }) {
            return mainDisplay
        }
        throw CaptureError(
            code: "display_unavailable",
            message: "The main screen is not available for capture.",
            recoveryAction: "Verify Screen Recording permission and keep the capture area on the main screen.",
            isRecoverable: true,
            preservedArtifacts: []
        )
    }
}

private final class VideoStreamOutput: NSObject, SCStreamOutput {
    private let frameHandler: @Sendable (CapturedVideoFrame) -> Void
    private let droppedFrameHandler: @Sendable () -> Void

    init(
        frameHandler: @escaping @Sendable (CapturedVideoFrame) -> Void,
        droppedFrameHandler: @escaping @Sendable () -> Void
    ) {
        self.frameHandler = frameHandler
        self.droppedFrameHandler = droppedFrameHandler
    }

    func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of outputType: SCStreamOutputType) {
        guard outputType == .screen, sampleBuffer.isValid else { return }
        guard let attachments = videoAttachments(from: sampleBuffer) else {
            droppedFrameHandler()
            return
        }
        guard let statusRawValue = attachments[SCStreamFrameInfo.status] as? Int,
              let status = SCFrameStatus(rawValue: statusRawValue),
              status == .complete else {
            droppedFrameHandler()
            return
        }
        frameHandler(CapturedVideoFrame(
            sampleBuffer: sampleBuffer,
            presentationTime: CMSampleBufferGetPresentationTimeStamp(sampleBuffer),
            attachments: attachments
        ))
    }

    private func videoAttachments(from sampleBuffer: CMSampleBuffer) -> [SCStreamFrameInfo: Any]? {
        guard let attachmentsArray = CMSampleBufferGetSampleAttachmentsArray(sampleBuffer, createIfNecessary: false) as? [[SCStreamFrameInfo: Any]] else {
            return nil
        }
        return attachmentsArray.first
    }
}

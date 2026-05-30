import AppKit
import Foundation

actor CaptureSampleRouter {
    private let format: OutputFormat
    private let mp4ExportService: MP4ExportServicing
    private let gifExportService: GIFExportServicing
    private var acceptsSamples = true
    private var inFlightSamples = 0
    private var firstError: CaptureError?

    init(format: OutputFormat, mp4ExportService: MP4ExportServicing, gifExportService: GIFExportServicing) {
        self.format = format
        self.mp4ExportService = mp4ExportService
        self.gifExportService = gifExportService
    }

    func appendVideoFrame(_ frame: CapturedVideoFrame) async {
        guard beginSample() else { return }
        defer { finishSample() }
        do {
            switch format {
            case .mp4:
                try await mp4ExportService.appendVideoFrame(frame)
            case .gif:
                try await gifExportService.appendVideoFrame(frame)
            }
        } catch let error as CaptureError {
            record(error)
        } catch {
            record(CaptureError(
                code: "sample_append_failed",
                message: error.localizedDescription,
                recoveryAction: "Stop the capture and retry. Temporary artifacts will be reported if they were preserved.",
                isRecoverable: true,
                preservedArtifacts: []
            ))
        }
    }

    func appendAudioSample(_ sample: CapturedAudioSample) async {
        guard format == .mp4, beginSample() else { return }
        defer { finishSample() }
        do {
            try await mp4ExportService.appendAudioSample(sample)
        } catch let error as CaptureError {
            record(error)
        } catch {
            record(CaptureError(
                code: "audio_append_failed",
                message: error.localizedDescription,
                recoveryAction: "Stop the capture and retry.",
                isRecoverable: true,
                preservedArtifacts: []
            ))
        }
    }

    func closeAndDrain() async -> CaptureError? {
        acceptsSamples = false
        while inFlightSamples > 0 {
            await Task.yield()
        }
        return firstError
    }

    private func beginSample() -> Bool {
        guard acceptsSamples else { return false }
        inFlightSamples += 1
        return true
    }

    private func finishSample() {
        inFlightSamples = max(0, inFlightSamples - 1)
    }

    private func record(_ error: CaptureError) {
        if firstError == nil { firstError = error }
    }
}

@MainActor
final class CaptureCoordinator: ObservableObject {
    @Published var selectedArea: CaptureArea?
    @Published var outputSettings: OutputSettings
    @Published var state: CaptureSessionState = .idle
    @Published var lastError: CaptureError?
    @Published var savedRecording: SavedRecording?
    @Published var statusMessage = "Ready to select an area"

    private let environment: AppEnvironment
    private var sessionID = UUID()
    private var startedAt: Date?
    private var overlay: SelectionOverlayWindow?
    private var sampleRouter: CaptureSampleRouter?

    init(environment: AppEnvironment) { self.environment = environment; self.outputSettings = environment.settingsStore.load() }

    func selectArea() {
        overlay?.close()
        overlay = nil
        let window = SelectionOverlayWindow { [weak self] area in self?.completeAreaSelection(area) }
        overlay = window; window.makeKeyAndOrderFront(nil); statusMessage = "Drag to choose an area"; state = .idle
    }

    func setSelectedArea(_ area: CaptureArea) { selectedArea = area; _ = transition(to: .areaSelected); statusMessage = "Area selected" }

    private func completeAreaSelection(_ area: CaptureArea) {
        setSelectedArea(area)
        overlay = nil
    }

    func startCapture() async {
        do {
            guard let area = selectedArea, area.isValid else { throw CaptureError.invalidArea() }
            try enforceMainScreenOnly(area)
            guard state == .areaSelected || state == .completed || state == .idle else { throw CaptureError(code: "capture_busy", message: "A capture is already active.", recoveryAction: "Stop or wait for the current capture to finish.", isRecoverable: true, preservedArtifacts: []) }
            if state == .completed || state == .completedWithWarning || state == .idle {
                guard transition(to: .areaSelected) else { throw invalidTransitionError(to: .areaSelected) }
            }
            guard transition(to: .validating) else { throw invalidTransitionError(to: .validating) }
            try outputSettings.validateFolders()
            try environment.artifactStoreFactory(outputSettings.temporaryFolderURL).validate()
            let shouldCaptureAudio = outputSettings.shouldCaptureSystemAudio()
            let permission = environment.permissionService.currentStatus(requireAudio: shouldCaptureAudio)
            guard permission.canRecordScreen else { throw CaptureError.permissionDenied(permission.recoveryMessage ?? "Screen Recording permission is denied.") }
            if shouldCaptureAudio, permission.systemAudioCapture != .granted {
                throw CaptureError.permissionDenied(permission.recoveryMessage ?? "System audio capture permission is denied.")
            }
            if outputSettings.format == .mp4 { try await environment.mp4ExportService.validateCapabilities(for: outputSettings) }
            sessionID = UUID(); startedAt = Date(); savedRecording = nil; lastError = nil
            try await beginExportSession()
            configureSampleRouting(for: outputSettings.format)
            try await environment.screenCaptureService.start(area: area)
            try await environment.audioCaptureService.startIfNeeded(shouldCaptureAudio: shouldCaptureAudio)
            guard transition(to: .recording) else { throw invalidTransitionError(to: .recording) }
            statusMessage = shouldCaptureAudio ? "Recording selected area with system audio" : "Recording selected area"
        } catch let err as CaptureError {
            await abortFailedStart()
            fail(err)
        } catch {
            await abortFailedStart()
            fail(CaptureError(code: "start_failed", message: error.localizedDescription, recoveryAction: "Check permissions and output settings, then retry.", isRecoverable: true, preservedArtifacts: []))
        }
    }

    func stopCapture() async {
        guard state == .recording else { fail(CaptureError(code: "not_recording", message: "No recording is active.", recoveryAction: "Press Start Capture before Stop Capture.", isRecoverable: true, preservedArtifacts: [])); return }
        guard transition(to: .stopping) else { fail(invalidTransitionError(to: .stopping)); return }
        let router = sampleRouter
        sampleRouter = nil
        clearSampleRouting()
        let routingError = await router?.closeAndDrain()
        await environment.screenCaptureService.stop()
        await environment.audioCaptureService.stop()
        guard transition(to: .finalizing) else { fail(invalidTransitionError(to: .finalizing)); return }
        do {
            let stoppedAt = Date(); let started = startedAt ?? stoppedAt
            if let routingError { throw routingError }
            let saved: SavedRecording
            switch outputSettings.format {
            case .mp4:
                saved = try await environment.mp4ExportService.finalize(sessionID: sessionID, settings: outputSettings, startedAt: started, stoppedAt: stoppedAt)
            case .gif:
                saved = try await environment.gifExportService.finalize(sessionID: sessionID, settings: outputSettings, startedAt: started, stoppedAt: stoppedAt)
            }
            savedRecording = saved
            guard transition(to: .completed) else { throw invalidTransitionError(to: .completed) }
            statusMessage = "Saved: \(saved.fileURL.path)"
        } catch let err as CaptureError { fail(err) } catch { fail(CaptureError(code: "finalize_failed", message: error.localizedDescription, recoveryAction: "Check disk space and destination folder, then retry.", isRecoverable: true, preservedArtifacts: [])) }
    }

    func saveSettings() { environment.settingsStore.save(outputSettings) }
    func revealSavedFile() { if let url = savedRecording?.fileURL { NSWorkspace.shared.activateFileViewerSelecting([url]) } }
    func copySavedPath() { if let path = savedRecording?.fileURL.path { NSPasteboard.general.clearContents(); NSPasteboard.general.setString(path, forType: .string) } }

    private func beginExportSession() async throws {
        let start = startedAt ?? Date()
        switch outputSettings.format {
        case .mp4:
            let videoSize = selectedArea?.pixelRect.integral.size ?? CGSize(width: 64, height: 64)
            try await environment.mp4ExportService.begin(sessionID: sessionID, settings: outputSettings, startedAt: start, videoSize: videoSize)
        case .gif:
            try await environment.gifExportService.begin(sessionID: sessionID, settings: outputSettings, startedAt: start)
        }
    }

    private func configureSampleRouting(for format: OutputFormat) {
        let router = CaptureSampleRouter(format: format, mp4ExportService: environment.mp4ExportService, gifExportService: environment.gifExportService)
        sampleRouter = router

        environment.screenCaptureService.setVideoFrameHandler { frame in
            Task { await router.appendVideoFrame(frame) }
        }

        environment.audioCaptureService.setAudioSampleHandler { sample in
            Task { await router.appendAudioSample(sample) }
        }
    }

    private func clearSampleRouting() {
        environment.screenCaptureService.setVideoFrameHandler(nil)
        environment.audioCaptureService.setAudioSampleHandler(nil)
    }

    private func abortFailedStart() async {
        let router = sampleRouter
        sampleRouter = nil
        clearSampleRouting()
        _ = await router?.closeAndDrain()
        await environment.screenCaptureService.stop()
        await environment.audioCaptureService.stop()
        await environment.mp4ExportService.cancel()
        await environment.gifExportService.cancel()
    }

    private func enforceMainScreenOnly(_ area: CaptureArea) throws {
        guard area.displayID == CGMainDisplayID() else {
            throw CaptureError(
                code: "secondary_display_unsupported",
                message: "Capture is currently limited to the main screen.",
                recoveryAction: "Move the content to the main screen and select the area again.",
                isRecoverable: true,
                preservedArtifacts: []
            )
        }
    }

    @discardableResult
    private func transition(to next: CaptureSessionState) -> Bool {
        guard state.canTransition(to: next) || state == next || next == .areaSelected else { return false }
        state = next
        return true
    }

    private func invalidTransitionError(to next: CaptureSessionState) -> CaptureError {
        CaptureError(
            code: "invalid_state_transition",
            message: "Cannot transition from \(state.rawValue) to \(next.rawValue).",
            recoveryAction: "Select an area again and retry the capture.",
            isRecoverable: true,
            preservedArtifacts: []
        )
    }

    private func fail(_ error: CaptureError) { clearSampleRouting(); lastError = error; state = .error; statusMessage = error.message }
}

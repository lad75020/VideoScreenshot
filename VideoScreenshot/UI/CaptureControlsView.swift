import SwiftUI

struct CaptureControlsView: View {
    @EnvironmentObject var coordinator: CaptureCoordinator
    @State private var elapsed: TimeInterval = 0
    @State private var timerStart: Date?

    private let timer = Timer.publish(every: 0.1, on: .main, in: .common).autoconnect()

    private var canStart: Bool {
        coordinator.selectedArea?.isValid == true
            && coordinator.state != .recording
            && coordinator.state != .finalizing
            && coordinator.state != .stopping
            && coordinator.state != .validating
    }

    private var isRecording: Bool { coordinator.state == .recording }
    private var isBusy: Bool {
        coordinator.state == .validating
            || coordinator.state == .stopping
            || coordinator.state == .finalizing
    }

    var body: some View {
        SectionCard(title: "Recording", systemImage: "record.circle") {
            VStack(alignment: .center, spacing: 12) {
                recordButton
                VStack(alignment: .center, spacing: 4) {
                    Text(primaryLabel)
                        .font(.system(size: 13, weight: .semibold))
                        .multilineTextAlignment(.center)
                    Text(secondaryLabel)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if isRecording {
                    timerView
                }
            }
            .frame(maxWidth: .infinity)
        }
        .onReceive(timer) { _ in
            if isRecording, let start = timerStart {
                elapsed = Date().timeIntervalSince(start)
            }
        }
        .onChange(of: coordinator.state) { _, newState in
            if newState == .recording {
                timerStart = Date()
                elapsed = 0
            } else if newState != .recording {
                timerStart = nil
            }
        }
    }

    private var recordButton: some View {
        Button {
            Task {
                if isRecording {
                    await coordinator.stopCapture()
                } else {
                    await coordinator.startCapture()
                }
            }
        } label: {
            ZStack {
                Circle()
                    .fill(buttonFillGradient)
                    .frame(width: 64, height: 64)
                    .shadow(color: shadowColor, radius: 10, x: 0, y: 4)

                if isRecording {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(Color.white)
                        .frame(width: 22, height: 22)
                } else if isBusy {
                    ProgressView()
                        .controlSize(.small)
                        .tint(.white)
                } else {
                    Circle()
                        .fill(Color.white)
                        .frame(width: 22, height: 22)
                }
            }
            .overlay(
                Circle()
                    .stroke(Color.white.opacity(0.25), lineWidth: 2)
                    .frame(width: 64, height: 64)
            )
        }
        .buttonStyle(.plain)
        .disabled(!isRecording && !canStart)
        .opacity((!isRecording && !canStart) ? 0.5 : 1.0)
        .accessibilityLabel(isRecording ? "Stop Capture" : "Start Capture")
        .help(isRecording ? "Stop recording" : "Start recording")
    }

    private var timerView: some View {
        HStack(spacing: 6) {
            Text("REC")
                .font(.system(size: 10, weight: .bold))
                .tracking(2)
                .foregroundStyle(.red.opacity(0.8))
            Text(formatElapsed(elapsed))
                .font(.system(size: 18, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(.red)
        }
    }

    private var buttonFillGradient: LinearGradient {
        if isRecording {
            return LinearGradient(
                colors: [Color.red, Color.red.opacity(0.75)],
                startPoint: .top,
                endPoint: .bottom
            )
        }
        if isBusy {
            return LinearGradient(
                colors: [Color.orange, Color.orange.opacity(0.75)],
                startPoint: .top,
                endPoint: .bottom
            )
        }
        if canStart {
            return LinearGradient(
                colors: [Color.red.opacity(0.95), Color.red.opacity(0.7)],
                startPoint: .top,
                endPoint: .bottom
            )
        }
        return LinearGradient(
            colors: [Color.gray.opacity(0.6), Color.gray.opacity(0.45)],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    private var shadowColor: Color {
        if isRecording { return Color.red.opacity(0.45) }
        if isBusy { return Color.orange.opacity(0.35) }
        if canStart { return Color.red.opacity(0.3) }
        return Color.black.opacity(0.12)
    }

    private var primaryLabel: String {
        if isRecording { return "Recording in progress" }
        if coordinator.state == .validating { return "Validating…" }
        if coordinator.state == .stopping { return "Stopping…" }
        if coordinator.state == .finalizing { return "Finalizing capture…" }
        if canStart { return "Ready to record" }
        return "Select an area to begin"
    }

    private var secondaryLabel: String {
        if isRecording { return "Click the stop button to end the capture." }
        if isBusy { return "Please wait while the capture completes." }
        if canStart { return "Click the record button to start capturing." }
        return "Use the Select Area button above to choose a region."
    }

    private func formatElapsed(_ interval: TimeInterval) -> String {
        let total = Int(interval)
        let h = total / 3600
        let m = (total % 3600) / 60
        let s = total % 60
        if h > 0 {
            return String(format: "%d:%02d:%02d", h, m, s)
        }
        return String(format: "%02d:%02d", m, s)
    }
}

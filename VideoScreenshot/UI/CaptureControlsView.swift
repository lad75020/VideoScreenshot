import SwiftUI

struct CaptureControlsView: View {
    @EnvironmentObject var coordinator: CaptureCoordinator
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
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
        SectionCard(title: "Recording", subtitle: shortcutHint, systemImage: isRecording ? "record.circle.fill" : "record.circle") {
            VStack(spacing: 16) {
                recordButton

                VStack(spacing: 5) {
                    Text(primaryLabel)
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .multilineTextAlignment(.center)
                    Text(secondaryLabel)
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Divider().opacity(0.5)

                VStack(spacing: 10) {
                    recorderMetric(title: "Elapsed", value: isRecording ? formatElapsed(elapsed) : "00:00", systemImage: "timer")
                    recorderMetric(title: "Format", value: coordinator.outputSettings.format.rawValue.uppercased(), systemImage: "film")
                    recorderMetric(title: "Audio", value: coordinator.outputSettings.shouldCaptureSystemAudio() ? "System" : "Off", systemImage: "speaker.wave.2")
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
            VStack(spacing: 11) {
                ZStack {
                    Circle()
                        .fill(buttonHaloColor.opacity(0.14))
                        .frame(width: 102, height: 102)
                    Circle()
                        .fill(buttonFillGradient)
                        .frame(width: 78, height: 78)
                        .shadow(color: shadowColor, radius: 18, x: 0, y: 9)

                    if isRecording {
                        RoundedRectangle(cornerRadius: 7, style: .continuous)
                            .fill(Color.white)
                            .frame(width: 25, height: 25)
                    } else if isBusy {
                        ProgressView()
                            .controlSize(.small)
                            .tint(.white)
                    } else {
                        Circle()
                            .fill(Color.white)
                            .frame(width: 25, height: 25)
                    }
                }
                .overlay {
                    if isRecording && !reduceMotion {
                        Circle()
                            .stroke(Color.red.opacity(0.32), lineWidth: 5)
                            .frame(width: 78, height: 78)
                            .scaleEffect(1.45)
                            .opacity(0)
                            .animation(.easeOut(duration: 1.2).repeatForever(autoreverses: false), value: isRecording)
                    }
                }

                Text(isRecording ? "Stop Recording" : "Start Recording")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(isRecording || canStart ? .primary : .secondary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .keyboardShortcut("r", modifiers: [.command])
        .disabled(!isRecording && !canStart)
        .opacity((!isRecording && !canStart) ? 0.55 : 1.0)
        .animation(reduceMotion ? nil : .spring(response: 0.32, dampingFraction: 0.82), value: isRecording)
        .accessibilityLabel(isRecording ? "Stop Capture" : "Start Capture")
        .help(isRecording ? "Stop recording (⌘R)" : "Start recording (⌘R)")
    }

    private func recorderMetric(title: String, value: String, systemImage: String) -> some View {
        HStack(spacing: 9) {
            Image(systemName: systemImage)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.secondary)
                .frame(width: 18)
            Text(title)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(value == "Off" ? .secondary : .primary)
        }
        .padding(.horizontal, 11)
        .padding(.vertical, 8)
        .background(Color.primary.opacity(0.045), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private var shortcutHint: String {
        isRecording ? "⌘R stops capture" : "⌘R starts capture"
    }

    private var buttonFillGradient: LinearGradient {
        if isRecording {
            return LinearGradient(colors: [Color.red, Color.red.opacity(0.74)], startPoint: .top, endPoint: .bottom)
        }
        if isBusy {
            return LinearGradient(colors: [Color.orange, Color.orange.opacity(0.72)], startPoint: .top, endPoint: .bottom)
        }
        if canStart {
            return LinearGradient(colors: [Color.red.opacity(0.95), Color.red.opacity(0.68)], startPoint: .top, endPoint: .bottom)
        }
        return LinearGradient(colors: [Color.gray.opacity(0.58), Color.gray.opacity(0.38)], startPoint: .top, endPoint: .bottom)
    }

    private var buttonHaloColor: Color {
        if isRecording { return .red }
        if isBusy { return .orange }
        if canStart { return .red }
        return .secondary
    }

    private var shadowColor: Color {
        if isRecording { return Color.red.opacity(0.42) }
        if isBusy { return Color.orange.opacity(0.32) }
        if canStart { return Color.red.opacity(0.28) }
        return Color.black.opacity(0.10)
    }

    private var primaryLabel: String {
        if isRecording { return "Recording in progress" }
        if coordinator.state == .validating { return "Checking permissions…" }
        if coordinator.state == .stopping { return "Stopping streams…" }
        if coordinator.state == .finalizing { return "Writing final file…" }
        if canStart { return "Ready to record" }
        return "Select an area to begin"
    }

    private var secondaryLabel: String {
        if isRecording { return "The selected region is being captured at 24 fps." }
        if isBusy { return "Keep the app open while the current operation completes." }
        if canStart { return "Press the record button or use the keyboard shortcut." }
        return "Choose a main-screen region before starting."
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

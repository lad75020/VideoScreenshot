import SwiftUI

struct StatusView: View {
    @EnvironmentObject var coordinator: CaptureCoordinator

    var body: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(Color.primary.opacity(0.08))
                .frame(height: 0.5)

            HStack(alignment: .center, spacing: 12) {
                statusIcon
                    .frame(width: 30, height: 30)
                    .background(iconBackground, in: Circle())

                VStack(alignment: .leading, spacing: 3) {
                    Text(coordinator.statusMessage)
                        .font(.system(size: 12, weight: .medium))
                        .textSelection(.enabled)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityLabel("Capture status")

                    if let error = coordinator.lastError {
                        Text(error.recoveryAction)
                            .font(.system(size: 11))
                            .foregroundStyle(.red)
                            .textSelection(.enabled)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                Spacer(minLength: 12)

                if let recording = coordinator.savedRecording {
                    HStack(spacing: 8) {
                        Text(fileSummary(recording))
                            .font(.system(size: 11, weight: .medium, design: .monospaced))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)

                        Button {
                            coordinator.copySavedPath()
                        } label: {
                            Label("Copy Path", systemImage: "doc.on.doc")
                        }
                        .controlSize(.small)
                        .accessibilityLabel("Copy saved path")

                        Button {
                            coordinator.revealSavedFile()
                        } label: {
                            Label("Reveal", systemImage: "folder")
                        }
                        .controlSize(.small)
                        .buttonStyle(.borderedProminent)
                        .accessibilityLabel("Reveal File")
                    }
                    .transition(.opacity.combined(with: .move(edge: .trailing)))
                }
            }
            .padding(.horizontal, 22)
            .padding(.vertical, 12)
        }
        .background(.ultraThinMaterial)
        .animation(.easeInOut(duration: 0.2), value: coordinator.savedRecording?.id)
        .animation(.easeInOut(duration: 0.2), value: coordinator.state)
    }

    private var iconBackground: Color {
        switch coordinator.state {
        case .error, .recording: return .red.opacity(0.13)
        case .completed, .completedWithWarning: return .green.opacity(0.13)
        case .validating, .stopping, .finalizing: return .orange.opacity(0.13)
        case .areaSelected: return .blue.opacity(0.13)
        case .idle: return .secondary.opacity(0.11)
        }
    }

    @ViewBuilder
    private var statusIcon: some View {
        switch coordinator.state {
        case .error:
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.red)
        case .completed, .completedWithWarning:
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.green)
        case .recording:
            Image(systemName: "record.circle.fill")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.red)
        case .validating, .stopping, .finalizing:
            ProgressView().controlSize(.small)
        case .areaSelected:
            Image(systemName: "checkmark.circle")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.blue)
        case .idle:
            Image(systemName: "info.circle")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.secondary)
        }
    }

    private func fileSummary(_ recording: SavedRecording) -> String {
        let size = ByteCountFormatter.string(fromByteCount: recording.fileSizeBytes, countStyle: .file)
        return "\(recording.format.rawValue.uppercased()) · \(size)"
    }
}

import SwiftUI

struct StatusView: View {
    @EnvironmentObject var coordinator: CaptureCoordinator

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Divider()
            HStack(alignment: .top, spacing: 12) {
                statusIcon
                    .frame(width: 24, height: 24)

                VStack(alignment: .leading, spacing: 4) {
                    Text(coordinator.statusMessage)
                        .font(.system(size: 12, weight: .medium))
                        .textSelection(.enabled)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityLabel("Capture status")

                    if let error = coordinator.lastError {
                        Text("Recovery: \(error.recoveryAction)")
                            .font(.system(size: 11))
                            .foregroundStyle(.red)
                            .textSelection(.enabled)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                Spacer(minLength: 8)

                if coordinator.savedRecording != nil {
                    HStack(spacing: 8) {
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
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 14)
        }
        .background(.ultraThinMaterial)
    }

    @ViewBuilder
    private var statusIcon: some View {
        switch coordinator.state {
        case .error:
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 18))
                .foregroundStyle(.red)
        case .completed, .completedWithWarning:
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 18))
                .foregroundStyle(.green)
        case .recording:
            Image(systemName: "record.circle.fill")
                .font(.system(size: 18))
                .foregroundStyle(.red)
        case .validating, .stopping, .finalizing:
            ProgressView().controlSize(.small)
        case .areaSelected:
            Image(systemName: "checkmark.circle")
                .font(.system(size: 18))
                .foregroundStyle(.blue)
        case .idle:
            Image(systemName: "info.circle")
                .font(.system(size: 18))
                .foregroundStyle(.secondary)
        }
    }
}

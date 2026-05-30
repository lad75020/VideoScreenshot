import SwiftUI

struct MainWindowView: View {
    @EnvironmentObject var coordinator: CaptureCoordinator

    var body: some View {
        ZStack {
            backgroundGradient.ignoresSafeArea()

            VStack(spacing: 0) {
                HeaderView()
                    .environmentObject(coordinator)

                ScrollView {
                    VStack(spacing: 18) {
                        HStack(alignment: .top, spacing: 18) {
                            CaptureAreaCard().environmentObject(coordinator)
                            CaptureControlsView().environmentObject(coordinator)
                                .frame(width: 240)
                        }
                        SettingsView().environmentObject(coordinator)
                    }
                    .padding(.horizontal, 28)
                    .padding(.vertical, 22)
                }

                StatusView().environmentObject(coordinator)
            }
        }
        .frame(minWidth: 620, minHeight: 560)
        .accessibilityLabel("VideoScreenshot main window")
    }

    private var backgroundGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color(nsColor: .windowBackgroundColor),
                Color(nsColor: .underPageBackgroundColor)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }
}

private struct HeaderView: View {
    @EnvironmentObject var coordinator: CaptureCoordinator

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(LinearGradient(
                        colors: [Color.accentColor.opacity(0.9), Color.accentColor.opacity(0.55)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))
                    .frame(width: 44, height: 44)
                Image(systemName: "rectangle.dashed.badge.record")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(.white)
            }
            .shadow(color: Color.accentColor.opacity(0.35), radius: 8, x: 0, y: 4)

            VStack(alignment: .leading, spacing: 2) {
                Text("VideoScreenshot")
                    .font(.system(size: 18, weight: .semibold))
                Text("Record a region of your screen to MP4 or animated GIF")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            StateBadge(state: coordinator.state)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 18)
        .background(.ultraThinMaterial)
        .overlay(Divider(), alignment: .bottom)
    }
}

struct StateBadge: View {
    let state: CaptureSessionState

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
                .overlay(
                    Circle()
                        .stroke(color.opacity(0.35), lineWidth: 4)
                        .scaleEffect(state == .recording ? 1.8 : 1.0)
                        .opacity(state == .recording ? 0 : 1)
                        .animation(
                            state == .recording
                                ? .easeOut(duration: 1.1).repeatForever(autoreverses: false)
                                : .default,
                            value: state
                        )
                )
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.primary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(
            Capsule().fill(color.opacity(0.12))
        )
        .overlay(
            Capsule().stroke(color.opacity(0.25), lineWidth: 0.5)
        )
        .accessibilityLabel("Capture state \(label)")
    }

    private var color: Color {
        switch state {
        case .idle: return .secondary
        case .areaSelected: return .blue
        case .validating, .stopping, .finalizing: return .orange
        case .recording: return .red
        case .completed, .completedWithWarning: return .green
        case .error: return .red
        }
    }

    private var label: String {
        switch state {
        case .idle: return "Idle"
        case .areaSelected: return "Ready"
        case .validating: return "Validating"
        case .recording: return "Recording"
        case .stopping: return "Stopping"
        case .finalizing: return "Finalizing"
        case .completed: return "Completed"
        case .completedWithWarning: return "Completed (warning)"
        case .error: return "Error"
        }
    }
}

private struct CaptureAreaCard: View {
    @EnvironmentObject var coordinator: CaptureCoordinator

    var body: some View {
        SectionCard(title: "Capture Area", systemImage: "viewfinder") {
            HStack(alignment: .center, spacing: 16) {
                if let area = coordinator.selectedArea, area.isValid {
                    selectedPreview(area: area)
                } else {
                    emptyPreview
                }

                VStack(alignment: .leading, spacing: 8) {
                    if let area = coordinator.selectedArea, area.isValid {
                        Text("\(Int(area.pixelRect.width)) × \(Int(area.pixelRect.height)) px")
                            .font(.system(size: 15, weight: .semibold, design: .rounded))
                            .monospacedDigit()
                        Text("Display #\(area.displayID) · scale \(String(format: "%.1f", area.displayScale))×")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    } else {
                        Text("No region selected")
                            .font(.system(size: 14, weight: .semibold))
                        Text("Choose a rectangular area of your screen to record.")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer(minLength: 0)

                    Button {
                        coordinator.selectArea()
                    } label: {
                        Label(
                            coordinator.selectedArea?.isValid == true ? "Reselect Area" : "Select Area",
                            systemImage: "rectangle.dashed"
                        )
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.regular)
                    .disabled(coordinator.state == .recording || coordinator.state == .finalizing)
                    .accessibilityLabel("Select Area")
                }
            }
        }
    }

    private var emptyPreview: some View {
        RoundedRectangle(cornerRadius: 10, style: .continuous)
            .strokeBorder(
                style: StrokeStyle(lineWidth: 1.5, dash: [6, 4])
            )
            .foregroundStyle(Color.secondary.opacity(0.4))
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color(nsColor: .controlBackgroundColor).opacity(0.4))
            )
            .frame(width: 140, height: 90)
            .overlay(
                Image(systemName: "rectangle.dashed")
                    .font(.system(size: 26, weight: .light))
                    .foregroundStyle(.secondary)
            )
    }

    private func selectedPreview(area: CaptureArea) -> some View {
        let aspect = max(area.pixelRect.width / max(area.pixelRect.height, 1), 0.1)
        let height: CGFloat = 90
        let width = min(max(height * aspect, 80), 180)
        return RoundedRectangle(cornerRadius: 10, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [Color.accentColor.opacity(0.35), Color.accentColor.opacity(0.15)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .frame(width: width, height: height)
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(Color.accentColor.opacity(0.7), lineWidth: 1)
            )
            .overlay(
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 22))
                    .foregroundStyle(.white, Color.accentColor)
            )
    }
}

struct SectionCard<Content: View>: View {
    let title: String
    let systemImage: String
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Image(systemName: systemImage)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)
                Text(title)
                    .font(.system(size: 12, weight: .semibold))
                    .textCase(.uppercase)
                    .foregroundStyle(.secondary)
                    .tracking(0.6)
            }
            content()
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor).opacity(0.7))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.primary.opacity(0.08), lineWidth: 0.5)
        )
        .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 2)
    }
}

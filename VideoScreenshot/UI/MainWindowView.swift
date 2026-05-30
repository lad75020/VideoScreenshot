import SwiftUI

struct MainWindowView: View {
    @EnvironmentObject var coordinator: CaptureCoordinator

    var body: some View {
        ZStack {
            appBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                HeaderView()
                    .environmentObject(coordinator)

                ScrollView {
                    HStack(alignment: .top, spacing: 20) {
                        VStack(spacing: 20) {
                            CaptureAreaCard().environmentObject(coordinator)
                            SettingsView().environmentObject(coordinator)
                        }
                        .frame(maxWidth: .infinity, alignment: .top)

                        CaptureControlsView().environmentObject(coordinator)
                            .frame(width: 280)
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 22)
                }

                StatusView().environmentObject(coordinator)
            }
        }
        .frame(minWidth: 760, minHeight: 620)
        .accessibilityLabel("VideoScreenshot main window")
    }

    private var appBackground: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(nsColor: .windowBackgroundColor),
                    Color(nsColor: .controlBackgroundColor).opacity(0.82)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            Circle()
                .fill(Color.accentColor.opacity(0.11))
                .blur(radius: 64)
                .frame(width: 340, height: 340)
                .offset(x: -320, y: -220)
            Circle()
                .fill(Color.blue.opacity(0.08))
                .blur(radius: 72)
                .frame(width: 360, height: 360)
                .offset(x: 360, y: 260)
        }
    }
}

private struct HeaderView: View {
    @EnvironmentObject var coordinator: CaptureCoordinator

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            AppGlyph()

            VStack(alignment: .leading, spacing: 3) {
                Text("VideoScreenshot")
                    .font(.system(size: 20, weight: .semibold, design: .rounded))
                    .foregroundStyle(.primary)
                Text("Screen-area recording for MP4 and animated GIF")
                    .font(.system(size: 12, weight: .regular))
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 20)

            HeaderMetric(label: "Format", value: coordinator.outputSettings.format.rawValue.uppercased(), systemImage: "doc.badge.gearshape")
            HeaderMetric(label: "Audio", value: coordinator.outputSettings.shouldCaptureSystemAudio() ? "On" : "Off", systemImage: "speaker.wave.2")
            StateBadge(state: coordinator.state)
        }
        .padding(.leading, 22)
        .padding(.trailing, 24)
        .padding(.vertical, 14)
        .background(.ultraThinMaterial)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Color.primary.opacity(0.08))
                .frame(height: 0.5)
        }
    }
}

private struct AppGlyph: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color.accentColor, Color.accentColor.opacity(0.58)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 42, height: 42)
            Image(systemName: "rectangle.dashed.badge.record")
                .font(.system(size: 21, weight: .semibold))
                .foregroundStyle(.white)
        }
        .shadow(color: Color.accentColor.opacity(0.28), radius: 10, x: 0, y: 5)
        .accessibilityHidden(true)
    }
}

private struct HeaderMetric: View {
    let label: String
    let value: String
    let systemImage: String

    var body: some View {
        HStack(spacing: 7) {
            Image(systemName: systemImage)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 1) {
                Text(label)
                    .font(.system(size: 9, weight: .medium))
                    .textCase(.uppercase)
                    .tracking(0.6)
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(.primary)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(.thinMaterial, in: Capsule(style: .continuous))
        .overlay(Capsule(style: .continuous).stroke(Color.primary.opacity(0.08), lineWidth: 0.5))
    }
}

struct StateBadge: View {
    let state: CaptureSessionState
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: 7) {
            ZStack {
                Circle()
                    .fill(color)
                    .frame(width: 9, height: 9)
                if state == .recording && !reduceMotion {
                    Circle()
                        .stroke(color.opacity(0.35), lineWidth: 4)
                        .frame(width: 9, height: 9)
                        .scaleEffect(2.0)
                        .opacity(0)
                        .animation(.easeOut(duration: 1.15).repeatForever(autoreverses: false), value: state)
                }
            }
            Text(label)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(.primary)
        }
        .padding(.horizontal, 11)
        .padding(.vertical, 7)
        .background(color.opacity(0.13), in: Capsule(style: .continuous))
        .overlay(Capsule(style: .continuous).stroke(color.opacity(0.28), lineWidth: 0.5))
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
        case .completedWithWarning: return "Completed"
        case .error: return "Error"
        }
    }
}

private struct CaptureAreaCard: View {
    @EnvironmentObject var coordinator: CaptureCoordinator

    var body: some View {
        SectionCard(title: "Capture Area", subtitle: "Main screen only · rectangular region", systemImage: "viewfinder") {
            HStack(alignment: .center, spacing: 20) {
                if let area = coordinator.selectedArea, area.isValid {
                    selectedPreview(area: area)
                } else {
                    emptyPreview
                }

                VStack(alignment: .leading, spacing: 14) {
                    captureDescription

                    if let area = coordinator.selectedArea, area.isValid {
                        HStack(spacing: 8) {
                            InfoPill(title: "Size", value: "\(Int(area.pixelRect.width)) × \(Int(area.pixelRect.height)) px")
                            InfoPill(title: "Scale", value: "\(String(format: "%.1f", area.displayScale))×")
                            InfoPill(title: "Display", value: "Main")
                        }
                    }

                    Button {
                        coordinator.selectArea()
                    } label: {
                        Label(coordinator.selectedArea?.isValid == true ? "Reselect Area" : "Select Area", systemImage: "rectangle.dashed")
                            .frame(minWidth: 132)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .keyboardShortcut("a", modifiers: [.command, .shift])
                    .disabled(coordinator.state == .recording || coordinator.state == .finalizing)
                    .accessibilityLabel("Select Area")
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    @ViewBuilder
    private var captureDescription: some View {
        if let area = coordinator.selectedArea, area.isValid {
            VStack(alignment: .leading, spacing: 4) {
                Text("Region locked")
                    .font(.system(size: 17, weight: .semibold, design: .rounded))
                Text("Ready to capture a \(Int(area.pixelRect.width)) by \(Int(area.pixelRect.height)) pixel region on the main display.")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        } else {
            VStack(alignment: .leading, spacing: 4) {
                Text("Choose what to record")
                    .font(.system(size: 17, weight: .semibold, design: .rounded))
                Text("Drag over the main screen to define the exact region. The app keeps the rest of your desktop out of the recording.")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var emptyPreview: some View {
        RoundedRectangle(cornerRadius: 18, style: .continuous)
            .fill(.thinMaterial)
            .frame(width: 230, height: 140)
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(style: StrokeStyle(lineWidth: 1.5, dash: [7, 5]))
                    .foregroundStyle(Color.secondary.opacity(0.38))
                    .padding(18)
            }
            .overlay {
                VStack(spacing: 8) {
                    Image(systemName: "rectangle.dashed")
                        .font(.system(size: 32, weight: .light))
                    Text("No area selected")
                        .font(.system(size: 12, weight: .medium))
                }
                .foregroundStyle(.secondary)
            }
            .shadow(color: Color.black.opacity(0.05), radius: 12, x: 0, y: 6)
    }

    private func selectedPreview(area: CaptureArea) -> some View {
        let aspect = max(area.pixelRect.width / max(area.pixelRect.height, 1), 0.2)
        let height: CGFloat = 140
        let width = min(max(height * aspect, 130), 250)
        return ZStack {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(.thinMaterial)
                .frame(width: 250, height: height)
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color.accentColor.opacity(0.34), Color.blue.opacity(0.14)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: width, height: height - 30)
                .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Color.accentColor.opacity(0.68), lineWidth: 1))
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 25, weight: .semibold))
                .foregroundStyle(.white, Color.accentColor)
        }
        .shadow(color: Color.accentColor.opacity(0.12), radius: 16, x: 0, y: 8)
    }
}

private struct InfoPill: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.system(size: 9, weight: .medium))
                .textCase(.uppercase)
                .tracking(0.5)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(.primary)
                .lineLimit(1)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(Color.primary.opacity(0.045), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
    }
}

struct SectionCard<Content: View>: View {
    let title: String
    var subtitle: String? = nil
    let systemImage: String
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .center, spacing: 10) {
                Image(systemName: systemImage)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.accentColor)
                    .frame(width: 28, height: 28)
                    .background(Color.accentColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(.primary)
                    if let subtitle {
                        Text(subtitle)
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer(minLength: 0)
            }

            content()
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.primary.opacity(0.08), lineWidth: 0.5)
        )
        .shadow(color: Color.black.opacity(0.055), radius: 16, x: 0, y: 8)
    }
}

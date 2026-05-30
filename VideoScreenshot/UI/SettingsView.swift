import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var coordinator: CaptureCoordinator

    private var isLocked: Bool {
        coordinator.state == .recording || coordinator.state == .finalizing
    }

    var body: some View {
        SectionCard(title: "Output", subtitle: "Filename, export format, and destinations", systemImage: "slider.horizontal.3") {
            VStack(alignment: .leading, spacing: 12) {
                settingRow(icon: "doc.badge.gearshape", title: "Format", detail: "Choose MP4 video or GIF animation") {
                    Picker("Output Format", selection: $coordinator.outputSettings.format) {
                        ForEach(OutputFormat.allCases) { format in
                            Text(format.rawValue.uppercased()).tag(format)
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .frame(width: 210)
                    .accessibilityLabel("Output format picker")
                }

                settingRow(icon: "speaker.wave.2", title: "System Audio", detail: "Opt-in audio track for MP4 recordings") {
                    Toggle("Record System Audio", isOn: $coordinator.outputSettings.recordSystemAudio)
                        .toggleStyle(.switch)
                        .labelsHidden()
                        .disabled(coordinator.outputSettings.format != .mp4)
                        .opacity(coordinator.outputSettings.format == .mp4 ? 1.0 : 0.45)
                        .help("When enabled, MP4 recordings include system audio. Microphone capture is not used.")
                        .accessibilityLabel("Record system audio")
                }

                settingRow(icon: "textformat", title: "File Name", detail: "Final filename without extension") {
                    HStack(spacing: 6) {
                        TextField("Capture", text: $coordinator.outputSettings.baseFileName)
                            .textFieldStyle(.roundedBorder)
                            .frame(minWidth: 180)
                            .accessibilityLabel("Video file name")
                        Text(".\(coordinator.outputSettings.format.fileExtension)")
                            .font(.system(size: 12, weight: .medium, design: .monospaced))
                            .foregroundStyle(.secondary)
                    }
                }

                Divider().opacity(0.5)

                folderRow(
                    label: "Temporary Folder",
                    systemImage: "folder.badge.gearshape",
                    path: coordinator.outputSettings.temporaryFolderURL.path,
                    action: chooseTemp,
                    accessibility: "Choose temporary data folder"
                )
                folderRow(
                    label: "Output Folder",
                    systemImage: "tray.and.arrow.down",
                    path: coordinator.outputSettings.finalOutputFolderURL.path,
                    action: chooseOutput,
                    accessibility: "Choose final output folder"
                )
            }
        }
        .disabled(isLocked)
        .opacity(isLocked ? 0.56 : 1.0)
        .animation(.easeInOut(duration: 0.18), value: isLocked)
        .onChange(of: coordinator.outputSettings.format) { _, _ in coordinator.saveSettings() }
        .onChange(of: coordinator.outputSettings.recordSystemAudio) { _, _ in coordinator.saveSettings() }
        .onChange(of: coordinator.outputSettings.baseFileName) { _, _ in coordinator.saveSettings() }
    }

    private func settingRow<Accessory: View>(
        icon: String,
        title: String,
        detail: String,
        @ViewBuilder accessory: () -> Accessory
    ) -> some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.secondary)
                .frame(width: 28, height: 28)
                .background(Color.primary.opacity(0.045), in: RoundedRectangle(cornerRadius: 8, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.primary)
                Text(detail)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 16)
            accessory()
        }
        .padding(12)
        .background(Color.primary.opacity(0.035), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func folderRow(
        label: String,
        systemImage: String,
        path: String,
        action: @escaping () -> Void,
        accessibility: String
    ) -> some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: systemImage)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.secondary)
                .frame(width: 28, height: 28)
                .background(Color.primary.opacity(0.045), in: RoundedRectangle(cornerRadius: 8, style: .continuous))

            VStack(alignment: .leading, spacing: 4) {
                Text(label)
                    .font(.system(size: 13, weight: .semibold))
                Text(path)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .help(path)
            }

            Spacer(minLength: 16)
            Button("Choose…", action: action)
                .controlSize(.small)
                .accessibilityLabel(accessibility)
        }
        .padding(12)
        .background(Color.primary.opacity(0.035), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func chooseTemp() {
        if let url = FolderPicker.choose() {
            coordinator.outputSettings.setTemporaryFolder(url)
            coordinator.saveSettings()
        }
    }
    private func chooseOutput() {
        if let url = FolderPicker.choose() {
            coordinator.outputSettings.setFinalOutputFolder(url)
            coordinator.saveSettings()
        }
    }
}

enum FolderPicker {
    @MainActor static func choose() -> URL? {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        return panel.runModal() == .OK ? panel.url : nil
    }
}

import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var coordinator: CaptureCoordinator

    private var isLocked: Bool {
        coordinator.state == .recording || coordinator.state == .finalizing
    }

    var body: some View {
        SectionCard(title: "Output", systemImage: "slider.horizontal.3") {
            VStack(alignment: .leading, spacing: 16) {
                formatPicker
                systemAudioToggle
                Divider().opacity(0.5)
                fileNameField
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
        .opacity(isLocked ? 0.55 : 1.0)
    }

    private var formatPicker: some View {
        HStack(alignment: .center) {
            Label("Format", systemImage: "doc.badge.gearshape")
                .labelStyle(.titleAndIcon)
                .font(.system(size: 13, weight: .medium))
                .frame(width: 150, alignment: .leading)
            Spacer()
            Picker("Output Format", selection: $coordinator.outputSettings.format) {
                ForEach(OutputFormat.allCases) { format in
                    Text(format.rawValue.uppercased()).tag(format)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .frame(maxWidth: 220)
            .accessibilityLabel("Output format picker")
        }
    }

    private var systemAudioToggle: some View {
        Toggle(isOn: $coordinator.outputSettings.recordSystemAudio) {
            Label("Record System Audio", systemImage: "speaker.wave.2")
                .labelStyle(.titleAndIcon)
                .font(.system(size: 13, weight: .medium))
        }
        .toggleStyle(.switch)
        .disabled(coordinator.outputSettings.format != .mp4)
        .opacity(coordinator.outputSettings.format == .mp4 ? 1.0 : 0.55)
        .help("When enabled, MP4 recordings include system audio. Microphone capture is not used.")
        .accessibilityLabel("Record system audio")
    }

    private var fileNameField: some View {
        HStack(alignment: .center) {
            Label("File Name", systemImage: "textformat")
                .labelStyle(.titleAndIcon)
                .font(.system(size: 13, weight: .medium))
                .frame(width: 150, alignment: .leading)
            TextField("Capture", text: $coordinator.outputSettings.baseFileName)
                .textFieldStyle(.roundedBorder)
                .accessibilityLabel("Video file name")
            Text(".\(coordinator.outputSettings.format.fileExtension)")
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(.secondary)
        }
    }

    private func folderRow(
        label: String,
        systemImage: String,
        path: String,
        action: @escaping () -> Void,
        accessibility: String
    ) -> some View {
        HStack(alignment: .center, spacing: 10) {
            Label(label, systemImage: systemImage)
                .labelStyle(.titleAndIcon)
                .font(.system(size: 13, weight: .medium))
                .frame(width: 150, alignment: .leading)
            Text(path)
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(Color.primary.opacity(0.05))
                )
                .help(path)
            Button("Choose…", action: action)
                .controlSize(.small)
                .accessibilityLabel(accessibility)
        }
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

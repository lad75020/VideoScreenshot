import Foundation

final class TemporaryArtifactStore {
    let folderURL: URL
    private(set) var artifacts: [URL] = []
    init(folderURL: URL) { self.folderURL = folderURL }
    func validate(fileManager: FolderAccessChecking = FileManager.default) throws {
        try FolderAccessValidator.validateWritableDirectory(
            at: folderURL,
            fileManager: fileManager,
            errorCode: "invalid_temp_folder",
            errorMessage: "Temporary folder is not writable.",
            recoveryAction: "Choose a writable temporary folder.",
            preservedArtifacts: artifacts
        )
    }
    func register(_ url: URL) { artifacts.append(url) }
    func cleanup(fileManager: FileManager = .default) { for url in artifacts { try? fileManager.removeItem(at: url) }; artifacts.removeAll() }
}

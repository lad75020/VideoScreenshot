import Foundation

struct OutputFileNamer {
    var fileManager: FileManager = .default

    func resolvedURL(for settings: OutputSettings) throws -> URL {
        let url = try settings.finalURL()
        guard fileManager.fileExists(atPath: url.path) else { return url }
        switch settings.overwritePolicy {
        case .ask:
            throw CaptureError(code: "file_exists", message: "A file with this name already exists.", recoveryAction: "Choose Replace, Auto-Rename, Cancel, or enter another file name.", isRecoverable: true, preservedArtifacts: [])
        case .cancel:
            throw CaptureError(code: "save_cancelled", message: "Saving was cancelled because the file exists.", recoveryAction: "Choose a different name or enable auto-rename.", isRecoverable: true, preservedArtifacts: [])
        case .rename:
            return renamedURL(for: url)
        }
    }

    func renamedURL(for url: URL) -> URL {
        let dir = url.deletingLastPathComponent()
        let ext = url.pathExtension
        let base = url.deletingPathExtension().lastPathComponent
        for i in 1...999 {
            let candidate = dir.appendingPathComponent("\(base)-\(i)").appendingPathExtension(ext)
            if !fileManager.fileExists(atPath: candidate.path) { return candidate }
        }
        return dir.appendingPathComponent("\(base)-\(UUID().uuidString)").appendingPathExtension(ext)
    }

    func temporaryURL(for finalURL: URL, in temporaryFolderURL: URL) -> URL {
        let ext = finalURL.pathExtension
        let base = finalURL.deletingPathExtension().lastPathComponent
        return temporaryFolderURL
            .appendingPathComponent(".\(base).\(UUID().uuidString).recording")
            .appendingPathExtension(ext)
    }

    func temporarySiblingURL(for finalURL: URL) -> URL {
        temporaryURL(for: finalURL, in: finalURL.deletingLastPathComponent())
    }

    func commitTemporaryFile(_ temporaryURL: URL, to finalURL: URL) throws {
        guard !fileManager.fileExists(atPath: finalURL.path) else {
            throw CaptureError(
                code: "file_exists",
                message: "A file with this name already exists.",
                recoveryAction: "Choose another file name or enable auto-rename, then retry.",
                isRecoverable: true,
                preservedArtifacts: [temporaryURL]
            )
        }

        do {
            try fileManager.moveItem(at: temporaryURL, to: finalURL)
        } catch {
            throw CaptureError(
                code: "commit_failed",
                message: error.localizedDescription,
                recoveryAction: "Check the output folder and disk space, then retry. The temporary artifact is preserved.",
                isRecoverable: true,
                preservedArtifacts: [temporaryURL]
            )
        }
    }
}

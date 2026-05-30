import Foundation

enum OutputFormat: String, CaseIterable, Codable, Equatable, Identifiable { case mp4, gif; var id: String { rawValue }; var fileExtension: String { self == .mp4 ? "mp4" : "gif" } }
enum OverwritePolicy: String, CaseIterable, Codable, Equatable { case ask, rename, cancel }

protocol FolderAccessChecking {
    func fileExists(atPath path: String, isDirectory: UnsafeMutablePointer<ObjCBool>?) -> Bool
    func createFile(atPath path: String, contents data: Data?, attributes attr: [FileAttributeKey: Any]?) -> Bool
    func removeItem(at URL: URL) throws
}

extension FileManager: FolderAccessChecking {}

protocol SecurityScopeAccessing: AnyObject {
    func startAccessing(_ url: URL) -> Bool
    func stopAccessing(_ url: URL)
}

final class URLSecurityScopeAccessor: SecurityScopeAccessing {
    func startAccessing(_ url: URL) -> Bool { url.startAccessingSecurityScopedResource() }
    func stopAccessing(_ url: URL) { url.stopAccessingSecurityScopedResource() }
}

final class SecurityScopedFolderAccess {
    let folderURL: URL
    let didAccess: Bool
    private let accessor: SecurityScopeAccessing
    private var isStopped = false

    init(folderURL: URL, accessor: SecurityScopeAccessing = URLSecurityScopeAccessor()) {
        self.folderURL = folderURL
        self.accessor = accessor
        self.didAccess = accessor.startAccessing(folderURL)
    }

    func stop() {
        guard didAccess, !isStopped else { return }
        accessor.stopAccessing(folderURL)
        isStopped = true
    }

    deinit { stop() }
}

struct FolderAccessValidator {
    static func validateWritableDirectory(
        at folderURL: URL,
        fileManager: FolderAccessChecking = FileManager.default,
        errorCode: String,
        errorMessage: String,
        recoveryAction: String,
        preservedArtifacts: [URL] = []
    ) throws {
        var isDir: ObjCBool = false
        guard fileManager.fileExists(atPath: folderURL.path, isDirectory: &isDir), isDir.boolValue else {
            throw CaptureError(code: errorCode, message: errorMessage, recoveryAction: recoveryAction, isRecoverable: true, preservedArtifacts: preservedArtifacts)
        }

        let didAccess = folderURL.startAccessingSecurityScopedResource()
        defer { if didAccess { folderURL.stopAccessingSecurityScopedResource() } }

        let probeURL = folderURL.appendingPathComponent(".videoscreenshot-write-probe-\(UUID().uuidString)")
        guard fileManager.createFile(atPath: probeURL.path, contents: Data(), attributes: nil) else {
            throw CaptureError(code: errorCode, message: errorMessage, recoveryAction: recoveryAction, isRecoverable: true, preservedArtifacts: preservedArtifacts)
        }
        try? fileManager.removeItem(at: probeURL)
    }
}

struct OutputSettings: Equatable, Codable {
    var format: OutputFormat
    var recordSystemAudio: Bool
    var temporaryFolderURL: URL
    var finalOutputFolderURL: URL
    var temporaryFolderBookmarkData: Data?
    var finalOutputFolderBookmarkData: Data?
    var baseFileName: String
    var overwritePolicy: OverwritePolicy
    var validatedAt: Date?

    init(
        format: OutputFormat,
        recordSystemAudio: Bool = false,
        temporaryFolderURL: URL,
        finalOutputFolderURL: URL,
        temporaryFolderBookmarkData: Data? = nil,
        finalOutputFolderBookmarkData: Data? = nil,
        baseFileName: String,
        overwritePolicy: OverwritePolicy,
        validatedAt: Date? = nil
    ) {
        self.format = format
        self.recordSystemAudio = recordSystemAudio
        self.temporaryFolderURL = temporaryFolderURL
        self.finalOutputFolderURL = finalOutputFolderURL
        self.temporaryFolderBookmarkData = temporaryFolderBookmarkData
        self.finalOutputFolderBookmarkData = finalOutputFolderBookmarkData
        self.baseFileName = baseFileName
        self.overwritePolicy = overwritePolicy
        self.validatedAt = validatedAt
    }

    static var defaultValue: OutputSettings {
        let movies = FileManager.default.urls(for: .moviesDirectory, in: .userDomainMask).first ?? URL(fileURLWithPath: NSTemporaryDirectory())
        return OutputSettings(format: .mp4, recordSystemAudio: false, temporaryFolderURL: URL(fileURLWithPath: NSTemporaryDirectory()), finalOutputFolderURL: movies, temporaryFolderBookmarkData: nil, finalOutputFolderBookmarkData: nil, baseFileName: "Capture", overwritePolicy: .ask, validatedAt: nil)
    }

    func shouldCaptureSystemAudio() -> Bool {
        format == .mp4 && recordSystemAudio
    }

    func sanitizedBaseFileName() throws -> String {
        let trimmed = baseFileName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !trimmed.contains("/"), !trimmed.contains(":") else { throw CaptureError(code: "invalid_file_name", message: "File name is invalid.", recoveryAction: "Enter a non-empty file name without path separators.", isRecoverable: true, preservedArtifacts: []) }
        return trimmed
    }

    func finalURL() throws -> URL { finalOutputFolderURL.appendingPathComponent(try sanitizedBaseFileName()).appendingPathExtension(format.fileExtension) }

    func validateFolders(fileManager: FolderAccessChecking = FileManager.default) throws {
        try FolderAccessValidator.validateWritableDirectory(
            at: temporaryFolderURL,
            fileManager: fileManager,
            errorCode: "invalid_temp_folder",
            errorMessage: "Temporary folder is not writable.",
            recoveryAction: "Choose a writable temporary data folder."
        )
        try FolderAccessValidator.validateWritableDirectory(
            at: finalOutputFolderURL,
            fileManager: fileManager,
            errorCode: "invalid_output_folder",
            errorMessage: "Final output folder is not writable.",
            recoveryAction: "Choose a writable final output folder."
        )
        _ = try sanitizedBaseFileName()
    }

    func startTemporaryFolderAccess(accessor: SecurityScopeAccessing = URLSecurityScopeAccessor()) -> SecurityScopedFolderAccess {
        SecurityScopedFolderAccess(folderURL: temporaryFolderURL, accessor: accessor)
    }

    func startFinalOutputFolderAccess(accessor: SecurityScopeAccessing = URLSecurityScopeAccessor()) -> SecurityScopedFolderAccess {
        SecurityScopedFolderAccess(folderURL: finalOutputFolderURL, accessor: accessor)
    }

    mutating func setTemporaryFolder(_ url: URL) {
        temporaryFolderURL = url
        temporaryFolderBookmarkData = try? url.bookmarkData(options: .withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil)
    }

    mutating func setFinalOutputFolder(_ url: URL) {
        finalOutputFolderURL = url
        finalOutputFolderBookmarkData = try? url.bookmarkData(options: .withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil)
    }

    mutating func resolveSecurityScopedBookmarks() {
        if let resolved = Self.resolveSecurityScopedURL(from: temporaryFolderBookmarkData) {
            temporaryFolderURL = resolved
        }
        if let resolved = Self.resolveSecurityScopedURL(from: finalOutputFolderBookmarkData) {
            finalOutputFolderURL = resolved
        }
    }

    private static func resolveSecurityScopedURL(from bookmarkData: Data?) -> URL? {
        guard let bookmarkData else { return nil }
        var isStale = false
        return try? URL(resolvingBookmarkData: bookmarkData, options: .withSecurityScope, relativeTo: nil, bookmarkDataIsStale: &isStale)
    }

    private enum CodingKeys: String, CodingKey {
        case format
        case recordSystemAudio
        case temporaryFolderURL
        case finalOutputFolderURL
        case temporaryFolderBookmarkData
        case finalOutputFolderBookmarkData
        case baseFileName
        case overwritePolicy
        case validatedAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        format = try container.decode(OutputFormat.self, forKey: .format)
        recordSystemAudio = try container.decodeIfPresent(Bool.self, forKey: .recordSystemAudio) ?? false
        temporaryFolderURL = try container.decode(URL.self, forKey: .temporaryFolderURL)
        finalOutputFolderURL = try container.decode(URL.self, forKey: .finalOutputFolderURL)
        temporaryFolderBookmarkData = try container.decodeIfPresent(Data.self, forKey: .temporaryFolderBookmarkData)
        finalOutputFolderBookmarkData = try container.decodeIfPresent(Data.self, forKey: .finalOutputFolderBookmarkData)
        baseFileName = try container.decode(String.self, forKey: .baseFileName)
        overwritePolicy = try container.decode(OverwritePolicy.self, forKey: .overwritePolicy)
        validatedAt = try container.decodeIfPresent(Date.self, forKey: .validatedAt)
    }
}

import XCTest
@testable import VideoScreenshot

final class OutputSettingsTests: XCTestCase {
    func testFinalExtensionMatchesFormat() throws {
        var settings = OutputSettings.defaultValue
        settings.baseFileName = "Demo"; settings.format = .mp4
        XCTAssertEqual(try settings.finalURL().pathExtension, "mp4")
        settings.format = .gif
        XCTAssertEqual(try settings.finalURL().pathExtension, "gif")
    }
    func testRejectsUnsafeFileName() {
        var settings = OutputSettings.defaultValue; settings.baseFileName = "bad/name"
        XCTAssertThrowsError(try settings.sanitizedBaseFileName())
    }
    func testSettingsPersistAndReload() {
        let defaults = UserDefaults(suiteName: "VideoScreenshotTests-\(UUID().uuidString)")!
        let store = OutputSettingsStore(defaults: defaults)
        var settings = OutputSettings.defaultValue; settings.baseFileName = "Persisted"; settings.format = .gif
        store.save(settings)
        XCTAssertEqual(store.load().baseFileName, "Persisted"); XCTAssertEqual(store.load().format, .gif)
    }

    func testSystemAudioCaptureIsExplicitOptInForMP4Only() {
        var settings = OutputSettings.defaultValue
        XCTAssertFalse(settings.recordSystemAudio)
        XCTAssertFalse(settings.shouldCaptureSystemAudio())

        settings.recordSystemAudio = true
        settings.format = .mp4
        XCTAssertTrue(settings.shouldCaptureSystemAudio())

        settings.format = .gif
        XCTAssertFalse(settings.shouldCaptureSystemAudio())
    }

    func testLegacySettingsDecodeSystemAudioAsDisabled() throws {
        let json = """
        {
          "format": "mp4",
          "temporaryFolderURL": "file:///tmp/",
          "finalOutputFolderURL": "file:///tmp/",
          "baseFileName": "Capture",
          "overwritePolicy": "ask"
        }
        """.data(using: .utf8)!

        let settings = try JSONDecoder().decode(OutputSettings.self, from: json)

        XCTAssertFalse(settings.recordSystemAudio)
        XCTAssertFalse(settings.shouldCaptureSystemAudio())
    }

    func testFolderValidationUsesWriteProbeRatherThanIsWritableFlag() throws {
        var settings = OutputSettings.defaultValue
        settings.temporaryFolderURL = URL(fileURLWithPath: "/tmp/writable-temp")
        settings.finalOutputFolderURL = URL(fileURLWithPath: "/tmp/writable-output")

        let fileManager = ProbeWritableFileManager(writablePaths: [
            settings.temporaryFolderURL.path,
            settings.finalOutputFolderURL.path
        ])

        XCTAssertNoThrow(try settings.validateFolders(fileManager: fileManager))
        XCTAssertEqual(fileManager.probedPaths, [
            settings.temporaryFolderURL.path,
            settings.finalOutputFolderURL.path
        ])
    }

    func testFinalOutputAccessSessionKeepsSecurityScopeOpenUntilStopped() {
        var settings = OutputSettings.defaultValue
        settings.finalOutputFolderURL = URL(fileURLWithPath: "/tmp/scoped-output")
        let accessor = RecordingSecurityScopeAccessor(granted: true)

        let session = settings.startFinalOutputFolderAccess(accessor: accessor)

        XCTAssertEqual(accessor.startedURLs, [settings.finalOutputFolderURL])
        XCTAssertTrue(session.didAccess)
        XCTAssertTrue(accessor.stoppedURLs.isEmpty)

        session.stop()

        XCTAssertEqual(accessor.stoppedURLs, [settings.finalOutputFolderURL])
    }
}

private final class ProbeWritableFileManager: FolderAccessChecking {
    private let writablePaths: Set<String>
    private(set) var probedPaths: [String] = []

    init(writablePaths: Set<String>) {
        self.writablePaths = writablePaths
    }

    func fileExists(atPath path: String, isDirectory: UnsafeMutablePointer<ObjCBool>?) -> Bool {
        isDirectory?.pointee = true
        return writablePaths.contains(path)
    }

    func createFile(atPath path: String, contents data: Data?, attributes attr: [FileAttributeKey: Any]?) -> Bool {
        let parentPath = URL(fileURLWithPath: path).deletingLastPathComponent().path
        probedPaths.append(parentPath)
        return writablePaths.contains(parentPath)
    }

    func removeItem(at URL: URL) throws {}
}

private final class RecordingSecurityScopeAccessor: SecurityScopeAccessing {
    let granted: Bool
    private(set) var startedURLs: [URL] = []
    private(set) var stoppedURLs: [URL] = []

    init(granted: Bool) {
        self.granted = granted
    }

    func startAccessing(_ url: URL) -> Bool {
        startedURLs.append(url)
        return granted
    }

    func stopAccessing(_ url: URL) {
        stoppedURLs.append(url)
    }
}

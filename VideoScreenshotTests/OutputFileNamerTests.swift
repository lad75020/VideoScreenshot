import XCTest
@testable import VideoScreenshot

final class OutputFileNamerTests: XCTestCase {
    func testRenamePolicyFindsAvailableCandidate() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let existing = dir.appendingPathComponent("Capture.mp4")
        FileManager.default.createFile(atPath: existing.path, contents: Data())
        let renamed = OutputFileNamer().renamedURL(for: existing)
        XCTAssertEqual(renamed.lastPathComponent, "Capture-1.mp4")
    }
    func testAskPolicyRejectsDuplicate() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        var settings = OutputSettings(format: .mp4, temporaryFolderURL: dir, finalOutputFolderURL: dir, baseFileName: "Capture", overwritePolicy: .ask, validatedAt: nil)
        FileManager.default.createFile(atPath: try settings.finalURL().path, contents: Data())
        XCTAssertThrowsError(try OutputFileNamer().resolvedURL(for: settings))
    }

    func testTemporaryURLUsesConfiguredTemporaryFolder() throws {
        let finalDir = URL(fileURLWithPath: "/tmp/videoscreenshot-final")
        let temporaryDir = URL(fileURLWithPath: "/tmp/videoscreenshot-temp")
        let finalURL = finalDir.appendingPathComponent("Capture.mp4")

        let temporaryURL = OutputFileNamer().temporaryURL(for: finalURL, in: temporaryDir)

        XCTAssertEqual(temporaryURL.deletingLastPathComponent().path, temporaryDir.path)
        XCTAssertNotEqual(temporaryURL.deletingLastPathComponent().path, finalDir.path)
        XCTAssertEqual(temporaryURL.pathExtension, "mp4")
    }
}

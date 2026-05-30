import XCTest
@testable import VideoScreenshot

final class RegionSelectionTests: XCTestCase {
    func testRectangleDerivationMatchesDraggedBounds() {
        let rect = DisplayGeometry.selectionRect(from: CGPoint(x: 10, y: 10), to: CGPoint(x: 30, y: 50))
        XCTAssertEqual(rect, CGRect(x: 10, y: 10, width: 20, height: 40))
    }

    func testRectangleDerivationSupportsReverseDrag() {
        let rect = DisplayGeometry.selectionRect(from: CGPoint(x: 30, y: 50), to: CGPoint(x: 10, y: 10))
        XCTAssertEqual(rect, CGRect(x: 10, y: 10, width: 20, height: 40))
    }

    func testPixelRectAppliesRetinaScaleToRectangle() {
        let pixel = DisplayGeometry.pixelRect(for: CGRect(x: 10, y: 20, width: 30, height: 40), displayFrame: .zero, scale: 2)
        XCTAssertEqual(pixel, CGRect(x: 20, y: 40, width: 60, height: 80))
    }

    func testAreaAllowsRectangularBounds() throws {
        let area = try DisplayGeometry.makeArea(start: CGPoint(x: 10, y: 10), end: CGPoint(x: 30, y: 50), displayFrame: CGRect(x: 0, y: 0, width: 100, height: 100), scale: 2)
        XCTAssertTrue(area.isValid)
        XCTAssertEqual(area.sizePoints, CGSize(width: 20, height: 40))
        XCTAssertEqual(area.pixelRect, CGRect(x: 20, y: 20, width: 40, height: 80))
    }

    func testAreaRequiresSingleDisplayBounds() throws {
        XCTAssertThrowsError(try DisplayGeometry.makeArea(start: .zero, end: CGPoint(x: 200, y: 200), displayFrame: CGRect(x: 0, y: 0, width: 100, height: 100), scale: 1))
    }

    @MainActor
    func testSelectionOverlayIsNotReleasedByCloseWhileCoordinatorOwnsIt() {
        let overlay = SelectionOverlayWindow { _ in }
        XCTAssertFalse(overlay.isReleasedWhenClosed)
        overlay.close()
    }
}

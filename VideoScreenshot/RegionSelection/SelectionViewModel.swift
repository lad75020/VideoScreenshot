import AppKit
import Foundation

@MainActor
final class SelectionViewModel: ObservableObject {
    @Published private(set) var previewRect: CGRect = .zero
    @Published private(set) var selectedArea: CaptureArea?
    private var dragStart: CGPoint?
    var displayFrame: CGRect = NSScreen.main?.frame ?? CGRect(x: 0, y: 0, width: 1440, height: 900)
    var displayID: UInt32 = CGMainDisplayID()
    var displayScale: CGFloat = NSScreen.main?.backingScaleFactor ?? 2

    func beginDrag(at point: CGPoint) { dragStart = point; previewRect = .zero; selectedArea = nil }
    func updateDrag(to point: CGPoint) { if let start = dragStart { previewRect = DisplayGeometry.selectionRect(from: start, to: point) } }
    func endDrag(at point: CGPoint) throws -> CaptureArea {
        guard let start = dragStart else { throw CaptureError.invalidArea() }
        let area = try DisplayGeometry.makeArea(start: start, end: point, displayFrame: displayFrame, displayID: displayID, scale: displayScale)
        selectedArea = area; dragStart = nil; return area
    }
    func cancel() { dragStart = nil; previewRect = .zero; selectedArea = nil }
}

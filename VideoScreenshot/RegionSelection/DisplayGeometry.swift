import AppKit
import CoreGraphics
import Foundation

enum DisplayGeometry {
    static func selectionRect(from start: CGPoint, to end: CGPoint) -> CGRect {
        CGRect(
            x: min(start.x, end.x),
            y: min(start.y, end.y),
            width: abs(end.x - start.x),
            height: abs(end.y - start.y)
        ).standardized
    }

    static func pixelRect(for pointRect: CGRect, displayFrame: CGRect, scale: CGFloat) -> CGRect {
        let local = CGRect(x: pointRect.origin.x - displayFrame.origin.x, y: pointRect.origin.y - displayFrame.origin.y, width: pointRect.width, height: pointRect.height)
        return CGRect(x: (local.origin.x * scale).rounded(), y: (local.origin.y * scale).rounded(), width: (local.width * scale).rounded(), height: (local.height * scale).rounded())
    }

    static func makeArea(start: CGPoint, end: CGPoint, displayFrame: CGRect, displayID: UInt32 = 0, scale: CGFloat = NSScreen.main?.backingScaleFactor ?? 2) throws -> CaptureArea {
        let selection = selectionRect(from: start, to: end)
        guard selection.width > 0, selection.height > 0, displayFrame.contains(selection) else { throw CaptureError.invalidArea() }
        return CaptureArea(id: UUID(), originPoint: selection.origin, sizePoints: selection.size, displayID: displayID, displayScale: scale, pixelRect: pixelRect(for: selection, displayFrame: displayFrame, scale: scale), createdAt: Date())
    }
}

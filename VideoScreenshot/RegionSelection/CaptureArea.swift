import CoreGraphics
import Foundation

struct CaptureArea: Equatable, Identifiable, Codable {
    let id: UUID
    var originPoint: CGPoint
    var sizePoints: CGSize
    var displayID: UInt32
    var displayScale: CGFloat
    var pixelRect: CGRect
    var createdAt: Date

    var isValid: Bool {
        sizePoints.width > 0 && sizePoints.height > 0 && pixelRect.width > 0 && pixelRect.height > 0
    }
}

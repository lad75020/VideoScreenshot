import AppKit
import SwiftUI

@MainActor
final class SelectionOverlayWindow: NSWindow {
    private let viewModel: SelectionViewModel
    private let onComplete: (CaptureArea) -> Void

    init(viewModel: SelectionViewModel = SelectionViewModel(), onComplete: @escaping (CaptureArea) -> Void) {
        self.viewModel = viewModel; self.onComplete = onComplete
        super.init(contentRect: NSScreen.main?.frame ?? .zero, styleMask: [.borderless], backing: .buffered, defer: false)
        isReleasedWhenClosed = false
        isOpaque = false; backgroundColor = NSColor.black.withAlphaComponent(0.15); level = .screenSaver
        ignoresMouseEvents = false; collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        contentView = NSHostingView(rootView: SelectionOverlayView(viewModel: viewModel, onComplete: { [weak self] area in
            guard let self else { return }
            self.close()
            self.onComplete(area)
        }))
    }
}

struct SelectionOverlayView: View {
    @ObservedObject var viewModel: SelectionViewModel
    let onComplete: (CaptureArea) -> Void
    var body: some View {
        GeometryReader { _ in
            ZStack(alignment: .topLeading) {
                Color.black.opacity(0.08)
                Rectangle().stroke(Color.accentColor, lineWidth: 2)
                    .frame(width: viewModel.previewRect.width, height: viewModel.previewRect.height)
                    .offset(x: viewModel.previewRect.minX, y: viewModel.previewRect.minY)
            }
            .contentShape(Rectangle())
            .gesture(DragGesture(minimumDistance: 1, coordinateSpace: .local)
                .onChanged { value in
                    if viewModel.previewRect == .zero { viewModel.beginDrag(at: value.startLocation) }
                    viewModel.updateDrag(to: value.location)
                }
                .onEnded { value in if let area = try? viewModel.endDrag(at: value.location) { onComplete(area) } })
        }
        .accessibilityLabel("Area selection overlay")
    }
}

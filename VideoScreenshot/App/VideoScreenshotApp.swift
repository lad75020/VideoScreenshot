import SwiftUI

@main
struct VideoScreenshotApp: App {
    @StateObject private var coordinator = CaptureCoordinator(environment: .live)
    var body: some Scene {
        WindowGroup {
            MainWindowView().environmentObject(coordinator)
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 900, height: 680)
    }
}

import SwiftUI

@main
struct VideoScreenshotApp: App {
    @StateObject private var coordinator = CaptureCoordinator(environment: .live)
    var body: some Scene {
        WindowGroup {
            MainWindowView().environmentObject(coordinator)
        }
    }
}

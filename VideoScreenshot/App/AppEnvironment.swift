import Foundation

struct AppEnvironment {
    var permissionService: CapturePermissionServicing
    var screenCaptureService: ScreenCaptureServicing
    var audioCaptureService: SystemAudioCaptureServicing
    var mp4ExportService: MP4ExportServicing
    var gifExportService: GIFExportServicing
    var settingsStore: OutputSettingsStoring
    var artifactStoreFactory: (URL) -> TemporaryArtifactStore

    @MainActor static let live = AppEnvironment(
        permissionService: CapturePermissionService(),
        screenCaptureService: ScreenCaptureService(),
        audioCaptureService: SystemAudioCaptureService(),
        mp4ExportService: MP4ExportService(),
        gifExportService: GIFExportService(),
        settingsStore: OutputSettingsStore(),
        artifactStoreFactory: { TemporaryArtifactStore(folderURL: $0) }
    )
}

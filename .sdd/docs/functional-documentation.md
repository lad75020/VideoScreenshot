# Functional Documentation

## 4. Functional Requirements

### 4.1 Area Selection

- FR-001: The system shall let the user request a screen area selection overlay.
  [INFERRED: HIGH] Source: `CaptureCoordinator.selectArea`, `SelectionOverlayWindow`, `CaptureAreaCard`.
  - Precondition: The app is open and not recording or finalizing.
  - Postcondition: A valid `CaptureArea` can be stored on the coordinator.
  - Error: A missing or invalid area blocks Start Capture.

- FR-002: The system shall keep the selected capture area visible for review before recording starts.
  [INFERRED: HIGH] Source: `CaptureCoordinator.setSelectedArea`, `MainWindowView.CaptureAreaCard`.
  - Precondition: A selection has been completed.
  - Postcondition: The UI shows the selected area dimensions, display ID, and scale.
  - Error: Invalid areas are treated as no usable selection.

- FR-003: The system shall reject capture start when no valid non-empty area exists.
  [INFERRED: HIGH] Source: `CaptureCoordinator.startCapture`, `CaptureArea.isValid`, `CaptureError.invalidArea`.
  - Precondition: The user activates Start Capture.
  - Postcondition: No capture service is started.
  - Error: The user sees `Select an area before starting capture.` with recovery guidance.

### 4.2 Capture Lifecycle

- FR-004: The system shall prevent overlapping recordings.
  [INFERRED: HIGH] Source: `CaptureCoordinator.startCapture`, `ScreenCaptureService.start`, `SystemAudioCaptureService.startIfNeeded`.
  - Precondition: A capture or audio capture is already active, or the coordinator is not in an allowed state.
  - Postcondition: The existing session remains the only active recording.
  - Error: The user sees a recoverable busy error.

- FR-005: The system shall transition through explicit visible states during capture.
  [INFERRED: HIGH] Source: `CaptureSessionState`, `StateBadge`, `CaptureControlsView`.
  - Precondition: The user selects an area and starts/stops capture.
  - Postcondition: The UI displays Idle, Ready, Validating, Recording, Stopping, Finalizing, Completed, or Error as appropriate.
  - Error: Invalid transitions are not applied by `canTransition`.

- FR-006: The system shall start screen capture only after area, state, folders, permissions, and MP4 capability checks pass.
  [INFERRED: HIGH] Source: `CaptureCoordinator.startCapture`.
  - Precondition: User activates Start Capture.
  - Postcondition: Screen capture starts and coordinator enters Recording.
  - Error: Failed validation calls `abortFailedStart` to stop capture streams and cancel export services.

- FR-007: The system shall stop active capture, stop audio capture, and finalize the selected export format when the user stops recording.
  [INFERRED: HIGH] Source: `CaptureCoordinator.stopCapture`.
  - Precondition: State is Recording.
  - Postcondition: The selected exporter finalizes the recording and reports a `SavedRecording`.
  - Error: If no recording is active, a recoverable `not_recording` error is shown.

### 4.3 Screen and Audio Capture

- FR-008: The system shall capture complete screen frames from the selected display region at 24 fps target cadence.
  [INFERRED: MEDIUM] Source: `ScreenCaptureService.streamConfiguration`, `VideoStreamOutput.stream`.
  - Precondition: ScreenCaptureKit can resolve a capturable display.
  - Postcondition: Complete valid frames are routed to the selected export service.
  - Error: Incomplete or invalid frames are dropped and counted.

- FR-009: The system shall capture default system output audio only for MP4 output.
  [INFERRED: MEDIUM] Source: `SystemAudioCaptureService.startIfNeeded`, `CaptureCoordinator.configureSampleRouting`.
  - Precondition: Output format is MP4.
  - Postcondition: Valid audio samples are routed to `MP4ExportService`.
  - Error: GIF output stops or skips audio capture.

- FR-010: The system shall exclude the current process audio and microphone audio from the ScreenCaptureKit audio stream.
  [INFERRED: MEDIUM] Source: `SystemAudioCaptureService.audioConfiguration`.
  - Precondition: Audio capture starts.
  - Postcondition: Configuration sets `excludesCurrentProcessAudio = true` and `captureMicrophone = false`.
  - Error: ScreenCaptureKit start failures surface as recoverable start errors.

### 4.4 Export and File Handling

- FR-011: The system shall export MP4 recordings with HEVC video and AAC audio settings.
  [INFERRED: HIGH] Source: `MP4ExportService.validateCapabilities`, `hevcVideoSettings`, `mp4AudioSettings`, `SavedRecording` construction.
  - Precondition: Output format is MP4 and AVAssetWriter can apply the settings.
  - Postcondition: A `.mp4` file exists at the final URL.
  - Error: Unsupported writer capabilities produce a recoverable `writer_unsupported` error.

- FR-012: The system shall export GIF recordings as silent looping animations.
  [INFERRED: HIGH] Source: `GIFExportService.finalize`, `SavedRecording.hasAudio = false`.
  - Precondition: Output format is GIF.
  - Postcondition: A `.gif` file exists at the final URL and has no audio metadata from the app.
  - Error: GIF writer creation or finalization failures produce recoverable errors.

- FR-013: The system shall prevent silent overwrites of existing final files.
  [INFERRED: HIGH] Source: `OutputFileNamer.resolvedURL`, `commitTemporaryFile`.
  - Precondition: A final file URL is resolved.
  - Postcondition: The app either chooses a non-existing renamed URL or blocks with a file-exists error according to policy.
  - Error: Existing final files produce `file_exists` or `save_cancelled` errors when overwrite is not allowed.

- FR-014: The system shall commit finalized output by moving a temporary sibling file into the final path.
  [INFERRED: MEDIUM] Source: `OutputFileNamer.temporarySiblingURL`, `commitTemporaryFile`, `MP4ExportService.finalize`, `GIFExportService.finalize`.
  - Precondition: The media writer has successfully finalized the temporary file.
  - Postcondition: The temporary file is moved to the final output URL.
  - Error: Commit failures preserve the temporary artifact URL in the error.

### 4.5 Settings and Permissions

- FR-015: The system shall persist output settings and resolve selected folder bookmarks on load.
  [INFERRED: HIGH] Source: `OutputSettingsStore.load`, `OutputSettings.setTemporaryFolder`, `setFinalOutputFolder`, `resolveSecurityScopedBookmarks`.
  - Precondition: User chooses folders or app starts with saved settings.
  - Postcondition: Settings are stored as JSON in UserDefaults and bookmark URLs are resolved when possible.
  - Error: Invalid or missing saved settings fall back to defaults.

- FR-016: The system shall validate temporary and output folders before capture starts.
  [INFERRED: HIGH] Source: `OutputSettings.validateFolders`, `FolderAccessValidator.validateWritableDirectory`.
  - Precondition: Start Capture is requested.
  - Postcondition: Both folders exist, are directories, and accept a probe file.
  - Error: Invalid folders produce `invalid_temp_folder` or `invalid_output_folder` with recovery text.

- FR-017: The system shall validate the output file name before capture starts.
  [INFERRED: HIGH] Source: `OutputSettings.sanitizedBaseFileName`, `validateFolders`.
  - Precondition: Start Capture is requested or final URL is resolved.
  - Postcondition: The name is non-empty and contains no `/` or `:`.
  - Error: Invalid names produce `invalid_file_name`.

- FR-018: The system shall surface permission problems with recovery guidance.
  [INFERRED: MEDIUM] Source: `CaptureCoordinator.startCapture`, `CapturePermissionService`, `CaptureError.permissionDenied`.
  - Precondition: Capture requires screen or audio permission.
  - Postcondition: Capture starts only when required permissions are available.
  - Error: Denied permissions produce recovery instructions for System Settings.

## 4B. Business Rules and Invariants

- BR-001: A recording cannot begin without a selected valid capture area.
  Enforcement: `CaptureCoordinator.startCapture` checks `selectedArea` and `area.isValid`.
  [INFERRED: HIGH]

- BR-002: Settings changes are locked while recording or finalizing.
  Enforcement: `SettingsView.isLocked` disables and dims the settings section.
  [INFERRED: MEDIUM]

- BR-003: GIF recordings are always silent.
  Enforcement: `SystemAudioCaptureService.startIfNeeded` skips audio unless format is MP4; `GIFExportService` returns `hasAudio: false`.
  [INFERRED: HIGH]

- BR-004: MP4 export currently uses AAC audio, not MP3 audio.
  Enforcement: `MP4ExportService.mp4AudioSettings` uses `kAudioFormatMPEG4AAC`; capability errors mention AAC.
  [INFERRED: HIGH]

- BR-005: Final output filenames cannot be empty and cannot include path separators.
  Enforcement: `OutputSettings.sanitizedBaseFileName`.
  [INFERRED: HIGH]

- BR-006: Finalization failures should preserve artifact information when possible.
  Enforcement: `CaptureError.preservedArtifacts` is populated for writer, GIF, and commit failures where a temporary URL exists.
  [INFERRED: MEDIUM]

- BR-007: GIF export is bounded by maximum buffered frames and pixels.
  Enforcement: `GIFExportService.maximumBufferedFrames` and `maximumBufferedPixels`.
  [INFERRED: HIGH]

## 4C. Decision Logic

| Decision | Condition | Outcome | Source |
|----------|-----------|---------|--------|
| Start capture eligibility | Area missing or invalid | Throw `invalid_area`, do not start streams | `CaptureCoordinator.startCapture` |
| Start capture eligibility | State not idle, areaSelected, or completed | Throw `capture_busy` | `CaptureCoordinator.startCapture` |
| Permission requirement | Format is MP4 | Require screen and audio capability status | `currentStatus(requireAudio: outputSettings.format == .mp4)` |
| Export session | Format is MP4 | Begin MP4 writer with selected video size | `beginExportSession` |
| Export session | Format is GIF | Begin GIF writer and buffer frames | `beginExportSession` |
| Sample routing | Format is MP4 | Route video and audio to MP4 service | `configureSampleRouting` |
| Sample routing | Format is GIF | Route video to GIF service and ignore audio | `configureSampleRouting` |
| Existing file | Overwrite policy is ask | Throw `file_exists` | `OutputFileNamer.resolvedURL` |
| Existing file | Overwrite policy is rename | Resolve numbered or UUID suffixed URL | `OutputFileNamer.renamedURL` |
| Existing file | Overwrite policy is cancel | Throw `save_cancelled` | `OutputFileNamer.resolvedURL` |

## 4D. Computed Values and Transformations

- CV-001: Capture pixel rectangle.
  Formula: Selected screen point geometry plus display scale maps to `CaptureArea.pixelRect`.
  Business meaning: Defines the exact pixels sent to ScreenCaptureKit.
  [INFERRED: MEDIUM] Source: `CaptureArea`, region selection files, data model.

- CV-002: Final output URL.
  Formula: `finalOutputFolderURL / sanitizedBaseFileName + format.fileExtension`.
  Business meaning: Determines the final user-visible artifact location.
  [INFERRED: HIGH] Source: `OutputSettings.finalURL`.

- CV-003: Temporary sibling URL.
  Formula: `.<base>.<UUID>.recording.<extension>` in the final output directory.
  Business meaning: Avoids exposing partial files as final recordings.
  [INFERRED: HIGH] Source: `OutputFileNamer.temporarySiblingURL`.

- CV-004: Saved recording metadata.
  Formula: Duration equals `stoppedAt - startedAt`, frame rate is 24, codecs and audio flags derive from export path and appended samples.
  Business meaning: Gives UI and users structured information about the saved file.
  [INFERRED: HIGH] Source: `MP4ExportService.finalize`, `GIFExportService.finalize`.

## 4E. Side Effects and Events

- SE-001: Open selection overlay.
  Trigger: User clicks Select Area.
  Side effect: Creates and shows `SelectionOverlayWindow`.
  [INFERRED: MEDIUM]

- SE-002: Start ScreenCaptureKit streams.
  Trigger: Start Capture after validation passes.
  Side effect: Creates SCStream instances and starts capture.
  [INFERRED: HIGH]

- SE-003: Write output files.
  Trigger: Export service begins and finalizes.
  Side effect: Creates temporary output file and moves it to final output path.
  [INFERRED: HIGH]

- SE-004: Persist output settings.
  Trigger: User chooses folders or coordinator saves settings.
  Side effect: Writes encoded settings to UserDefaults.
  [INFERRED: HIGH]

- SE-005: Open Finder for saved file.
  Trigger: User uses reveal action after completion.
  Side effect: Calls `NSWorkspace.shared.activateFileViewerSelecting`.
  [INFERRED: MEDIUM]

- SE-006: Copy saved path.
  Trigger: User uses copy action after completion.
  Side effect: Writes saved path to the general pasteboard.
  [INFERRED: MEDIUM]

## 5. User Stories

### US-01 - Select Capture Area (Priority: P1) MVP

As a screen recorder user, I want to select the screen area to record, so that the output contains only the intended content.
[INFERRED: HIGH]

Independent Test: Select an area and confirm the UI shows dimensions and the Ready state.

Acceptance Scenarios:
1. Given no area is selected, when the user clicks Select Area and drags a region, then the selected region is stored and shown.
2. Given no valid area is selected, when the user tries to start capture, then the system blocks recording with an invalid-area recovery message.

### US-02 - Record MP4 With Audio (Priority: P1) MVP

As a screen recorder user, I want to record the selected area with system audio, so that I can save shareable video demonstrations.
[INFERRED: HIGH]

Independent Test: Record a short MP4 while playing audible system output and verify the saved path opens.

Acceptance Scenarios:
1. Given a valid area and MP4 settings, when Start Capture is clicked, then the app starts screen and audio capture.
2. Given capture is recording, when Stop Capture is clicked, then the app finalizes an MP4 file.

### US-03 - Record Silent GIF (Priority: P1) MVP

As a user creating short visual clips, I want to export a silent GIF, so that I can share a lightweight animation.
[INFERRED: HIGH]

Independent Test: Record a short GIF and verify it loops and has no audio.

Acceptance Scenarios:
1. Given GIF format is selected, when capture starts, then audio capture is skipped.
2. Given GIF frames are within safety limits, when capture stops, then a final GIF is created.

### US-04 - Configure Output (Priority: P2)

As a user, I want to choose the format, filename, temporary folder, and output folder, so that recordings are saved where I expect with safe names.
[INFERRED: HIGH]

Independent Test: Change settings, restart the app, and confirm settings persist where bookmarks resolve.

Acceptance Scenarios:
1. Given the app is idle, when the user changes folders, then settings are saved and folder bookmarks are created.
2. Given a folder is invalid or unwritable, when Start Capture is clicked, then capture is blocked with recovery text.

## 6. User Flows

### 6.1 MP4 Recording Flow

Actor: Desktop user
Precondition: App is launched, permissions are available, output folders are writable.
Trigger: User wants a local video recording.

1. User chooses MP4 and output settings.
2. User selects a screen area.
3. System stores the capture area and shows Ready.
4. User starts capture.
5. System validates folders, permissions, and writer capabilities.
6. System starts screen and audio capture.
7. User stops capture.
8. System stops streams, finalizes the MP4, commits the temporary file, and reports the saved path.

Error paths:
- If permissions are denied, the system stops startup and shows recovery instructions.
- If writer capability is unavailable, the system blocks before recording starts.
- If final commit fails, the system reports preserved temporary artifacts where available.

### 6.2 GIF Recording Flow

Actor: Desktop user
Precondition: App is launched, screen permission is available, and output folders are writable.
Trigger: User wants a short silent animation.

1. User chooses GIF and output settings.
2. User selects a screen area.
3. User starts capture.
4. System starts screen capture only.
5. System buffers converted frames within frame and pixel limits.
6. User stops capture.
7. System writes a looping GIF and reports the saved path.

Error paths:
- If the GIF grows too large, the system reports `gif_buffer_limit_exceeded` and recommends shorter, smaller captures or MP4.
- If GIF finalization fails, the system reports a recoverable finalization error.

### 6.3 Settings Recovery Flow

Actor: Desktop user
Precondition: Capture is blocked by invalid settings.
Trigger: The app reports an invalid folder, invalid filename, duplicate file, or permission problem.

1. User reads the message and recovery action.
2. User chooses a writable folder, changes the filename, or grants permissions as directed.
3. User retries Start Capture.
4. System revalidates and either starts capture or reports the next blocking issue.

Error paths:
- If a selected folder bookmark is stale, the user reselects the folder through the app to refresh access.


## Source Evidence

This document is based on:

- Codebase-memory MCP project `Volumes-WDBlack4TB-Code-VideoScreenshot`: index status ready, 885 nodes, 1350 edges.
- Codebase-memory MCP graph searches for Capture, Export, and Settings components.
- Codebase-memory MCP trace_path results for `start`, `stop`, `CaptureCoordinator`, `ScreenCaptureService`, `SystemAudioCaptureService`, `MP4ExportService`, `GIFExportService`, and `OutputSettingsStore`.
- Source files under `VideoScreenshot/App`, `VideoScreenshot/Capture`, `VideoScreenshot/Export`, `VideoScreenshot/RegionSelection`, and `VideoScreenshot/UI`.
- Spec Kit files under `specs/001-screen-capture-export/`.
- Verification log `/tmp/videoscreenshot-xcodebuild-test.log`, which contains one `** TEST SUCCEEDED **` marker and no build/test error markers in the parsed verification pass.

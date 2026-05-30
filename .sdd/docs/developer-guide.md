# Developer Guide

## Development Environment Setup

### Prerequisites

| Tool | Minimum version | Purpose |
|------|-----------------|---------|
| macOS | 26.0 | Runtime target and capture API availability. |
| Xcode | 26.5 or compatible with macOS 26 SDK | Build, signing, testing, and app packaging. |
| Swift | Project setting `SWIFT_VERSION: 6.0` | Compile the application and tests. |
| XcodeGen | 2.42.0 or later if regenerating the project | Generate `VideoScreenshot.xcodeproj` from `project.yml`. |
| Apple Developer Team | `RJYVGK9S3F` in `project.yml` | Automatic code signing for local development and release builds. |

### First-Time Setup

1. Open the repository:

```bash
cd /Volumes/WDBlack4TB/Code/VideoScreenshot
```

2. If the Xcode project must be regenerated, install XcodeGen and run:

```bash
xcodegen generate
```

3. Open the project in Xcode:

```bash
open VideoScreenshot.xcodeproj
```

4. Select the `VideoScreenshot` scheme and a macOS destination.

5. Confirm signing uses the team configured in `project.yml` or update the team locally if needed.

### Updating Your Environment

After pulling changes, regenerate the Xcode project only when `project.yml` changed:

```bash
xcodegen generate
```

Then cleanly build or test from Xcode, or use the command line commands in the Testing section.

## Project Structure

```text
VideoScreenshot/
  project.yml                         # XcodeGen configuration
  VideoScreenshot/                     # Application source
    App/                               # App startup and dependency injection
    Capture/                           # Capture coordinator, state, errors, permissions, video/audio capture
    Export/                            # Output settings, bookmarks, file naming, temporary artifacts, MP4/GIF export
    RegionSelection/                   # Selection overlay, display geometry, capture area model
    UI/                                # SwiftUI views and controls
  VideoScreenshotTests/                # XCTest unit tests
  VideoScreenshotUITests/              # Xcode UI tests
  specs/001-screen-capture-export/     # Spec Kit artifacts and contracts
  .sdd/docs/                           # Generated docs
```

### Where to Start Reading

1. Start with `VideoScreenshot/App/AppEnvironment.swift` to understand dependency wiring.
2. Read `VideoScreenshot/Capture/CaptureCoordinator.swift` to understand the workflow.
3. Read `VideoScreenshot/Capture/ScreenCaptureService.swift` and `VideoScreenshot/Capture/SystemAudioCaptureService.swift` for ScreenCaptureKit details.
4. Read `VideoScreenshot/Export/MP4ExportService.swift`, `VideoScreenshot/Export/GIFExportService.swift`, and `VideoScreenshot/Export/OutputFileNamer.swift` for output behavior.
5. Read `VideoScreenshot/UI/MainWindowView.swift`, `SettingsView.swift`, and `CaptureControlsView.swift` for user-facing state and actions.

## Coding Conventions

### Naming

| Item | Convention | Examples |
|------|------------|----------|
| Types | PascalCase | `CaptureCoordinator`, `OutputSettings`, `SavedRecording` |
| Protocols | Capability-oriented names ending in `Servicing` or `Storing` | `ScreenCaptureServicing`, `OutputSettingsStoring` |
| Methods and properties | lowerCamelCase | `startCapture`, `validateFolders`, `savedRecording` |
| Enum cases | lowerCamelCase | `areaSelected`, `finalizing`, `completedWithWarning` |
| Files | One primary type or feature per Swift file | `MP4ExportService.swift`, `CaptureSessionState.swift` |

### File Organization

The source tree is layer-based:

- `App` owns startup and dependency composition.
- `UI` owns presentation only.
- `Capture` owns workflow, state, permissions, and capture streams.
- `Export` owns persistence and media/file export behavior.
- `RegionSelection` owns screen region selection and geometry.

### Error Handling

User-facing failures use `CaptureError`, which always includes a stable code, message, recovery action, recoverability flag, and preserved artifact URLs. Throw `CaptureError` when the failure can be explained to the user. Wrap unknown errors at the coordinator boundary with a recoverable `CaptureError` and actionable recovery text.

### Concurrency

- `CaptureCoordinator`, capture services, and export services are `@MainActor` to keep SwiftUI state and media writer state serialized.
- ScreenCaptureKit callbacks arrive on dedicated sample queues and hop back to the main actor before mutating coordinator/export state.
- `SampleDeliveryGate` prevents unbounded concurrent sample delivery when callbacks arrive faster than the main actor can process them.

### File Access and Sandbox Rules

- Use security-scoped bookmarks for user-selected output folders.
- Validate writable directories with a probe file before capture starts.
- Use temporary sibling files and commit them to final URLs only after successful finalization.
- Preserve temporary artifacts on commit/finalization failures when possible.

## Testing

### Test Structure

| Test area | Location | Purpose |
|-----------|----------|---------|
| Unit tests | `VideoScreenshotTests/` | Validate settings, file naming, error handling, state transitions, and selection behavior. |
| UI tests | `VideoScreenshotUITests/` | Validate basic capture control presentation and interaction. |
| Manual QA | `specs/001-screen-capture-export/manual-qa.md` and `quickstart.md` | Validate real capture, audio, permissions, and output files. |

### Running Tests

```bash
# Run all available tests for the macOS scheme
xcodebuild -project VideoScreenshot.xcodeproj -scheme VideoScreenshot -destination 'platform=macOS' test

# Capture a log for evidence
xcodebuild -project VideoScreenshot.xcodeproj -scheme VideoScreenshot -destination 'platform=macOS' test | tee /tmp/videoscreenshot-xcodebuild-test.log
```

The latest verification pass succeeded with `** TEST SUCCEEDED **` in `/tmp/videoscreenshot-xcodebuild-test.log`.

### Security and Reliability Checks

Run a targeted source scan for high-risk patterns after security-sensitive changes:

```bash
python3 - <<'PY'
from pathlib import Path
patterns = ['semaphore.wait', 'try!', 'fatalError', 'Authorization', 'password', 'serverTrust', 'Process(']
for path in Path('VideoScreenshot').rglob('*.swift'):
    text = path.read_text(errors='ignore')
    for pattern in patterns:
        if pattern in text:
            print(path, pattern)
PY
```

The latest scan found no matches for the selected high-risk patterns.

## Adding New Features

### Development Workflow

1. Update or create the relevant Spec Kit artifact under `specs/` for user-visible feature changes.
2. Add model or state changes in `Capture`, `Export`, or `RegionSelection` before wiring UI.
3. Add or update a protocol in `AppEnvironment` when a new service dependency is needed.
4. Implement the live service with explicit error behavior and cleanup paths.
5. Wire the service into `AppEnvironment.live`.
6. Add SwiftUI controls that call coordinator methods rather than service methods directly.
7. Add XCTest coverage for pure model, file naming, validation, and state-transition logic.
8. Run `xcodebuild ... test` and any targeted security scan before committing.

### Example: Adding a New Export Format

1. Add a new `OutputFormat` case and file extension in `OutputSettings.swift`.
2. Add a new export service protocol and implementation under `VideoScreenshot/Export/`.
3. Add the service to `AppEnvironment`.
4. Update `CaptureCoordinator.beginExportSession`, `configureSampleRouting`, and `stopCapture` switch statements.
5. Update `SettingsView` if the picker needs copy or availability behavior.
6. Add tests for settings persistence, output naming, duplicate handling, and the coordinator state path.
7. Update user, deployment, and functional documentation.

### Patterns to Follow

- Keep views declarative and state-driven.
- Keep long-running capture/export side effects in services.
- Validate before starting capture, and clean up both capture streams if any start step fails.
- Avoid direct deletion of final user files unless explicitly requested by the overwrite policy.
- Prefer additive service protocols for testability.


## Source Evidence

This document is based on:

- Codebase-memory MCP project `Volumes-WDBlack4TB-Code-VideoScreenshot`: index status ready, 885 nodes, 1350 edges.
- Codebase-memory MCP graph searches for Capture, Export, and Settings components.
- Codebase-memory MCP trace_path results for `start`, `stop`, `CaptureCoordinator`, `ScreenCaptureService`, `SystemAudioCaptureService`, `MP4ExportService`, `GIFExportService`, and `OutputSettingsStore`.
- Source files under `VideoScreenshot/App`, `VideoScreenshot/Capture`, `VideoScreenshot/Export`, `VideoScreenshot/RegionSelection`, and `VideoScreenshot/UI`.
- Spec Kit files under `specs/001-screen-capture-export/`.
- Verification log `/tmp/videoscreenshot-xcodebuild-test.log`, which contains one `** TEST SUCCEEDED **` marker and no build/test error markers in the parsed verification pass.

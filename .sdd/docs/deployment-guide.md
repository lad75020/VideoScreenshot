# Deployment Guide

## Prerequisites

### Software Requirements

| Software | Minimum Version | Purpose |
|----------|-----------------|---------|
| macOS | 26.0 | Target runtime. |
| Xcode | Compatible with macOS 26 SDK | Build, test, sign, archive, and export the app. |
| Swift | Project setting `SWIFT_VERSION: 6.0` | Compile source and tests. |
| XcodeGen | 2.42.0 or later, only if regenerating project files | Generate `VideoScreenshot.xcodeproj` from `project.yml`. |

### Hardware and OS Requirements

- Mac capable of running macOS 26.0 or later.
- HEVC/H.265 hardware or OS encoder support for MP4 export.
- Screen Recording permission available for the installed app.
- Audio capture support on the target macOS version for MP4 audio.

### Signing and Entitlements

`project.yml` configures:

| Setting | Value |
|---------|-------|
| Bundle identifier | `fr.dubertrand.VideoScreenshot` |
| Signing style | Automatic |
| Development team | `RJYVGK9S3F` |
| Hardened runtime | Enabled |
| Entitlements file | `VideoScreenshot/VideoScreenshot.entitlements` |

The entitlements file enables App Sandbox, user-selected read/write file access, and audio input access.

### Required Credentials

- Apple Developer signing access for the configured team or a locally substituted signing team.
- No server credentials, database credentials, API keys, or cloud credentials are used by the current app.

## Build and Release

### Regenerate Project Files

Run this only when `project.yml` changed:

```bash
xcodegen generate
```

### Build for Development

```bash
xcodebuild -project VideoScreenshot.xcodeproj -scheme VideoScreenshot -destination 'platform=macOS' build
```

### Run Tests Before Release

```bash
xcodebuild -project VideoScreenshot.xcodeproj -scheme VideoScreenshot -destination 'platform=macOS' test
```

The latest verification pass succeeded with `** TEST SUCCEEDED **` in `/tmp/videoscreenshot-xcodebuild-test.log`.

### Archive for Distribution

Use Xcode Organizer when possible:

1. Open `VideoScreenshot.xcodeproj`.
2. Select the `VideoScreenshot` scheme.
3. Select Any Mac or the appropriate archive destination.
4. Choose Product > Archive.
5. Validate signing and entitlements in Organizer.
6. Export according to the intended distribution channel.

Command-line archive example:

```bash
xcodebuild \
  -project VideoScreenshot.xcodeproj \
  -scheme VideoScreenshot \
  -configuration Release \
  -archivePath build/VideoScreenshot.xcarchive \
  archive
```

### Versioning

Version values currently come from `VideoScreenshot/Info.plist`:

- `CFBundleShortVersionString`: `1.0`
- `CFBundleVersion`: `1`

Update these before release if the build is intended for external distribution.

## Deployment Process

### Distribution Model

VideoScreenshot is a local macOS application. There is no backend deployment, database migration, container image, or server rollout process in the current repository.

### Manual Deployment

1. Build or archive the app with the Release configuration.
2. Export the signed `.app` or packaged installer according to the chosen distribution channel.
3. Move the app into `/Applications` or another user-approved app location.
4. Launch the app once.
5. Grant Screen Recording and any requested audio-related permissions in System Settings.
6. Restart the app if macOS requires a restart after privacy changes.
7. Run the manual validation flows in `specs/001-screen-capture-export/quickstart.md`.

### Rollback

1. Quit VideoScreenshot.
2. Replace the installed app with the previous signed build.
3. Launch the previous version.
4. Confirm previously selected folders still resolve or reselect them from Settings.
5. Run a short capture smoke test.

Application settings are stored in UserDefaults. If a rollback has incompatible settings, reset app preferences or choose folders/file names again from the UI.

## Health Checks

There are no HTTP health endpoints because the product is a local desktop app. Use operational smoke checks instead.

| Check | Expected Result |
|-------|-----------------|
| Launch app | Main window opens and state badge shows Idle. |
| Select area | State badge changes to Ready and the Capture Area card shows dimensions. |
| Start blocked without area | Record button is disabled or capture reports a recoverable invalid-area error. |
| MP4 smoke capture | Short MP4 finalizes and opens from the reported path. |
| GIF smoke capture | Short GIF finalizes, opens, loops, and has no audio. |
| Permission recovery | Denied capture permission produces actionable recovery text. |

## Operational Procedures

### Permission Setup

1. Launch VideoScreenshot.
2. Attempt a capture if permissions have not yet been prompted.
3. Open System Settings > Privacy and Security.
4. Grant Screen Recording access to VideoScreenshot.
5. Grant audio-related access if macOS prompts for the MP4 audio path.
6. Restart the app if macOS requires it.

### Log and Failure Evidence

For developer troubleshooting, run the app from Xcode and inspect the debug console. For test evidence, capture command output:

```bash
xcodebuild -project VideoScreenshot.xcodeproj -scheme VideoScreenshot -destination 'platform=macOS' test | tee /tmp/videoscreenshot-xcodebuild-test.log
```

For user-facing export failures, preserve any temporary artifact path listed in `CaptureError.preservedArtifacts` before retrying or quitting.

### Storage Operations

- Use a stable local folder for final outputs.
- Use a local temporary folder with enough free space for long recordings.
- Avoid disconnected external drives during capture or finalization.
- GIF export is memory-limited. Prefer MP4 for long recordings.

### Release Checklist

1. Confirm version and build numbers in `Info.plist`.
2. Confirm signing team and entitlements in `project.yml` and the built app.
3. Run the full Xcode test suite.
4. Run an MP4 manual smoke capture with audible system audio.
5. Run a GIF manual smoke capture.
6. Validate permission denial and invalid-folder error paths.
7. Archive and export the signed app.
8. Install the exported app on a clean or secondary macOS user profile and repeat smoke checks.


## Source Evidence

This document is based on:

- Codebase-memory MCP project `Volumes-WDBlack4TB-Code-VideoScreenshot`: index status ready, 885 nodes, 1350 edges.
- Codebase-memory MCP graph searches for Capture, Export, and Settings components.
- Codebase-memory MCP trace_path results for `start`, `stop`, `CaptureCoordinator`, `ScreenCaptureService`, `SystemAudioCaptureService`, `MP4ExportService`, `GIFExportService`, and `OutputSettingsStore`.
- Source files under `VideoScreenshot/App`, `VideoScreenshot/Capture`, `VideoScreenshot/Export`, `VideoScreenshot/RegionSelection`, and `VideoScreenshot/UI`.
- Spec Kit files under `specs/001-screen-capture-export/`.
- Verification log `/tmp/videoscreenshot-xcodebuild-test.log`, which contains one `** TEST SUCCEEDED **` marker and no build/test error markers in the parsed verification pass.

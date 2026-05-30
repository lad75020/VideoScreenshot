# User Guide

## Features

### Select a Screen Area

VideoScreenshot lets you choose the part of the screen you want to record. Use the Select Area button, drag over the desired region, and release the mouse to keep that region for review before recording.

What it does: Stores a valid capture area with pixel dimensions and display information.
When to use it: Before every recording, or whenever you want to change what will be captured.

### Record to MP4

MP4 mode records the selected screen area at 24 frames per second and captures default system output audio when available. The current implementation writes HEVC/H.265 video and AAC audio in an MP4 file.

What it does: Creates a local MP4 recording in your configured output folder.
When to use it: For longer recordings, recordings that need audio, or files intended for editing or sharing.

### Record to Animated GIF

GIF mode records the selected screen area as a silent animated GIF. GIF output never includes audio.

What it does: Creates a looping animated GIF in your configured output folder.
When to use it: For short visual clips, quick demos, or places where silent animation is enough.

### Configure Output Settings

The Output panel lets you choose the format, final file name, temporary folder, and output folder. The app validates folders before starting capture and stores selected folders for future launches.

What it does: Controls where files are written and how they are named.
When to use it: Before starting a recording, especially when recording large files or changing destination folders.

### Review Completion and Errors

After a successful export, the app reports the saved file path. If something blocks capture or export, the app shows an actionable error and may preserve temporary artifacts if finalization failed.

What it does: Keeps capture state understandable and gives recovery guidance.
When to use it: After stopping a recording or when Start Capture is blocked.

## Usage Instructions

### Select a Capture Area

Prerequisites: The app is open and not recording.

1. Click Select Area.
2. Drag over the part of the screen you want to record.
3. Release the mouse button.
4. Confirm the Capture Area card shows a selected region and pixel size.

Expected result: The state badge changes to Ready and recording can be started.

### Create an MP4 Recording

Prerequisites: Screen Recording permission is available, output folders are writable, and your Mac supports HEVC writing.

1. Choose MP4 in the Output section.
2. Enter a file name without path separators.
3. Choose a writable temporary folder.
4. Choose a writable output folder.
5. Click Select Area and select the region to record.
6. Start any system audio you want included.
7. Click the record button to start capture.
8. Wait while the state badge shows Recording.
9. Click the stop button.
10. Wait while the state badge shows Finalizing.
11. Use the saved path reported by the app to open the MP4 file.

Expected result: The final file is an MP4 with HEVC video and AAC audio if audio samples were captured.

### Create an Animated GIF

Prerequisites: Screen Recording permission is available, output folders are writable, and the selected region/duration is small enough for GIF memory limits.

1. Choose GIF in the Output section.
2. Enter a file name without path separators.
3. Choose a writable temporary folder.
4. Choose a writable output folder.
5. Click Select Area and select the region to record.
6. Click the record button to start capture.
7. Record a short visual sequence.
8. Click the stop button.
9. Wait for finalization.
10. Open the saved GIF in a browser or image viewer.

Expected result: The final file is a silent looping GIF.

### Reveal or Copy the Saved File Path

Prerequisites: A recording has completed successfully.

1. Review the saved path in the status area.
2. Use the reveal action to open Finder at the saved file when available.
3. Use the copy action to copy the path when available.

Expected result: You can locate the exported recording without searching manually.

## Configuration

| Option | Type | Default | Required | Description |
|--------|------|---------|----------|-------------|
| Output format | `mp4` or `gif` | `mp4` | Yes | Selects MP4 with audio-capable export or silent GIF export. |
| File name | Text | `Capture` | Yes | Base output name. The app adds `.mp4` or `.gif`. Must be non-empty and cannot contain `/` or `:`. |
| Temporary folder | Folder URL | System temporary directory | Yes | Folder used for intermediate validation or artifacts. Must exist and be writable. |
| Output folder | Folder URL | User Movies directory, falling back to system temporary directory | Yes | Final destination for completed recordings. Must exist and be writable. |
| Overwrite policy | `ask`, `rename`, `cancel` | `ask` in the model | Yes | Determines behavior when a final file already exists. Current UI exposes safe file naming behavior through the configured name and recoverable duplicate-file errors. |

Selected folder access is persisted through security-scoped bookmark data in app settings.

## Common Workflows

### Record a Short Demo With Audio

Features involved: area selection, MP4 export, output settings, final path reporting.

1. Choose MP4.
2. Select an output folder in Movies or another writable user-selected folder.
3. Enter a descriptive file name.
4. Select a small screen area around the app or content you want to demonstrate.
5. Start playback of any system audio that should be captured.
6. Start capture.
7. Perform the demo.
8. Stop capture.
9. Open the saved MP4 from the reported path.

Result: You have a local MP4 demo with video and system audio.

### Create a Silent GIF for Visual Sharing

Features involved: area selection, GIF export, folder validation.

1. Choose GIF.
2. Select a small area to keep the GIF lightweight.
3. Record a short action.
4. Stop capture before the GIF grows too large.
5. Open the saved GIF from the reported path.

Result: You have a silent animated GIF suitable for visual previews or short documentation clips.

### Recover From a Blocked Start

Features involved: validation, permissions, error handling.

1. Read the error message and recovery action shown by the app.
2. If no area is selected, click Select Area and try again.
3. If permissions are denied, open System Settings and grant Screen Recording or audio capture access as requested.
4. If a folder is invalid, choose a writable temporary or output folder.
5. If the file exists, choose a different name or enable a safe rename path when available.
6. Try Start Capture again.

Result: The app either starts recording or gives a more specific recoverable error.

## Troubleshooting

### Start Capture is Disabled

Cause: No valid capture area is selected, or the app is already validating, recording, stopping, or finalizing.

Resolution:
1. Wait for any busy state to complete.
2. Click Select Area.
3. Select a non-empty region.
4. Confirm the state badge shows Ready.

Prevention: Select or reselect the capture area before pressing the record button.

### Select an Area Before Starting Capture

Cause: Capture was started without a valid selected area.

Resolution:
1. Click Select Area.
2. Drag over a non-empty region.
3. Release the mouse button.
4. Start capture again.

Prevention: Confirm the Capture Area card shows dimensions before recording.

### Permission Denied

Cause: macOS has not granted the required capture permission, or a permission change requires an app restart.

Resolution:
1. Open System Settings.
2. Grant Screen Recording permission to VideoScreenshot.
3. Grant audio capture or microphone-related permission if macOS requests it for MP4 audio capture.
4. Restart the app if macOS asks.
5. Try capture again.

Prevention: Grant permissions when first prompted and restart after changing system privacy settings.

### Temporary Folder is Not Writable

Cause: The selected temporary folder does not exist, is not a directory, or cannot accept a probe file.

Resolution:
1. Choose a different temporary folder.
2. Prefer a local folder with enough free disk space.
3. Try Start Capture again.

Prevention: Avoid read-only, disconnected, or permission-restricted folders.

### Final Output Folder is Not Writable

Cause: The selected output folder does not exist, cannot be accessed through the sandbox, or cannot accept a probe file.

Resolution:
1. Choose the output folder again from the app so macOS grants access.
2. Confirm the folder exists and is writable in Finder.
3. Try Start Capture again.

Prevention: Use user-selected folders and avoid disconnected volumes.

### File Already Exists

Cause: A file with the configured final name and extension already exists.

Resolution:
1. Enter a different file name, or use a safe rename option when available.
2. Start capture again.

Prevention: Use descriptive names or include dates/takes in file names.

### GIF Recording is Too Large

Cause: GIF export buffers frames in memory and reached its frame or pixel safety limits.

Resolution:
1. Stop sooner.
2. Select a smaller area.
3. Choose MP4 for longer recordings.

Prevention: Use GIF only for short, small visual clips.

### Finalization Failed

Cause: The media writer failed, the destination became unavailable, disk space ran out, or moving the temporary file failed.

Resolution:
1. Read the error message for preserved artifact paths.
2. Check output folder access and disk space.
3. Retry with a writable local folder.
4. Preserve any temporary artifact listed by the app before quitting.

Prevention: Use a stable local output folder with enough free space before long recordings.


## Source Evidence

This document is based on:

- Codebase-memory MCP project `Volumes-WDBlack4TB-Code-VideoScreenshot`: index status ready, 885 nodes, 1350 edges.
- Codebase-memory MCP graph searches for Capture, Export, and Settings components.
- Codebase-memory MCP trace_path results for `start`, `stop`, `CaptureCoordinator`, `ScreenCaptureService`, `SystemAudioCaptureService`, `MP4ExportService`, `GIFExportService`, and `OutputSettingsStore`.
- Source files under `VideoScreenshot/App`, `VideoScreenshot/Capture`, `VideoScreenshot/Export`, `VideoScreenshot/RegionSelection`, and `VideoScreenshot/UI`.
- Spec Kit files under `specs/001-screen-capture-export/`.
- Verification log `/tmp/videoscreenshot-xcodebuild-test.log`, which contains one `** TEST SUCCEEDED **` marker and no build/test error markers in the parsed verification pass.

# AGENTS.md

This file provides guidance to Codex (Codex.ai/code) when working with code in this repository.

## Build

This is a native macOS SwiftUI app. Open `ClipboardMenuBar.xcodeproj` in Xcode or build from the command line:

```bash
xcodebuild -project ClipboardMenuBar.xcodeproj -scheme ClipboardMenuBar -configuration Debug build
```

### Single-App Dev Workflow

To avoid duplicate app instances, duplicate Accessibility permission prompts, split clipboard history, and Launchpad confusion:

- Do not directly run `DerivedData/.../ClipboardMenuBar.app`.
- After rebuilding, replace `/Applications/ClipboardMenuBar.app` with the newly built app, then launch only `/Applications/ClipboardMenuBar.app`.
- If an old `ClipboardMenuBar` process is running, stop it before replacing the app.
- Treat `/Applications/ClipboardMenuBar.app` as the only app the user should ever interact with during development and testing.

Typical flow after a rebuild:

```bash
pkill -f 'ClipboardMenuBar.app/Contents/MacOS/ClipboardMenuBar' || true
rm -rf /Applications/ClipboardMenuBar.app
ditto ~/Library/Developer/Xcode/DerivedData/ClipboardMenuBar-*/Build/Products/Debug/ClipboardMenuBar.app /Applications/ClipboardMenuBar.app
open /Applications/ClipboardMenuBar.app
```

No package manager dependencies — the project uses only Apple frameworks (SwiftUI, SwiftData, AppKit, Carbon, CryptoKit, ServiceManagement).

- Deployment target: macOS 15.0
- Swift 5
- Bundle ID: `com.example.ClipboardMenuBar`

## Architecture

ClipboardMenuBar is a menu-bar-only clipboard history manager (LSUIElement = true). It runs as a status bar item and shows a floating panel for selecting past clipboard entries.

### Core flow

1. **ClipboardMonitor** polls `NSPasteboard.general` every 0.25s. On change, it hashes the content (SHA256) to create a signature, then saves text directly or offloads image processing to a background task.
2. **ClipboardStore** persists items via SwiftData (`ClipboardItem` model). It deduplicates by comparing the signature of the latest item and supports a suppress mechanism so that pasting an item back doesn't re-capture it.
3. **PasteService** writes the selected item to the system pasteboard, then synthesizes Cmd+V via CGEvent to auto-paste into the previously active app. This requires Accessibility permission.
4. **HotKeyManager** registers a global Option+V hotkey via Carbon EventHotKey API to toggle the panel.

### Key design details

- **Signature-based dedup**: Both `ClipboardMonitor` and `PasteService` compute SHA256 signatures with a "text-" or "image-" prefix. `ClipboardStore.suppressNextCapture()` prevents re-capturing an item that was just pasted.
- **Image storage**: `ImageStorage` saves clipboard images as PNG files in `~/Library/Application Support/<bundleID>/Images/`. Each `ClipboardItem` stores only the relative filename; preview thumbnails (120px max) are stored inline as `previewData`.
- **Panel positioning**: `PanelController` uses a non-activating `NSPanel` (HUD style, statusBar level) that floats above all windows and closes on resign-key. It remembers `targetApplication` before showing so it can re-activate it after paste.
- **Keyboard navigation**: `ClipboardListView` embeds a `KeyView` (NSViewRepresentable) as first responder to handle arrow keys (↑↓), Enter (paste), and Escape (close).
- **Pin support**: Items can be pinned; pinned items sort before unpinned and are excluded from clear/trim operations. Max 100 unpinned items.

### Services singleton

`AppServices` (singleton, `@MainActor`) owns the entire object graph: `ModelContainer`, `ClipboardStore`, `PanelController`, `ClipboardMonitor`, `HotKeyManager`. It also manages system state polling (accessibility permission, launch-at-login via SMAppService) on a 1-second timer.

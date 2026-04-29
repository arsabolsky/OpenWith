# OpenWith Codebase Guidelines

## Project Overview

**OpenWith** is a native macOS Swift application that intercepts clicked HTTP/HTTPS links and presents a custom, keyboard-driven floating window (HUD) to allow the user to select which installed browser—and specifically, which browser *profile*—to open the link in. It serves as a free, open-source alternative to premium routing apps like OpenIn.

**Core Technologies:**
*   **Language:** Swift 5+
*   **UI Framework:** SwiftUI (for the Picker and Settings), AppKit (for window management and application lifecycle).
*   **Build System:** Swift Package Manager (SPM) wrapped in a custom shell script (`bundle.sh`).
*   **Key Frameworks:** `Cocoa`, `SwiftUI`, `ServiceManagement` (for Launch at Login), `ApplicationServices` (Accessibility/AppleEvents).

**Architecture:**
*   **`main.swift` (AppDelegate):** The central controller. Registers the URL handler (`NSAppleEventManager`), manages the application lifecycle, handles the floating `NSPanel` for the picker, and manages the main window for Settings/Setup. It also checks system permissions (Accessibility & Automation).
*   **`AppDiscovery.swift`:** The engine that scans the system for browsers. 
    *   *Chromium* (Chrome, Edge, Brave, Arc, Helium): Parses `Local State` JSON files to identify profile names and folder IDs.
    *   *Firefox*: Queries the `Profile Groups` SQLite databases (or falls back to parsing `profiles.ini`) to map user-friendly names to profile paths.
    *   *Safari*: Uses Dynamic UI Scripting (AppleScript) to query the `File` menu and submenus to identify available Safari profiles.
*   **`PickerView.swift`:** A SwiftUI view rendered inside a borderless `NSPanel`. Features a custom `KeyEventsView` (`NSViewRepresentable` local event monitor) to strictly handle keyboard navigation (Up/Down, Enter, 1-9 shortcuts, Escape) without losing focus.
*   **`SettingsView.swift`:** UI for managing hidden browsers/profiles, toggling "Launch at Login", and checking/requesting system permissions.
*   **`SetupView.swift`:** The initial onboarding flow.

## Building and Running

Because OpenWith relies on strict macOS App Bundle structures (for `Info.plist` registration and Entitlements) to act as a default browser, **do not build via Xcode or bare `swift build` for testing.**

Always use the provided build script:

```bash
./bundle.sh
```

**What `bundle.sh` does:**
1.  Compiles the Swift code using SPM (`swift build`).
2.  Creates the `OpenWith.app` directory structure.
3.  Copies the compiled executable, `Info.plist`, and `AppIcon.icns` into the bundle.
4.  Kills any currently running instance of `OpenWith` (using `pkill -x`).
5.  Copies the `.app` bundle to `/Applications/`.
6.  Registers the app with Launch Services (`lsregister`) so macOS knows it can handle `http/https` links.
7.  Launches the new build in the background, redirecting stdout/stderr to `/tmp/openwith.log`.

**Debugging:**
To view logs or debug crashes:
```bash
cat /tmp/openwith.log
# Or follow live:
tail -f /tmp/openwith.log
```

## Development Conventions

*   **UI Scripting (Safari):** Safari provides no API for profile management. All Safari interaction MUST rely on AppleScript communicating with `System Events` -> `process "Safari"`. This requires the app to have Accessibility permissions.
*   **Keystroke Injection:** When launching a Safari profile, NEVER use the AppleScript `open location` command, as it fails to respect the newly created profile window. Instead, use Keystroke Injection (`Cmd+L` -> paste -> `Return`) or directly set the document URL (`set URL of document 1 to ...`) to guarantee the link opens in the correct profile context.
*   **Window Management:** The Picker uses an `NSPanel` with the `.nonactivatingPanel` and `.hudWindow` style masks. This prevents the app from aggressively stealing main focus from the application where the user clicked the link, while still allowing a local `NSEvent` monitor to capture keystrokes.
*   **Concurrency & Caching:** Browser discovery (especially the Safari AppleScript) can be slow. `AppDelegate.refreshBrowserCache()` runs asynchronously on a background queue. The `PickerView` uses an `@ObservedObject` to reactively update its list when discovery finishes.
*   **Profile IDs:** Always prefix discovered profile IDs with the parent browser's bundle identifier (e.g., `com.apple.Safari:Personal`) to ensure global uniqueness and prevent state collisions in the Settings UI. Strip this prefix in `main.swift` right before passing the argument to the `open` command.
*   **No "Just-In-Case" Code:** The app explicitly dropped its "Rules Engine" feature to remain a lean, manual picker. Do not re-introduce automatic routing features unless explicitly requested.

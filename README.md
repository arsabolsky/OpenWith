# OpenWith

A macOS utility to intercept and route links, emails, and files to specific applications based on customizable rules.

## Features
- **Link Interception:** Acts as a default browser to capture clicks.
- **Rules Engine:** Auto-route links based on domains, regex, or file extensions.
- **App Picker:** Shows a floating picker UI when no rule matches.
- **Settings:** Manage your rules via a native macOS interface.

## How to use
1. Build the app using `swift build`.
2. Run the executable: `.build/debug/OpenWith`.
3. Set OpenWith as your default browser in macOS System Settings.
4. Click any link!

## Implementation Details
- **Swift & SwiftUI:** Native macOS performance and look.
- **NSApplicationDelegate:** Captures AppleEvents for link handling.
- **UserDefaults:** Persists user rules.

## Future Plans
- [ ] Browser profile support (Chrome, Arc, etc.)
- [ ] Mailto link routing.
- [ ] Modifier key overrides (e.g., hold ⌥ to force picker).

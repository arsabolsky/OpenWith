# OpenWith 🔗

### The ultimate free, open-source alternative to OpenIn for macOS.

**OpenWith** is a lightweight, ultra-fast macOS utility that acts as your default web browser. Instead of being locked into one browser, OpenWith intercepts every link you click and presents a beautiful, keyboard-driven floating picker that lets you choose exactly which browser—and which **profile**—to use.

Designed for power users who juggle multiple Chrome, Safari, and Firefox profiles for work, personal, and development use.

---

## 🚀 Key Features

*   **Automatic Browser Discovery:** Instantly finds every browser installed on your Mac.
*   **Deep Profile Support:**
    *   **Chromium (Chrome, Brave, Edge, Arc, Vivaldi, Helium):** Automatically parses `Local State` files to find your profiles.
    *   **Safari:** Uses advanced UI scripting to discover and switch between your Safari profiles (something most alternatives can't do!).
    *   **Firefox:** Supports modern Firefox "Profile Groups" and SQLite-based profile discovery.
*   **Keyboard First Navigation:**
    *   **Numbers 1-9:** Instant launch.
    *   **Arrow Keys + Enter:** Smooth selection.
    *   **ESC:** Quick dismiss.
*   **Privacy & Control:** Easily hide browsers or specific profiles you don't need from the picker via a streamlined Settings menu.
*   **Launch at Login:** Automatically stays ready in your menu bar.
*   **Copy to Clipboard:** Quickly copy the intercepted URL with a single click in the picker.
*   **100% Free & Open Source:** No subscriptions, no tracking, just a native Swift tool.

---

## 🛠️ How It Works (The "Secret Sauce")

OpenWith uses the same reverse-engineered logic found in premium tools like OpenIn to handle the trickiest parts of macOS:

1.  **Safari Profiles:** Since Apple provides no API for Safari profiles, OpenWith dynamically scans Safari's `File > New Window` menu using AppleScript to find your active profiles.
2.  **Stable Launching:** We don't just use `open location`. For Safari, we use native AppleScript window targeting to ensure the link hits the *correct* profile window every time. For Chromium, we use `open -na` with the `--profile-directory` flag to force profile isolation.
3.  **Persistence:** Your profiles and settings are cached and persisted, so the UI is instantaneous even if your browsers aren't running.

---

## 📦 Installation & Setup

1.  **Clone & Build:**
    ```bash
    git clone https://github.com/arsabolsky/OpenWith.git
    cd OpenWith
    ./bundle.sh
    ```
2.  **Onboarding:** On first launch, OpenWith will guide you through:
    *   Granting **Accessibility permissions** (required for Safari profile switching).
    *   Setting OpenWith as your **Default Browser** in macOS System Settings.
3.  **Enjoy:** Click any link in your email, Slack, or terminal, and watch the picker appear!

---

## 🤝 Contributing

This is a community-driven alternative to paid routing apps. Contributions, bug reports, and feature requests are welcome!

*   **Language:** Swift / SwiftUI
*   **Platform:** macOS 12.0+
*   **License:** MIT

---

**OpenWith** — Stop opening work links in your personal browser. Take control of your web routing today.

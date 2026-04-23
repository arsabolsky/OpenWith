import Cocoa
import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate, ObservableObject {
    var statusItem: NSStatusItem?
    var pickerWindow: NSWindow?
    @Published var rules: [Rule] = []

    func applicationDidFinishLaunching(_ notification: Notification) {
        loadRules()
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "arrow.up.right.square", accessibilityDescription: "OpenWith")
        }
        setupMenu()
        NSAppleEventManager.shared().setEventHandler(self, andSelector: #selector(handleAppleEvent(_:withReplyEvent:)), forEventClass: AEEventClass(kInternetEventClass), andEventID: AEEventID(kAEGetURL))
    }

    func loadRules() {
        if let data = UserDefaults.standard.data(forKey: "Rules"), let decoded = try? JSONDecoder().decode([Rule].self, from: data) { self.rules = decoded }
    }

    func saveRules() {
        if let encoded = try? JSONEncoder().encode(rules) { UserDefaults.standard.set(encoded, forKey: "Rules") }
    }

    func setupMenu() {
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Settings...", action: #selector(openSettings), keyEquivalent: ","))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit OpenWith", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        statusItem?.menu = menu
    }

    var settingsWindow: NSWindow?
    @objc func openSettings() {
        if settingsWindow == nil {
            let view = SettingsView(rules: Binding(get: { self.rules }, set: { self.rules = $0 }), onSave: { self.saveRules() })
            settingsWindow = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 500, height: 400), styleMask: [.titled, .closable, .miniaturizable, .resizable], backing: .buffered, defer: false)
            settingsWindow?.title = "OpenWith Settings"
            settingsWindow?.center()
            settingsWindow?.contentView = NSHostingView(rootView: view)
        }
        settingsWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc func handleAppleEvent(_ event: NSAppleEventDescriptor, withReplyEvent replyEvent: NSAppleEventDescriptor) {
        guard let urlString = event.paramDescriptor(forKeyword: keyDirectObject)?.stringValue, let url = URL(string: urlString) else { return }
        if let matchedRule = RulesEngine.match(url: url, rules: rules), let appUrl = NSWorkspace.shared.urlForApplication(withBundleIdentifier: matchedRule.targetAppBundleId) {
            let appInfo = ApplicationInfo(name: matchedRule.name, bundleIdentifier: matchedRule.targetAppBundleId, path: appUrl, icon: nil)
            var profile: BrowserProfile? = nil
            if let profileId = matchedRule.targetProfileId { profile = BrowserProfile(id: profileId, name: "") }
            self.open(url: url, in: appInfo, profile: profile)
            return
        }
        DispatchQueue.main.async { self.showAppPicker(for: url) }
    }
    
    func showAppPicker(for url: URL) {
        let browsers = AppDiscovery.getInstalledBrowsers()
        let contentView = PickerView(url: url, apps: browsers) { selectedApp, profile in
            self.open(url: url, in: selectedApp, profile: profile)
            self.closePicker()
        }
        if pickerWindow == nil {
            pickerWindow = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 300, height: 400), styleMask: [.borderless, .fullSizeContentView], backing: .buffered, defer: false)
            pickerWindow?.level = .floating
            pickerWindow?.isOpaque = false
            pickerWindow?.backgroundColor = .clear
            pickerWindow?.hasShadow = true
        }
        pickerWindow?.contentView = NSHostingView(rootView: contentView)
        let mouseLocation = NSEvent.mouseLocation
        pickerWindow?.setFrame(NSRect(x: mouseLocation.x - 150, y: mouseLocation.y - 200, width: 300, height: 400), display: true)
        pickerWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func open(url: URL, in app: ApplicationInfo, profile: BrowserProfile? = nil) {
        if app.bundleIdentifier == "com.apple.Safari" && profile != nil {
            openSafari(url: url, profile: profile!)
            return
        }
        
        let configuration = NSWorkspace.OpenConfiguration()
        if let profile = profile {
            if app.bundleIdentifier == "org.mozilla.firefox" {
                configuration.arguments = ["-P", profile.id]
            } else {
                configuration.arguments = ["--profile-directory=\(profile.id)"]
            }
        }
        
        NSWorkspace.shared.open([url], withApplicationAt: app.path, configuration: configuration) { _, error in
            if let error = error { print("NSWorkspace Open Error: \(error.localizedDescription)") }
        }
    }

    // Safari RE Strategy: UI Automation
    func openSafari(url: URL, profile: BrowserProfile) {
        let script = """
        tell application "Safari"
            activate
            tell application "System Events"
                tell process "Safari"
                    set menuName to "New \(profile.name) Window"
                    try
                        click menu item menuName of menu 1 of menu bar item "File" of menu bar 1
                    on error
                        return
                    end try
                end tell
            end tell
            repeat 20 times
                try
                    if (count of windows) > 0 then
                        set URL of document 1 of window 1 to "\(url.absoluteString)"
                        return
                    end if
                end try
                delay 0.1
            end repeat
        end tell
        """
        let task = Process()
        task.launchPath = "/usr/bin/osascript"
        task.arguments = ["-e", script]
        do { try task.run() } catch { print("Safari Launch Error: \(error)") }
    }

    func closePicker() { pickerWindow?.orderOut(nil) }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()

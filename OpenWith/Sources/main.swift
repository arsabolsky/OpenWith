import Cocoa
import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate, ObservableObject {
    var statusItem: NSStatusItem?
    var pickerWindow: NSWindow?
    @Published var rules: [Rule] = []

    func applicationDidFinishLaunching(_ notification: Notification) {
        loadRules()
        
        // Setup Menu Bar Item
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "arrow.up.right.square", accessibilityDescription: "OpenWith")
        }

        setupMenu()
        
        // Register for Apple Events (URLs)
        NSAppleEventManager.shared().setEventHandler(
            self,
            andSelector: #selector(handleAppleEvent(_:withReplyEvent:)),
            forEventClass: AEEventClass(kInternetEventClass),
            andEventID: AEEventID(kAEGetURL)
        )
    }

    func loadRules() {
        if let data = UserDefaults.standard.data(forKey: "Rules"),
           let decoded = try? JSONDecoder().decode([Rule].self, from: data) {
            self.rules = decoded
        } else {
            // Default rules for testing
            self.rules = [
                Rule(name: "Zoom", type: .domain, pattern: "zoom.us", targetAppBundleId: "us.zoom.xos")
            ]
        }
    }

    func saveRules() {
        if let encoded = try? JSONEncoder().encode(rules) {
            UserDefaults.standard.set(encoded, forKey: "Rules")
        }
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
            let view = SettingsView(rules: Binding(
                get: { self.rules },
                set: { self.rules = $0 }
            ), onSave: {
                self.saveRules()
            })
            
            settingsWindow = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 500, height: 400),
                styleMask: [.titled, .closable, .miniaturizable, .resizable],
                backing: .buffered,
                defer: false
            )
            settingsWindow?.title = "OpenWith Settings"
            settingsWindow?.center()
            settingsWindow?.contentView = NSHostingView(rootView: view)
        }
        
        settingsWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc func handleAppleEvent(_ event: NSAppleEventDescriptor, withReplyEvent replyEvent: NSAppleEventDescriptor) {
        guard let urlString = event.paramDescriptor(forKeyword: keyDirectObject)?.stringValue,
              let url = URL(string: urlString) else {
            return
        }
        
        // Rules Engine Matching
        if let matchedRule = RulesEngine.match(url: url, rules: rules),
           let appUrl = NSWorkspace.shared.urlForApplication(withBundleIdentifier: matchedRule.targetAppBundleId) {
            
            let appInfo = ApplicationInfo(name: matchedRule.name, bundleIdentifier: matchedRule.targetAppBundleId, path: appUrl, icon: nil)
            var profile: BrowserProfile? = nil
            if let profileId = matchedRule.targetProfileId {
                profile = BrowserProfile(id: profileId, name: "")
            }
            
            self.open(url: url, in: appInfo, profile: profile)
            return
        }
        
        DispatchQueue.main.async {
            self.showAppPicker(for: url)
        }
    }
    
    func showAppPicker(for url: URL) {
        let browsers = AppDiscovery.getInstalledBrowsers()
        
        let contentView = PickerView(url: url, apps: browsers) { selectedApp, profile in
            self.open(url: url, in: selectedApp, profile: profile)
            self.closePicker()
        }
        
        if pickerWindow == nil {
            pickerWindow = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 300, height: 400),
                styleMask: [.borderless, .fullSizeContentView],
                backing: .buffered,
                defer: false
            )
            pickerWindow?.level = .floating
            pickerWindow?.isOpaque = false
            pickerWindow?.backgroundColor = .clear
            pickerWindow?.hasShadow = true
        }
        
        pickerWindow?.contentView = NSHostingView(rootView: contentView)
        
        // Center on screen or follow mouse
        let mouseLocation = NSEvent.mouseLocation
        let windowWidth: CGFloat = 300
        let windowHeight: CGFloat = 400
        pickerWindow?.setFrame(NSRect(x: mouseLocation.x - windowWidth/2, y: mouseLocation.y - windowHeight/2, width: windowWidth, height: windowHeight), display: true)
        
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
            // Chromium browsers use --profile-directory
            configuration.arguments = ["--profile-directory=\(profile.id)"]
        }
        
        NSWorkspace.shared.open([url], withApplicationAt: app.path, configuration: configuration) { _, error in
            if let error = error {
                print("Error opening URL: \(error.localizedDescription)")
            }
        }
    }

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
            
            -- Wait for the new window/document to be ready
            repeat 20 times
                try
                    tell application "Safari"
                        if (count of windows) > 0 then
                            set URL of document 1 of window 1 to "\(url.absoluteString)"
                            return
                        end if
                    end tell
                end try
                delay 0.1
            end repeat
        end tell
        """
        
        let task = Process()
        task.launchPath = "/usr/bin/osascript"
        task.arguments = ["-e", script]
        
        do {
            try task.run()
        } catch {
            print("Error launching Safari profile: \(error)")
        }
    }

    func closePicker() {
        pickerWindow?.orderOut(nil)
    }
}

// Entry Point
let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()

import Cocoa
import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate, ObservableObject {
    var statusItem: NSStatusItem?
    var pickerWindow: NSWindow?
    @Published var rules: [Rule] = []
    @Published var isAccessibilityTrusted: Bool = false
    @Published var isAutomationAllowed: Bool = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        loadRules()
        checkPermissions()
        
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

    func applicationDidBecomeActive(_ notification: Notification) {
        checkPermissions()
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

    func checkPermissions() {
        isAccessibilityTrusted = AXIsProcessTrusted()
        
        // Check Automation (Apple Events) for Safari
        if #available(macOS 10.14, *) {
            let safariTarget = NSAppleEventDescriptor(bundleIdentifier: "com.apple.Safari")
            if let aeDescPointer = safariTarget.aeDesc {
                let status = AEDeterminePermissionToAutomateTarget(aeDescPointer, AEEventClass(typeWildCard), AEEventID(typeWildCard), true)
                isAutomationAllowed = (status == noErr)
            } else {
                isAutomationAllowed = false
            }
        } else {
            isAutomationAllowed = true
        }
    }

    func requestPermissions() {
        let options = [kAXTrustedCheckOptionPrompt.takeRetainedValue() as String: true]
        AXIsProcessTrustedWithOptions(options as CFDictionary)
        
        // Triggering an AppleScript usually prompts for Automation if not determined
        let script = NSAppleScript(source: "tell application \"Safari\" to get name")
        script?.executeAndReturnError(nil)
        
        // Polling for status change might be overkill, let's just check again after a short delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.checkPermissions()
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
            let view = SettingsView(appDelegate: self, rules: Binding(
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
        
        print("Intercepted URL: \(url)")
        
        // Rules Engine Matching
        if let matchedRule = RulesEngine.match(url: url, rules: rules),
           let appUrl = NSWorkspace.shared.urlForApplication(withBundleIdentifier: matchedRule.targetAppBundleId) {
            print("Auto-routing to \(matchedRule.targetAppBundleId) due to rule: \(matchedRule.name)")
            
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
        if app.bundleIdentifier == "com.apple.Safari", let profile = profile {
            self.launchSafari(url: url, profile: profile)
            return
        }
        
        let configuration = NSWorkspace.OpenConfiguration()
        if let profile = profile {
            configuration.arguments = ["--profile-directory=\(profile.id)"]
        }
        NSWorkspace.shared.open([url], withApplicationAt: app.path, configuration: configuration) { _, error in
            if let error = error {
                print("Error opening URL: \(error.localizedDescription)")
            }
        }
    }

    func launchSafari(url: URL, profile: BrowserProfile) {
        if !AXIsProcessTrusted() {
            print("Accessibility permissions missing for Safari UI scripting")
            requestPermissions()
            return
        }

        let scriptSource = """
        tell application "Safari"
            activate
            tell application "System Events"
                tell process "Safari"
                    if exists menu bar item "Profiles" of menu bar 1 then
                        click menu item "\(profile.name)" of menu 1 of menu bar item "Profiles" of menu bar 1
                    end if
                end tell
            end tell
            open location "\(url.absoluteString)"
        end tell
        """
        
        if let script = NSAppleScript(source: scriptSource) {
            var error: NSDictionary?
            script.executeAndReturnError(&error)
            if let err = error {
                print("Safari AppleScript error: \(err)")
            }
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

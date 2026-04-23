import Cocoa
import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate, ObservableObject {
    var statusItem: NSStatusItem?
    var pickerWindow: NSWindow?
    
    @Published var isAccessibilityTrusted: Bool = false
    @Published var isAutomationAllowed: Bool = false
    @Published var cachedBrowsers: [ApplicationInfo] = []
    
    @Published var hiddenBundleIds: Set<String> = []
    @Published var hiddenProfileIds: Set<String> = []
    
    private var isRefreshingCache = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        loadHiddenItems()
        checkPermissions()
        refreshBrowserCache()
        
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
        
        // Check for initial setup
        if !UserDefaults.standard.bool(forKey: "SetupCompleted") {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                self.openSetup()
            }
        }
    }

    func applicationDidBecomeActive(_ notification: Notification) {
        checkPermissions()
        refreshBrowserCache()
    }

    func refreshBrowserCache() {
        guard !isRefreshingCache else { return }
        isRefreshingCache = true
        
        DispatchQueue.global(qos: .userInitiated).async {
            let browsers = AppDiscovery.getInstalledBrowsers()
            
            DispatchQueue.main.async {
                self.cachedBrowsers = browsers
                self.isRefreshingCache = false
            }
        }
    }

    func loadHiddenItems() {
        if let bundles = UserDefaults.standard.stringArray(forKey: "HiddenBundleIds") {
            self.hiddenBundleIds = Set(bundles)
        }
        if let profiles = UserDefaults.standard.stringArray(forKey: "HiddenProfileIds") {
            self.hiddenProfileIds = Set(profiles)
        }
    }

    func saveHiddenItems() {
        UserDefaults.standard.set(Array(hiddenBundleIds), forKey: "HiddenBundleIds")
        UserDefaults.standard.set(Array(hiddenProfileIds), forKey: "HiddenProfileIds")
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
        
        let script = NSAppleScript(source: "tell application \"Safari\" to get name")
        script?.executeAndReturnError(nil)
        
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
            let view = SettingsView(appDelegate: self)
            
            settingsWindow = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 500, height: 500),
                styleMask: [.titled, .closable, .miniaturizable, .resizable],
                backing: .buffered,
                defer: false
            )
            settingsWindow?.title = "OpenWith Settings"
            settingsWindow?.center()
            settingsWindow?.contentView = NSHostingView(rootView: view)
            settingsWindow?.isReleasedWhenClosed = false
        }
        
        settingsWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    var setupWindow: NSWindow?
    
    @objc func openSetup() {
        if setupWindow == nil {
            let view = SetupView(appDelegate: self)
            
            setupWindow = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 400, height: 450),
                styleMask: [.titled, .closable],
                backing: .buffered,
                defer: false
            )
            setupWindow?.title = "Welcome to OpenWith"
            setupWindow?.center()
            setupWindow?.contentView = NSHostingView(rootView: view)
            setupWindow?.isReleasedWhenClosed = false
        }
        
        setupWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc func handleAppleEvent(_ event: NSAppleEventDescriptor, withReplyEvent replyEvent: NSAppleEventDescriptor) {
        guard let urlString = event.paramDescriptor(forKeyword: keyDirectObject)?.stringValue,
              let url = URL(string: urlString) else {
            return
        }
        
        print("Intercepted URL: \(url)")
        
        DispatchQueue.main.async {
            self.showAppPicker(for: url)
        }
    }
    
    func showAppPicker(for url: URL) {
        // Filter out hidden items
        let visibleApps = cachedBrowsers.compactMap { app -> ApplicationInfo? in
            if hiddenBundleIds.contains(app.bundleIdentifier) { return nil }
            var filteredApp = app
            filteredApp.profiles = app.profiles.filter { !hiddenProfileIds.contains($0.id) }
            return filteredApp
        }
        
        let contentView = PickerView(url: url, apps: visibleApps, onSelect: { selectedApp, profile in
            self.open(url: url, in: selectedApp, profile: profile)
            self.closePicker()
        }, onCancel: {
            self.closePicker()
        })
        
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
            
            // Close when losing focus
            NotificationCenter.default.addObserver(self, selector: #selector(closePicker), name: NSApplication.didResignActiveNotification, object: nil)
        }
        
        pickerWindow?.contentView = NSHostingView(rootView: contentView)
        
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
        
        if let profile = profile {
            let chromiumIds = ["com.google.Chrome", "com.google.Chrome.canary", "org.chromium.Chromium", "com.microsoft.edgemac", "com.brave.Browser", "company.thebrowser.Browser", "com.vivaldi.Vivaldi", "net.imput.helium"]
            let isChromium = chromiumIds.contains(app.bundleIdentifier)
            let isFirefox = app.bundleIdentifier == "org.mozilla.firefox"
            
            if isChromium || isFirefox {
                let process = Process()
                process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
                
                var arguments = ["-na", app.path.path]
                if isChromium {
                    arguments.append(contentsOf: ["--args", "--profile-directory=\(profile.id)"])
                } else if isFirefox {
                    arguments.append(contentsOf: ["--args", "--new-instance", "--profile", profile.id])
                }
                arguments.append(url.absoluteString)
                
                process.arguments = arguments
                
                do {
                    try process.run()
                    return
                } catch {
                    print("Failed to launch \(app.name) profile via Process: \(error)")
                }
            }
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
        set theURL to "\(url.absoluteString)"
        
        tell application "Safari" to activate
        delay 0.3
        
        tell application "System Events"
            tell process "Safari"
                set frontmost to true
                try
                    try
                        tell menu bar item "File" of menu bar 1
                            tell menu 1
                                tell menu item "New Window"
                                    click menu item "\(profile.id)" of menu 1
                                end tell
                            end tell
                        end tell
                    on error
                        tell menu bar item "File" of menu bar 1
                            tell menu 1
                                click menu item "\(profile.id)"
                            end tell
                        end tell
                    end try
                on error errMsg
                    log "Error clicking Safari menu: " & errMsg
                end try
            end tell
        end tell
        
        delay 0.6
        
        tell application "Safari"
            try
                set URL of document 1 to theURL
            on error errMsg
                log "Error setting URL: " & errMsg
                open location theURL
            end try
        end tell
        """
        
        if let script = NSAppleScript(source: scriptSource) {
            var error: NSDictionary?
            script.executeAndReturnError(&error)
        }
    }
    
    @objc func closePicker() {
        pickerWindow?.orderOut(nil)
    }
}

// Entry Point
print("OpenWith started")
fflush(stdout)
let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()

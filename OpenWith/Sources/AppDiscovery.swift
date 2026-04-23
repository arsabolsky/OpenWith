import AppKit

struct BrowserProfile: Identifiable, Codable, Hashable {
    var id: String // Profile directory name (e.g., "Default", "Profile 1")
    var name: String // User-visible name
}

struct ApplicationInfo: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let bundleIdentifier: String
    let path: URL
    let icon: NSImage?
    var profiles: [BrowserProfile] = []
}

class AppDiscovery {
    static func getInstalledBrowsers() -> [ApplicationInfo] {
        let workspace = NSWorkspace.shared
        let httpsUrl = URL(string: "https://")!
        let appUrls = workspace.urlsForApplications(toOpen: httpsUrl)
        
        var apps: [ApplicationInfo] = []
        let myBundleId = Bundle.main.bundleIdentifier
        
        for path in appUrls {
            guard let bundleId = Bundle(url: path)?.bundleIdentifier else { continue }
            if bundleId == myBundleId { continue }
            
            let name = (try? path.resourceValues(forKeys: [.localizedNameKey]).localizedName) ?? path.deletingPathExtension().lastPathComponent
            let icon = workspace.icon(forFile: path.path)
            
            var appInfo = ApplicationInfo(name: name, bundleIdentifier: bundleId, path: path, icon: icon)
            
            if isChromiumBased(bundleId: bundleId) {
                appInfo.profiles = discoverChromiumProfiles(bundleId: bundleId)
            } else if bundleId == "com.apple.Safari" {
                appInfo.profiles = discoverSafariProfiles()
            }
            
            if !apps.contains(where: { $0.bundleIdentifier == bundleId }) {
                apps.append(appInfo)
            }
        }
        
        return apps.sorted { $0.name < $1.name }
    }
    
    private static func discoverSafariProfiles() -> [BrowserProfile] {
        // Check if Safari is running. If not, we can't use UI Scripting.
        let runningSafari = NSWorkspace.shared.runningApplications.first(where: { $0.bundleIdentifier == "com.apple.Safari" })
        
        if runningSafari == nil {
            // Safari isn't running, return an empty list or just "Personal"
            return [BrowserProfile(id: "Personal", name: "Personal")]
        }

        let script = """
        tell application "System Events"
            tell process "Safari"
                try
                    -- Ensure we have the File menu
                    if exists (menu bar item "File" of menu bar 1) then
                        return name of menu items of menu 1 of menu bar item "File" of menu bar 1
                    else
                        return {}
                    end try
                on error
                    return {}
                end try
            end tell
        end tell
        """
        
        let task = Process()
        task.launchPath = "/usr/bin/osascript"
        task.arguments = ["-e", script]
        
        let pipe = Pipe()
        task.standardOutput = pipe
        
        do {
            try task.run()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let output = String(data: data, encoding: .utf8) {
                var profiles: [BrowserProfile] = []
                let items = output.components(separatedBy: ", ")
                for item in items {
                    let name = item.trimmingCharacters(in: .whitespacesAndNewlines)
                    if name.hasPrefix("New ") && name.hasSuffix(" Window") {
                        let profileName = name.replacingOccurrences(of: "New ", with: "")
                                              .replacingOccurrences(of: " Window", with: "")
                        
                        let standardNames = ["Private", "Tab", "Window", "Window to Group", "Private Window", ""]
                        if standardNames.contains(profileName) { continue }
                        
                        profiles.append(BrowserProfile(id: profileName, name: profileName))
                    }
                }
                
                // Always include Personal if not found
                if !profiles.contains(where: { $0.name == "Personal" }) {
                    profiles.insert(BrowserProfile(id: "Personal", name: "Personal"), at: 0)
                }
                
                return profiles
            }
        } catch {
            print("Error discovering Safari profiles: \(error)")
        }
        
        return [BrowserProfile(id: "Personal", name: "Personal")]
    }

    private static func isChromiumBased(bundleId: String) -> Bool {
        let chromiumIds = [
            "com.google.Chrome",
            "com.google.Chrome.canary",
            "org.chromium.Chromium",
            "com.microsoft.edgemac",
            "com.brave.Browser",
            "company.thebrowser.Browser", // Arc
            "com.vivaldi.Vivaldi",
            "net.imput.helium"
        ]
        return chromiumIds.contains(bundleId)
    }
    
    private static func discoverChromiumProfiles(bundleId: String) -> [BrowserProfile] {
        let supportDir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let browserSubDir: String
        
        switch bundleId {
        case "com.google.Chrome": browserSubDir = "Google/Chrome"
        case "com.google.Chrome.canary": browserSubDir = "Google/Chrome Canary"
        case "org.chromium.Chromium": browserSubDir = "Chromium"
        case "com.microsoft.edgemac": browserSubDir = "Microsoft Edge"
        case "com.brave.Browser": browserSubDir = "BraveSoftware/Brave-Browser"
        case "company.thebrowser.Browser": browserSubDir = "Arc"
        case "com.vivaldi.Vivaldi": browserSubDir = "Vivaldi"
        case "net.imput.helium": browserSubDir = "net.imput.helium"
        default: return []
        }
        
        let localStateUrl = supportDir.appendingPathComponent(browserSubDir).appendingPathComponent("Local State")
        guard let data = try? Data(contentsOf: localStateUrl),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let profile = json["profile"] as? [String: Any],
              let infoCache = profile["info_cache"] as? [String: Any] else {
            return []
        }
        
        var discoveredProfiles: [BrowserProfile] = []
        for (key, value) in infoCache {
            if let details = value as? [String: Any],
               let name = details["name"] as? String {
                discoveredProfiles.append(BrowserProfile(id: key, name: name))
            }
        }
        
        return discoveredProfiles.sorted { $0.name < $1.name }
    }
}

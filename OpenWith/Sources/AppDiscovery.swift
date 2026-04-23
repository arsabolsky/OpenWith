import AppKit

struct BrowserProfile: Identifiable, Codable, Hashable {
    var id: String // Profile directory name or name
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
            
            // Revert to strategies from RE findings
            if bundleId == "com.apple.Safari" {
                appInfo.profiles = discoverSafariProfiles()
            } else if isChromiumBased(bundleId: bundleId) {
                appInfo.profiles = discoverChromiumProfiles(bundleId: bundleId)
            } else if bundleId == "org.mozilla.firefox" {
                appInfo.profiles = discoverFirefoxProfiles()
            }
            
            if !apps.contains(where: { $0.bundleIdentifier == bundleId }) {
                apps.append(appInfo)
            }
        }
        
        return apps.sorted { $0.name < $1.name }
    }
    
    // 1. Safari Strategy: UI Scripting
    private static func discoverSafariProfiles() -> [BrowserProfile] {
        let script = """
        tell application "System Events"
            tell process "Safari"
                try
                    set fileMenu to menu 1 of menu bar item "File" of menu bar 1
                    return name of menu items of fileMenu
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
                        let profileName = name.replacingOccurrences(of: "New ", with: "").replacingOccurrences(of: " Window", with: "")
                        let standardNames = ["Private", "Tab", "Window", "Empty Tab Group", "Tab Group with This Tab", "Private Window", ""]
                        if standardNames.contains(profileName) { continue }
                        profiles.append(BrowserProfile(id: profileName, name: profileName))
                    }
                }
                if !profiles.contains(where: { $0.name == "Personal" }) {
                    profiles.insert(BrowserProfile(id: "Personal", name: "Personal"), at: 0)
                }
                return profiles
            }
        } catch { print("Safari RE Error: \(error)") }
        return [BrowserProfile(id: "Personal", name: "Personal")]
    }
    
    // 2. Chromium Strategy: File Analysis (Local State)
    private static func isChromiumBased(bundleId: String) -> Bool {
        let chromiumIds = ["com.google.Chrome", "com.google.Chrome.canary", "org.chromium.Chromium", "com.microsoft.edgemac", "com.brave.Browser", "company.thebrowser.Browser", "com.vivaldi.Vivaldi", "net.imput.helium"]
        return chromiumIds.contains(bundleId)
    }
    
    private static func discoverChromiumProfiles(bundleId: String) -> [BrowserProfile] {
        let supportDir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        var subDir = ""
        switch bundleId {
        case "com.google.Chrome": subDir = "Google/Chrome"
        case "com.microsoft.edgemac": subDir = "Microsoft Edge"
        case "com.brave.Browser": subDir = "BraveSoftware/Brave-Browser"
        case "company.thebrowser.Browser": subDir = "Arc"
        case "net.imput.helium": subDir = "net.imput.helium"
        default: subDir = bundleId
        }
        
        let localStateUrl = supportDir.appendingPathComponent(subDir).appendingPathComponent("Local State")
        guard let data = try? Data(contentsOf: localStateUrl),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let profile = json["profile"] as? [String: Any],
              let infoCache = profile["info_cache"] as? [String: Any] else { return [] }
        
        return infoCache.compactMap { (key, value) in
            if let details = value as? [String: Any], let name = details["name"] as? String {
                return BrowserProfile(id: key, name: name)
            }
            return nil
        }.sorted { $0.name < $1.name }
    }
    
    // 3. Firefox Strategy: File Analysis (profiles.ini)
    private static func discoverFirefoxProfiles() -> [BrowserProfile] {
        let supportDir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let iniUrl = supportDir.appendingPathComponent("Firefox/profiles.ini")
        guard let content = try? String(contentsOf: iniUrl, encoding: .utf8) else { return [] }
        
        var profiles: [BrowserProfile] = []
        let lines = content.components(separatedBy: .newlines)
        var currentName: String?
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.starts(with: "Name=") {
                currentName = trimmed.replacingOccurrences(of: "Name=", with: "")
            } else if trimmed.starts(with: "[Profile") || trimmed.isEmpty {
                if let name = currentName {
                    profiles.append(BrowserProfile(id: name, name: name))
                    currentName = nil
                }
            }
        }
        if let last = currentName { profiles.append(BrowserProfile(id: last, name: last)) }
        return profiles.sorted { $0.name < $1.name }
    }
}

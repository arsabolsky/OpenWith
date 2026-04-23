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
        
        // Dynamically find EVERY app registered for HTTPS
        let appUrls = workspace.urlsForApplications(toOpen: httpsUrl)
        
        var apps: [ApplicationInfo] = []
        let myBundleId = Bundle.main.bundleIdentifier
        
        for path in appUrls {
            guard let bundleId = Bundle(url: path)?.bundleIdentifier else { continue }
            if bundleId == myBundleId { continue }
            
            let name = (try? path.resourceValues(forKeys: [.localizedNameKey]).localizedName) ?? path.deletingPathExtension().lastPathComponent
            let icon = workspace.icon(forFile: path.path)
            
            var appInfo = ApplicationInfo(name: name, bundleIdentifier: bundleId, path: path, icon: icon)
            
            // Dynamically attempt to find profiles if it looks like a Chromium/Electron app
            appInfo.profiles = discoverProfiles(for: bundleId, appName: name)
            
            if !apps.contains(where: { $0.bundleIdentifier == bundleId }) {
                apps.append(appInfo)
            }
        }
        
        return apps.sorted { $0.name < $1.name }
    }
    
    private static func discoverProfiles(for bundleId: String, appName: String) -> [BrowserProfile] {
        let fileManager = FileManager.default
        let supportDir = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        
        // Map specific bundle IDs to their known Application Support sub-folders
        var possiblePaths: [String] = []
        
        switch bundleId {
        case "com.apple.Safari":
            return discoverSafariProfiles()
        case "com.google.Chrome": possiblePaths = ["Google/Chrome"]
        case "com.google.Chrome.canary": possiblePaths = ["Google/Chrome Canary"]
        case "org.chromium.Chromium": possiblePaths = ["Chromium"]
        case "com.microsoft.edgemac": possiblePaths = ["Microsoft Edge"]
        case "com.brave.Browser": possiblePaths = ["BraveSoftware/Brave-Browser"]
        case "company.thebrowser.Browser": possiblePaths = ["Arc"]
        case "com.vivaldi.Vivaldi": possiblePaths = ["Vivaldi"]
        case "net.imput.helium": possiblePaths = ["net.imput.helium"]
        case "org.mozilla.firefox":
            return discoverFirefoxProfiles()
        default:
            // For unknown apps, only check paths containing the app name or bundle ID
            possiblePaths = [appName, bundleId]
        }
        
        for subPath in possiblePaths {
            let localStateUrl = supportDir.appendingPathComponent(subPath).appendingPathComponent("Local State")
            if fileManager.fileExists(atPath: localStateUrl.path) {
                return parseChromiumProfiles(at: localStateUrl)
            }
        }
        
        return []
    }
    
    private static func parseChromiumProfiles(at url: URL) -> [BrowserProfile] {
        guard let data = try? Data(contentsOf: url),
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

    private static func discoverFirefoxProfiles() -> [BrowserProfile] {
        let fileManager = FileManager.default
        let supportDir = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let firefoxDir = supportDir.appendingPathComponent("Firefox")
        let profileGroupsDir = firefoxDir.appendingPathComponent("Profile Groups")
        
        var profiles: [BrowserProfile] = []
        var seenPaths = Set<String>()
        
        // Strategy 1: SQLite discovery (Newer Firefox / OpenIn style)
        if let groupFiles = try? fileManager.contentsOfDirectory(at: profileGroupsDir, includingPropertiesForKeys: nil) {
            for file in groupFiles where file.pathExtension == "sqlite" {
                let process = Process()
                process.executableURL = URL(fileURLWithPath: "/usr/bin/sqlite3")
                process.arguments = [file.path, "select path, name from Profiles;"]
                
                let outputPipe = Pipe()
                process.standardOutput = outputPipe
                
                try? process.run()
                process.waitUntilExit()
                
                let data = outputPipe.fileHandleForReading.readDataToEndOfFile()
                if let output = String(data: data, encoding: .utf8) {
                    let lines = output.components(separatedBy: .newlines)
                    for line in lines where !line.isEmpty {
                        let parts = line.components(separatedBy: "|")
                        if parts.count >= 2 {
                            let relPath = parts[0]
                            let name = parts[1]
                            let fullPath = firefoxDir.appendingPathComponent(relPath).path
                            
                            if !seenPaths.contains(fullPath) {
                                profiles.append(BrowserProfile(id: fullPath, name: name))
                                seenPaths.insert(fullPath)
                            }
                        }
                    }
                }
            }
        }
        
        // Strategy 2: profiles.ini discovery (Legacy / Fallback)
        if profiles.isEmpty {
            let profilesIniUrl = firefoxDir.appendingPathComponent("profiles.ini")
            if let content = try? String(contentsOf: profilesIniUrl, encoding: .utf8) {
                let lines = content.components(separatedBy: .newlines)
                var currentName: String?
                var currentPath: String?
                
                for line in lines {
                    let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
                    if trimmed.hasPrefix("[Profile") {
                        if let name = currentName, let path = currentPath {
                            let fullPath = path.hasPrefix("/") ? path : firefoxDir.appendingPathComponent(path).path
                            if !seenPaths.contains(fullPath) {
                                profiles.append(BrowserProfile(id: fullPath, name: name))
                                seenPaths.insert(fullPath)
                            }
                        }
                        currentName = nil
                        currentPath = nil
                    } else if trimmed.hasPrefix("Name=") {
                        currentName = String(trimmed.dropFirst(5))
                    } else if trimmed.hasPrefix("Path=") {
                        currentPath = String(trimmed.dropFirst(5))
                    }
                }
                
                if let name = currentName, let path = currentPath {
                    let fullPath = path.hasPrefix("/") ? path : firefoxDir.appendingPathComponent(path).path
                    if !seenPaths.contains(fullPath) {
                        profiles.append(BrowserProfile(id: fullPath, name: name))
                    }
                }
            }
        }
        
        return profiles.sorted { $0.name < $1.name }
    }

    private static func discoverSafariProfiles() -> [BrowserProfile] {
        print("Discovering Safari profiles via dynamic menu scanning...")
        let scriptSource = """
        tell application "System Events"
            if exists process "Safari" then
                tell process "Safari"
                    set foundNames to {}
                    try
                        -- Strategy: Scan the 'File' menu for 'New [Profile] Window'
                        tell menu 1 of menu bar item "File" of menu bar 1
                            -- Check direct menu items first
                            set allItems to name of every menu item
                            repeat with itemName in allItems
                                if itemName starts with "New " and itemName ends with " Window" then
                                    copy itemName to end of foundNames
                                end if
                            end repeat
                            
                            -- Also check submenus of 'New Window' just in case
                            try
                                set subItems to name of menu items of menu 1 of menu item "New Window"
                                repeat with subName in subItems
                                    if subName is not missing value and subName is not "" then
                                        copy subName to end of foundNames
                                    end if
                                end repeat
                            end try
                        end tell
                    on error
                        return {"_ERROR_"}
                    end try
                    return foundNames
                end tell
            else
                return {"_SAFARI_NOT_RUNNING_"}
            end if
        end tell
        """
        
        var discoveredProfiles: [BrowserProfile] = []
        if let script = NSAppleScript(source: scriptSource) {
            var error: NSDictionary?
            let result = script.executeAndReturnError(&error)
            
            if let err = error {
                print("Safari Profile Discovery AppleScript Error: \(err)")
            } else {
                let count = result.numberOfItems
                if count >= 1 {
                    let firstItem = result.atIndex(1)?.stringValue
                    if firstItem == "_SAFARI_NOT_RUNNING_" {
                        print("Safari is not running. Using cached profiles.")
                    } else if firstItem == "_ERROR_" {
                        print("Error during Safari menu scanning. Using cached profiles.")
                    } else {
                        var namesSet = Set<String>()
                        for i in 1...count {
                            if let fullName = result.atIndex(i)?.stringValue, !fullName.isEmpty {
                                if namesSet.contains(fullName) { continue }
                                namesSet.insert(fullName)
                                
                                var id = fullName
                                var displayName = fullName
                                
                                if fullName.hasPrefix("New ") && fullName.hasSuffix(" Window") {
                                    displayName = String(fullName.dropFirst(4).dropLast(7))
                                } else {
                                    id = "New \(fullName) Window"
                                    displayName = fullName
                                }
                                
                                // Filter out static items
                                if displayName == "Tab" || displayName == "Window" || displayName == "Private Window" || displayName == "Empty Tab Group" {
                                    continue
                                }
                                
                                discoveredProfiles.append(BrowserProfile(id: id, name: displayName))
                            }
                        }
                        
                        if !discoveredProfiles.isEmpty {
                            print("Successfully discovered \(discoveredProfiles.count) Safari profiles live.")
                            saveSafariProfilesToCache(discoveredProfiles)
                        }
                    }
                }
            }
        }
        
        let finalProfiles = discoveredProfiles.isEmpty ? loadSafariProfilesFromCache() : discoveredProfiles
        if discoveredProfiles.isEmpty && !finalProfiles.isEmpty {
            print("Using \(finalProfiles.count) Safari profiles from persistent cache.")
        }
        
        fflush(stdout)
        return finalProfiles
    }

    private static func saveSafariProfilesToCache(_ profiles: [BrowserProfile]) {
        if let encoded = try? JSONEncoder().encode(profiles) {
            UserDefaults.standard.set(encoded, forKey: "CachedSafariProfiles")
        }
    }

    private static func loadSafariProfilesFromCache() -> [BrowserProfile] {
        if let data = UserDefaults.standard.data(forKey: "CachedSafariProfiles"),
           let decoded = try? JSONDecoder().decode([BrowserProfile].self, from: data) {
            return decoded
        }
        return []
    }
}

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
        
        let id = bundleId.lowercased()
        
        // 1. Firefox Handling
        if id.contains("mozilla.firefox") || id.contains("org.mozilla.firefox") {
            // Check both Firefox and Firefox/Profiles
            let firefoxDir = supportDir.appendingPathComponent("Firefox")
            return discoverFirefoxProfiles(at: firefoxDir)
        }
        
        // 2. Chromium Handling
        var searchPaths: [String] = []
        
        switch bundleId {
        case "com.google.Chrome": searchPaths.append("Google/Chrome")
        case "com.google.Chrome.canary": searchPaths.append("Google/Chrome Canary")
        case "org.chromium.Chromium": searchPaths.append("Chromium")
        case "com.microsoft.edgemac": searchPaths.append("Microsoft Edge")
        case "com.brave.Browser": searchPaths.append("BraveSoftware/Brave-Browser")
        case "company.thebrowser.Browser": searchPaths.append("Arc")
        case "com.vivaldi.Vivaldi": searchPaths.append("Vivaldi")
        case "net.imput.helium": searchPaths.append("net.imput.helium")
        default:
            // For other apps, only check if the directory matches name or bundle exactly
            searchPaths.append(bundleId)
            searchPaths.append(appName)
        }
        
        for subPath in searchPaths {
            let localStateUrl = supportDir.appendingPathComponent(subPath).appendingPathComponent("Local State")
            if fileManager.fileExists(atPath: localStateUrl.path) {
                let profiles = parseChromiumProfiles(at: localStateUrl)
                if !profiles.isEmpty {
                    return profiles
                }
            }
        }
        
        return []
    }
    
    private static func discoverFirefoxProfiles(at url: URL) -> [BrowserProfile] {
        var discoveredProfiles: [BrowserProfile] = []
        
        // 1. Detect Modern Firefox (Profile Groups)
        let profileGroupsDir = url.appendingPathComponent("Profile Groups")
        if let contents = try? FileManager.default.contentsOfDirectory(at: profileGroupsDir, includingPropertiesForKeys: nil) {
            for fileUrl in contents where fileUrl.pathExtension == "sqlite" {
                if let sqliteProfiles = parseFirefoxSqlite(at: fileUrl), !sqliteProfiles.isEmpty {
                    // If we found modern profiles, we prefer these
                    discoveredProfiles.append(contentsOf: sqliteProfiles)
                }
            }
        }
        
        // 2. If no modern profiles found, fallback to Traditional Firefox (profiles.ini)
        if discoveredProfiles.isEmpty {
            let iniUrl = url.appendingPathComponent("profiles.ini")
            if let content = try? String(contentsOf: iniUrl, encoding: .utf8) {
                let sections = parseIni(content)
                for (sectionName, keys) in sections {
                    if sectionName.lowercased().starts(with: "profile"), let name = keys["Name"] {
                        discoveredProfiles.append(BrowserProfile(id: name, name: name))
                    }
                }
            }
        }
        
        return discoveredProfiles.sorted { $0.name < $1.name }
    }
    
    private static func parseFirefoxSqlite(at url: URL) -> [BrowserProfile]? {
        // Since we can't easily link SQLite in a simple SPM script without dependencies,
        // we will use a shell command to dump the table if possible, or skip for now.
        // Actually, we can use process execution to run sqlite3 which is built into macOS.
        
        let task = Process()
        task.launchPath = "/usr/bin/sqlite3"
        task.arguments = [url.path, "SELECT path, name FROM Profiles;"]
        
        let pipe = Pipe()
        task.standardOutput = pipe
        
        do {
            try task.run()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let output = String(data: data, encoding: .utf8) {
                var profiles: [BrowserProfile] = []
                let lines = output.components(separatedBy: .newlines)
                for line in lines where !line.isEmpty {
                    let parts = line.components(separatedBy: "|")
                    if parts.count >= 2 {
                        // For Firefox, the name is what matters for the -P flag
                        let name = parts[1]
                        profiles.append(BrowserProfile(id: name, name: name))
                    }
                }
                return profiles
            }
        } catch {
            print("Error reading Firefox SQLite: \(error)")
        }
        
        return nil
    }
    
    private static func parseIni(_ content: String) -> [String: [String: String]] {
        var sections: [String: [String: String]] = [:]
        var currentSection: String?
        
        let lines = content.components(separatedBy: .newlines)
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty || trimmed.starts(with: ";") || trimmed.starts(with: "#") {
                continue
            }
            
            if trimmed.starts(with: "[") && trimmed.hasSuffix("]") {
                let sectionName = String(trimmed.dropFirst().dropLast())
                currentSection = sectionName
                sections[sectionName] = [:]
            } else if let current = currentSection, let eqIndex = trimmed.firstIndex(of: "=") {
                let key = String(trimmed[..<eqIndex]).trimmingCharacters(in: .whitespaces)
                let value = String(trimmed[trimmed.index(after: eqIndex)...]).trimmingCharacters(in: .whitespaces)
                sections[current]?[key] = value
            }
        }
        return sections
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
}

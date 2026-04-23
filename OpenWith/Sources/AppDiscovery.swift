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
        let iniUrl = url.appendingPathComponent("profiles.ini")
        guard let content = try? String(contentsOf: iniUrl, encoding: .utf8) else { return [] }
        
        var profiles: [BrowserProfile] = []
        let lines = content.components(separatedBy: .newlines)
        
        var currentProfileName: String?
        
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.starts(with: "[Profile") {
                // Starting a new profile section
                if let name = currentProfileName {
                    profiles.append(BrowserProfile(id: name, name: name))
                }
                currentProfileName = nil
            } else if trimmed.starts(with: "Name=") {
                currentProfileName = trimmed.replacingOccurrences(of: "Name=", with: "")
            }
        }
        
        // Add the last one
        if let name = currentProfileName {
            profiles.append(BrowserProfile(id: name, name: name))
        }
        
        return profiles.sorted { $0.name < $1.name }
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

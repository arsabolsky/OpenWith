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
        let fileManager = FileManager.default
        var discoveredProfiles: [String: String] = [:] // Path -> Name
        
        // 1. Try profiles.ini first (Official Source)
        let iniUrl = url.appendingPathComponent("profiles.ini")
        if let content = try? String(contentsOf: iniUrl, encoding: .utf8) {
            let sections = content.components(separatedBy: "[Profile")
            for section in sections {
                let lines = section.components(separatedBy: .newlines)
                var name: String?
                var path: String?
                for line in lines {
                    if line.starts(with: "Name=") {
                        name = line.replacingOccurrences(of: "Name=", with: "")
                    } else if line.starts(with: "Path=") {
                        path = line.replacingOccurrences(of: "Path=", with: "")
                    }
                }
                if let n = name, let p = path {
                    discoveredProfiles[p] = n
                }
            }
        }
        
        // 2. Scan Profiles folder for dangling/unlisted profiles
        let profilesDir = url.appendingPathComponent("Profiles")
        if let contents = try? fileManager.contentsOfDirectory(at: profilesDir, includingPropertiesForKeys: nil) {
            for itemUrl in contents {
                let folderName = itemUrl.lastPathComponent
                let relativePath = "Profiles/\(folderName)"
                
                // If not in INI, try to extract a name from the folder name
                // Format: [random].[name] -> e.g. eRt2OTh8.Profile 1
                if discoveredProfiles[relativePath] == nil {
                    let parts = folderName.components(separatedBy: ".")
                    if parts.count > 1 {
                        let extractedName = parts.suffix(from: 1).joined(separator: ".")
                        discoveredProfiles[relativePath] = extractedName
                    } else {
                        discoveredProfiles[relativePath] = folderName
                    }
                }
            }
        }
        
        return discoveredProfiles.map { BrowserProfile(id: $1, name: $1) }.sorted { $0.name < $1.name }
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

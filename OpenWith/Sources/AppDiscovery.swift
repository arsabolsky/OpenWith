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
        
        // Strategy: Look for directories that match the bundleId or appName
        // Also check common Chromium paths
        var searchPaths: [String] = [
            bundleId,
            appName,
            "Google/\(appName)",
            "BraveSoftware/\(appName)-Browser",
            "Microsoft Edge",
            "Chromium",
            "Vivaldi"
        ]
        
        // Special case for known bundles like Helium (net.imput.helium)
        if bundleId.contains(".") {
            searchPaths.append(bundleId)
            // Also try the last component of the bundleId
            searchPaths.append(bundleId.components(separatedBy: ".").last!)
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

import AppKit

struct ApplicationInfo: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let bundleIdentifier: String
    let path: URL
    let icon: NSImage?
}

class AppDiscovery {
    static func getInstalledBrowsers() -> [ApplicationInfo] {
        let workspace = NSWorkspace.shared
        let httpsUrl = URL(string: "https://")!
        
        // Find all apps that can open https:// URLs
        let appUrls = workspace.urlsForApplications(toOpen: httpsUrl)
        
        var apps: [ApplicationInfo] = []
        let myBundleId = Bundle.main.bundleIdentifier
        
        for path in appUrls {
            guard let bundleId = Bundle(url: path)?.bundleIdentifier else { continue }
            
            // Don't show ourselves in the list
            if bundleId == myBundleId { continue }
            
            let name = (try? path.resourceValues(forKeys: [.localizedNameKey]).localizedName) ?? path.deletingPathExtension().lastPathComponent
            let icon = workspace.icon(forFile: path.path)
            
            // Avoid duplicates (some browsers might have multiple entries)
            if !apps.contains(where: { $0.bundleIdentifier == bundleId }) {
                apps.append(ApplicationInfo(name: name, bundleIdentifier: bundleId, path: path, icon: icon))
            }
        }
        
        // Sort alphabetically
        return apps.sorted { $0.name < $1.name }
    }
}

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
        let browserIds = [
            "com.apple.Safari",
            "com.google.Chrome",
            "com.google.Chrome.canary",
            "org.mozilla.firefox",
            "com.microsoft.edgemac",
            "company.thebrowser.Browser", // Arc
            "com.operasoftware.Opera",
            "com.brave.Browser",
            "com.vivaldi.Vivaldi"
        ]
        
        var apps: [ApplicationInfo] = []
        let workspace = NSWorkspace.shared
        
        for bundleId in browserIds {
            if let path = workspace.urlForApplication(withBundleIdentifier: bundleId) {
                let name = (try? path.resourceValues(forKeys: [.localizedNameKey]).localizedName) ?? path.deletingPathExtension().lastPathComponent
                let icon = workspace.icon(forFile: path.path)
                apps.append(ApplicationInfo(name: name, bundleIdentifier: bundleId, path: path, icon: icon))
            }
        }
        
        return apps
    }
}

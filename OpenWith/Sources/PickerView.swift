import SwiftUI

struct PickerView: View {
    @ObservedObject var appDelegate: AppDelegate
    let url: URL
    var onSelect: (ApplicationInfo, BrowserProfile?) -> Void
    var onCancel: () -> Void
    
    @State private var selectedIndex = 0
    @State private var eventMonitor: Any?
    
    var visibleApps: [ApplicationInfo] {
        appDelegate.cachedBrowsers.compactMap { app -> ApplicationInfo? in
            if appDelegate.hiddenBundleIds.contains(app.bundleIdentifier) { return nil }
            var filteredApp = app
            filteredApp.profiles = app.profiles.filter { !appDelegate.hiddenProfileIds.contains($0.id) }
            return filteredApp
        }
    }
    
    var allOptions: [(app: ApplicationInfo, profile: BrowserProfile?)] {
        var options: [(app: ApplicationInfo, profile: BrowserProfile?)] = []
        for app in visibleApps {
            options.append((app, nil))
            for profile in app.profiles {
                options.append((app, profile))
            }
        }
        return options
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Open with...")
                    .font(.headline)
                    .foregroundColor(.primary)
                Spacer()
                Button(action: onCancel) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding()
            
            // List
            if allOptions.isEmpty {
                VStack {
                    ProgressView()
                        .padding()
                    Text("Searching for browsers...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxHeight: .infinity)
            } else {
                ScrollViewReader { proxy in
                    List {
                        let options = allOptions
                        ForEach(0..<options.count, id: \.self) { index in
                            let option = options[index]
                            
                            HStack {
                                // Shortcut Number
                                if index < 9 {
                                    Text("\(index + 1)")
                                        .font(.caption2)
                                        .bold()
                                        .foregroundColor(selectedIndex == index ? .white.opacity(0.8) : .secondary)
                                        .frame(width: 12)
                                } else {
                                    Spacer().frame(width: 12)
                                }
                                
                                if let profile = option.profile {
                                    Image(systemName: "person.circle")
                                        .resizable()
                                        .frame(width: 16, height: 16)
                                        .padding(.leading, 12)
                                        .foregroundColor(selectedIndex == index ? .white : .primary.opacity(0.8))
                                    Text(profile.name)
                                        .font(.subheadline)
                                        .foregroundColor(selectedIndex == index ? .white : .primary.opacity(0.9))
                                } else {
                                    if let icon = option.app.icon {
                                        Image(nsImage: icon)
                                            .resizable()
                                            .frame(width: 20, height: 20)
                                    }
                                    Text(option.app.name)
                                        .font(.body.bold())
                                        .foregroundColor(selectedIndex == index ? .white : .primary)
                                }
                                Spacer()
                            }
                            .padding(.vertical, 4)
                            .padding(.horizontal, 8)
                            .background(selectedIndex == index ? Color.accentColor : Color.clear)
                            .cornerRadius(6)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                onSelect(option.app, option.profile)
                            }
                            .id(index)
                        }
                    }
                    .listStyle(.plain)
                    .onChange(of: selectedIndex) { newIndex in
                        withAnimation {
                            proxy.scrollTo(newIndex, anchor: .center)
                        }
                    }
                }
            }
            
            Divider()
            
            // URL Display & Copy
            HStack {
                Text(url.absoluteString)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                
                Spacer()
                
                Button(action: {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(url.absoluteString, forType: .string)
                }) {
                    Image(systemName: "doc.on.doc")
                        .font(.caption)
                        .foregroundColor(.accentColor)
                }
                .buttonStyle(.plain)
                .help("Copy URL")
            }
            .padding(10)
        }
        .frame(width: 300, height: 400)
        .background(VisualEffectView(material: .hudWindow, blendingMode: .behindWindow))
        .cornerRadius(12)
        .onAppear {
            self.eventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
                let options = allOptions
                switch event.keyCode {
                case 126: // Up
                    if selectedIndex > 0 { selectedIndex -= 1 }
                    return nil
                case 125: // Down
                    if selectedIndex < options.count - 1 { selectedIndex += 1 }
                    return nil
                case 36: // Enter
                    if selectedIndex < options.count {
                        let opt = options[selectedIndex]
                        onSelect(opt.app, opt.profile)
                    }
                    return nil
                case 53: // Escape
                    onCancel()
                    return nil
                default:
                    if let chars = event.characters, let num = Int(chars), num >= 1 && num <= 9 {
                        let idx = num - 1
                        if idx >= 0 && idx < options.count {
                            let opt = options[idx]
                            onSelect(opt.app, opt.profile)
                        }
                        return nil
                    }
                }
                return event
            }
        }
        .onDisappear {
            if let monitor = self.eventMonitor {
                NSEvent.removeMonitor(monitor)
                self.eventMonitor = nil
            }
        }
    }
}

struct VisualEffectView: NSViewRepresentable {
    let material: NSVisualEffectView.Material
    let blendingMode: NSVisualEffectView.BlendingMode
    
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        return view
    }
    
    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {}
}

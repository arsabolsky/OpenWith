import SwiftUI

struct PickerView: View {
    let url: URL
    let apps: [ApplicationInfo]
    var onSelect: (ApplicationInfo, BrowserProfile?) -> Void
    var onCancel: () -> Void
    
    @State private var selectedIndex = 0
    @State private var allOptions: [(app: ApplicationInfo, profile: BrowserProfile?)] = []
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Open with...")
                    .font(.headline)
                Spacer()
                Button(action: onCancel) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding()
            
            // List
            ScrollViewReader { proxy in
                List {
                    ForEach(0..<allOptions.count, id: \.self) { index in
                        let option = allOptions[index]
                        
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
                                    .foregroundColor(selectedIndex == index ? .white : .primary)
                                Text(profile.name)
                                    .font(.subheadline)
                                    .foregroundColor(selectedIndex == index ? .white : .secondary)
                            } else {
                                if let icon = option.app.icon {
                                    Image(nsImage: icon)
                                        .resizable()
                                        .frame(width: 20, height: 20)
                                }
                                Text(option.app.name)
                                    .font(.body)
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
        .onAppear {
            setupOptions()
            
            // Add local event monitor for keyboard navigation
            NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
                switch event.keyCode {
                case 126: // Up
                    if selectedIndex > 0 { selectedIndex -= 1 }
                    return nil
                case 125: // Down
                    if selectedIndex < allOptions.count - 1 { selectedIndex += 1 }
                    return nil
                case 36: // Enter
                    if selectedIndex < allOptions.count {
                        let opt = allOptions[selectedIndex]
                        onSelect(opt.app, opt.profile)
                    }
                    return nil
                case 53: // Escape
                    onCancel()
                    return nil
                default:
                    if let chars = event.characters, let num = Int(chars), num >= 1 && num <= 9 {
                        let idx = num - 1
                        if idx >= 0 && idx < allOptions.count {
                            let opt = allOptions[idx]
                            onSelect(opt.app, opt.profile)
                        }
                        return nil
                    }
                }
                return event
            }
        }
    }
    
    private func setupOptions() {
        var options: [(app: ApplicationInfo, profile: BrowserProfile?)] = []
        for app in apps {
            options.append((app, nil))
            for profile in app.profiles {
                options.append((app, profile))
            }
        }
        self.allOptions = options
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

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
                                    .foregroundColor(.secondary)
                                    .frame(width: 12)
                            } else {
                                Spacer().frame(width: 12)
                            }
                            
                            if let profile = option.profile {
                                Image(systemName: "person.circle")
                                    .resizable()
                                    .frame(width: 16, height: 16)
                                    .padding(.leading, 12)
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
        }
        .background(KeyEventsView(
            onUp: {
                if selectedIndex > 0 { selectedIndex -= 1 }
            },
            onDown: {
                if selectedIndex < allOptions.count - 1 { selectedIndex += 1 }
            },
            onEnter: {
                if selectedIndex < allOptions.count {
                    let opt = allOptions[selectedIndex]
                    onSelect(opt.app, opt.profile)
                }
            },
            onEscape: onCancel,
            onNumber: { num in
                let idx = num - 1
                if idx >= 0 && idx < allOptions.count {
                    let opt = allOptions[idx]
                    onSelect(opt.app, opt.profile)
                }
            }
        ))
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

struct KeyEventsView: NSViewRepresentable {
    let onUp: () -> Void
    let onDown: () -> Void
    let onEnter: () -> Void
    let onEscape: () -> Void
    let onNumber: (Int) -> Void
    
    func makeNSView(context: Context) -> NSView {
        let view = KeyView()
        view.onUp = onUp
        view.onDown = onDown
        view.onEnter = onEnter
        view.onEscape = onEscape
        view.onNumber = onNumber
        return view
    }
    
    func updateNSView(_ nsView: NSView, context: Context) {}
    
    class KeyView: NSView {
        var onUp: (() -> Void)?
        var onDown: (() -> Void)?
        var onEnter: (() -> Void)?
        var onEscape: (() -> Void)?
        var onNumber: ((Int) -> Void)?
        
        override var acceptsFirstResponder: Bool { true }
        
        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            window?.makeFirstResponder(self)
        }
        
        override func keyDown(with event: NSEvent) {
            switch event.keyCode {
            case 126: // Up
                onUp?()
            case 125: // Down
                onDown?()
            case 36: // Enter
                onEnter?()
            case 53: // Escape
                onEscape?()
            default:
                if let chars = event.characters, let num = Int(chars), num >= 1 && num <= 9 {
                    onNumber?(num)
                } else {
                    super.keyDown(with: event)
                }
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

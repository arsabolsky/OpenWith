import SwiftUI

struct PickerView: View {
    let url: URL
    let apps: [ApplicationInfo]
    var onSelect: (ApplicationInfo, BrowserProfile?) -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            Text("Open with...")
                .font(.headline)
                .padding()
            
            List {
                ForEach(apps) { app in
                    Section(header: Text(app.name)) {
                        // Main application option
                        Button(action: {
                            onSelect(app, nil)
                        }) {
                            HStack {
                                if let icon = app.icon {
                                    Image(nsImage: icon)
                                        .resizable()
                                        .frame(width: 24, height: 24)
                                }
                                Text(app.name)
                                    .font(.body)
                                Spacer()
                            }
                            .padding(.vertical, 4)
                        }
                        .buttonStyle(.plain)
                        
                        // Profile options
                        ForEach(app.profiles) { profile in
                            Button(action: {
                                onSelect(app, profile)
                            }) {
                                HStack {
                                    Image(systemName: "person.circle")
                                        .resizable()
                                        .frame(width: 16, height: 16)
                                        .padding(.leading, 32)
                                    Text(profile.name)
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                    Spacer()
                                }
                                .padding(.vertical, 2)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .listStyle(.sidebar)
            
            Divider()
            
            Text(url.absoluteString)
                .font(.caption)
                .foregroundColor(.secondary)
                .lineLimit(1)
                .padding()
        }
        .frame(width: 300, height: 400)
        .background(VisualEffectView(material: .hudWindow, blendingMode: .behindWindow))
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

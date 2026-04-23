import SwiftUI

struct PickerView: View {
    let url: URL
    let apps: [ApplicationInfo]
    var onSelect: (ApplicationInfo) -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            Text("Open with...")
                .font(.headline)
                .padding()
            
            List(apps) { app in
                Button(action: {
                    onSelect(app)
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
            }
            .listStyle(.inset)
            
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

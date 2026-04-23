import SwiftUI

struct SetupView: View {
    @ObservedObject var appDelegate: AppDelegate
    @State private var currentStep = 0
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "arrow.up.right.square.fill")
                .resizable()
                .frame(width: 64, height: 64)
                .foregroundColor(.accentColor)
                .padding(.top)
            
            Text("Welcome to OpenWith")
                .font(.largeTitle)
                .bold()
            
            Text("Let's get you set up to route links exactly where you want them.")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .padding(.horizontal)
            
            VStack(alignment: .leading, spacing: 15) {
                SetupStep(
                    title: "Accessibility Permissions",
                    description: "Required for Safari profile discovery and switching.",
                    isCompleted: appDelegate.isAccessibilityTrusted,
                    action: { appDelegate.requestPermissions() }
                )
                
                SetupStep(
                    title: "Set as Default Browser",
                    description: "Allow OpenWith to intercept your web links.",
                    isCompleted: false, // We can't easily check this status, so always allow button
                    action: {
                        let bundleId = Bundle.main.bundleIdentifier! as CFString
                        LSSetDefaultHandlerForURLScheme("http" as CFString, bundleId)
                        LSSetDefaultHandlerForURLScheme("https" as CFString, bundleId)
                    }
                )
            }
            .padding()
            .background(Color(NSColor.windowBackgroundColor).opacity(0.5))
            .cornerRadius(12)
            
            Spacer()
            
            Button("Finish Setup") {
                UserDefaults.standard.set(true, forKey: "SetupCompleted")
                NSApp.keyWindow?.close()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .padding(.bottom)
        }
        .frame(width: 400, height: 450)
        .padding()
    }
}

struct SetupStep: View {
    let title: String
    let description: String
    let isCompleted: Bool
    let action: () -> Void
    
    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(title).font(.headline)
                Text(description).font(.caption).foregroundColor(.secondary)
            }
            Spacer()
            if isCompleted {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                    .font(.title2)
            } else {
                Button("Configure") {
                    action()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
    }
}

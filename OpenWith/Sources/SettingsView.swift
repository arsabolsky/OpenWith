import SwiftUI

struct SettingsView: View {
    @ObservedObject var appDelegate: AppDelegate
    
    var body: some View {
        VStack {
            GroupBox(label: Text("Permissions").font(.headline)) {
                VStack(spacing: 8) {
                    HStack {
                        Image(systemName: appDelegate.isAccessibilityTrusted ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                            .foregroundColor(appDelegate.isAccessibilityTrusted ? .green : .red)
                        Text("Accessibility: \(appDelegate.isAccessibilityTrusted ? "Trusted" : "Not Trusted")")
                        Spacer()
                    }
                    
                    HStack {
                        Image(systemName: appDelegate.isAutomationAllowed ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                            .foregroundColor(appDelegate.isAutomationAllowed ? .green : .red)
                        Text("Safari Automation: \(appDelegate.isAutomationAllowed ? "Allowed" : "Not Allowed")")
                        Spacer()
                    }

                    if !appDelegate.isAccessibilityTrusted || !appDelegate.isAutomationAllowed {
                        Button("Request Missing Access") {
                            appDelegate.requestPermissions()
                        }
                        .padding(.top, 4)
                    } else {
                        Button("Re-check Status") {
                            appDelegate.checkPermissions()
                        }
                        .padding(.top, 4)
                    }
                }
                .padding(8)
            }
            .padding()

            GroupBox(label: Text("General").font(.headline)) {
                HStack {
                    Text("Launch at Login")
                    Spacer()
                    Toggle("", isOn: Binding(
                        get: { appDelegate.isLaunchAtLoginEnabled },
                        set: { _ in appDelegate.toggleLaunchAtLogin() }
                    ))
                    .toggleStyle(.switch)
                    .labelsHidden()
                    .disabled({
                        if #available(macOS 13.0, *) { return false }
                        return true
                    }())
                }
                .padding(8)
            }
            .padding(.horizontal)

            GroupBox(label: Text("Browsers & Profiles").font(.headline)) {
                VStack(spacing: 0) {
                    List {
                        ForEach(appDelegate.cachedBrowsers) { app in
                            Section(header: Text(app.name)) {
                                HStack {
                                    if let icon = app.icon {
                                        Image(nsImage: icon)
                                            .resizable()
                                            .frame(width: 16, height: 16)
                                    }
                                    Text(app.name)
                                    Spacer()
                                    Toggle("", isOn: Binding(
                                        get: { !appDelegate.hiddenBundleIds.contains(app.bundleIdentifier) },
                                        set: { visible in
                                            if visible {
                                                appDelegate.hiddenBundleIds.remove(app.bundleIdentifier)
                                            } else {
                                                appDelegate.hiddenBundleIds.insert(app.bundleIdentifier)
                                            }
                                            appDelegate.saveHiddenItems()
                                        }
                                    ))
                                    .toggleStyle(.switch)
                                    .labelsHidden()
                                }
                                
                                ForEach(app.profiles) { profile in
                                    HStack {
                                        Image(systemName: "person.circle")
                                            .padding(.leading, 20)
                                        Text(profile.name)
                                            .font(.subheadline)
                                            .foregroundColor(.secondary)
                                        Spacer()
                                        Toggle("", isOn: Binding(
                                            get: { !appDelegate.hiddenProfileIds.contains(profile.id) },
                                            set: { visible in
                                                if visible {
                                                    appDelegate.hiddenProfileIds.remove(profile.id)
                                                } else {
                                                    appDelegate.hiddenProfileIds.insert(profile.id)
                                                }
                                                appDelegate.saveHiddenItems()
                                            }
                                        ))
                                        .toggleStyle(.switch)
                                        .labelsHidden()
                                        .scaleEffect(0.8)
                                    }
                                }
                            }
                        }
                    }
                    .listStyle(.inset)
                    
                    Divider()
                    
                    Button(action: {
                        appDelegate.refreshBrowserCache()
                    }) {
                        Label("Refresh Profiles", systemImage: "arrow.clockwise")
                    }
                    .padding(8)
                }
            }
            .padding()
            
            HStack {
                Spacer()
                Button("Done") {
                    NSApp.keyWindow?.close()
                }
            }
            .padding()
        }
        .frame(width: 500, height: 500)
    }
}

import SwiftUI

struct SettingsView: View {
    @ObservedObject var appDelegate: AppDelegate
    @State private var showingAddAppRule = false
    
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
                }
                .padding(8)
            }
            .padding(.horizontal)

            GroupBox(label: Text("Auto-Route by Source App").font(.headline)) {
                VStack(alignment: .leading) {
                    if appDelegate.appRules.isEmpty {
                        Text("No rules yet. Links from specific apps can be auto-routed.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    } else {
                        ForEach(appDelegate.appRules) { rule in
                            HStack {
                                Text(rule.sourceBundleId)
                                    .font(.caption)
                                    .bold()
                                Image(systemName: "arrow.right")
                                    .font(.caption2)
                                Text(appDelegate.cachedBrowsers.first(where: { $0.bundleIdentifier == rule.targetBrowserBundleId })?.name ?? rule.targetBrowserBundleId)
                                    .font(.caption)
                                if let profileId = rule.targetProfileId {
                                    Text("(\(profileId.components(separatedBy: ":").last ?? ""))")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                                Button(action: {
                                    appDelegate.appRules.removeAll(where: { $0.id == rule.id })
                                    appDelegate.saveAppRules()
                                }) {
                                    Image(systemName: "trash")
                                        .foregroundColor(.red)
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(.vertical, 2)
                        }
                    }
                    
                    Divider()
                    
                    Button("Add App Rule...") {
                        showingAddAppRule = true
                    }
                    .controlSize(.small)
                }
                .padding(8)
            }
            .padding(.horizontal)

            GroupBox(label: Text("Browsers & Profiles Visibility").font(.headline)) {
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
                                        .disabled(appDelegate.hiddenBundleIds.contains(app.bundleIdentifier))
                                    }
                                    .foregroundColor(appDelegate.hiddenBundleIds.contains(app.bundleIdentifier) ? .secondary.opacity(0.5) : .primary)
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
        .frame(width: 500, height: 750)
        .sheet(isPresented: $showingAddAppRule) {
            AddAppRuleView(appDelegate: appDelegate)
        }
    }
}

struct AddAppRuleView: View {
    @ObservedObject var appDelegate: AppDelegate
    @Environment(\.dismiss) var dismiss
    
    @State private var sourceBundleId = ""
    @State private var targetBrowserBundleId = ""
    @State private var targetProfileId: String? = nil
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Add Auto-Route Rule").font(.headline)
            
            Form {
                Section(header: Text("Source Application Bundle ID")) {
                    TextField("e.g. com.microsoft.teams", text: $sourceBundleId)
                    Text("Tip: Open a link from the app first to see its ID in the logs.")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                
                Section(header: Text("Target Browser")) {
                    Picker("Browser", selection: $targetBrowserBundleId) {
                        Text("Select Browser").tag("")
                        ForEach(appDelegate.cachedBrowsers) { app in
                            Text(app.name).tag(app.bundleIdentifier)
                        }
                    }
                }
                
                if let selectedApp = appDelegate.cachedBrowsers.first(where: { $0.bundleIdentifier == targetBrowserBundleId }), !selectedApp.profiles.isEmpty {
                    Section(header: Text("Target Profile (Optional)")) {
                        Picker("Profile", selection: $targetProfileId) {
                            Text("Default Profile").tag(nil as String?)
                            ForEach(selectedApp.profiles) { profile in
                                Text(profile.name).tag(profile.id as String?)
                            }
                        }
                    }
                }
            }
            
            HStack {
                Button("Cancel") {
                    dismiss()
                }
                Spacer()
                Button("Add Rule") {
                    let newRule = AppRule(sourceBundleId: sourceBundleId, targetBrowserBundleId: targetBrowserBundleId, targetProfileId: targetProfileId)
                    appDelegate.appRules.append(newRule)
                    appDelegate.saveAppRules()
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .disabled(sourceBundleId.isEmpty || targetBrowserBundleId.isEmpty)
            }
        }
        .padding()
        .frame(width: 400)
    }
}

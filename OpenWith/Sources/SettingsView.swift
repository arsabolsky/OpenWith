import SwiftUI

struct SettingsView: View {
    @Binding var rules: [Rule]
    var onSave: () -> Void
    
    @State private var showingAddRule = false
    @State private var newRuleName = ""
    @State private var newRulePattern = ""
    @State private var newRuleTarget = ""
    @State private var newRuleType: RuleType = .domain

    var body: some View {
        VStack {
            List {
                ForEach(rules) { rule in
                    HStack {
                        VStack(alignment: .leading) {
                            Text(rule.name).font(.headline)
                            Text("\(rule.type.rawValue): \(rule.pattern)").font(.subheadline).foregroundColor(.secondary)
                        }
                        Spacer()
                        Text(rule.targetAppBundleId).font(.caption)
                        Button(role: .destructive) {
                            rules.removeAll { $0.id == rule.id }
                            onSave()
                        } label: {
                            Image(systemName: "trash")
                        }
                    }
                }
            }
            
            HStack {
                Button("Add Rule") {
                    showingAddRule = true
                }
                Spacer()
                Button("Done") {
                    NSApp.keyWindow?.close()
                }
            }
            .padding()
        }
        .frame(width: 500, height: 400)
        .sheet(isPresented: $showingAddRule) {
            VStack(spacing: 20) {
                Text("Add New Rule").font(.headline)
                
                TextField("Rule Name (e.g., Zoom)", text: $newRuleName)
                
                Picker("Rule Type", selection: $newRuleType) {
                    Text("Domain").tag(RuleType.domain)
                    Text("Regex").tag(RuleType.regex)
                    Text("File Extension").tag(RuleType.fileExtension)
                }
                
                TextField("Pattern (e.g., zoom.us)", text: $newRulePattern)
                TextField("Target Bundle ID (e.g., us.zoom.xos)", text: $newRuleTarget)
                
                HStack {
                    Button("Cancel") {
                        showingAddRule = false
                    }
                    Spacer()
                    Button("Add") {
                        let rule = Rule(name: newRuleName, type: newRuleType, pattern: newRulePattern, targetAppBundleId: newRuleTarget)
                        rules.append(rule)
                        onSave()
                        showingAddRule = false
                        // Reset
                        newRuleName = ""
                        newRulePattern = ""
                        newRuleTarget = ""
                    }
                    .disabled(newRuleName.isEmpty || newRulePattern.isEmpty || newRuleTarget.isEmpty)
                }
            }
            .padding()
            .frame(width: 300)
        }
    }
}

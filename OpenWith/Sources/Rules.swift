import Foundation

enum RuleType: String, Codable {
    case domain
    case regex
    case fileExtension
}

struct Rule: Identifiable, Codable {
    var id = UUID()
    var name: String
    var type: RuleType
    var pattern: String
    var targetAppBundleId: String
    var targetProfileId: String? // Optional profile ID
}

class RulesEngine {
    static func match(url: URL, rules: [Rule]) -> Rule? {
        for rule in rules {
            switch rule.type {
            case .domain:
                if let host = url.host, host.contains(rule.pattern) {
                    return rule
                }
            case .regex:
                if let _ = url.absoluteString.range(of: rule.pattern, options: .regularExpression) {
                    return rule
                }
            case .fileExtension:
                if url.pathExtension == rule.pattern {
                    return rule
                }
            }
        }
        return nil
    }
}

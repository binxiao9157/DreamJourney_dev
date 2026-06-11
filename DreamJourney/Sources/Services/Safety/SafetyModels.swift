import Foundation

enum SafetyRiskLevel: Int, Comparable {
    case none = 0
    case low = 1
    case medium = 2
    case high = 3

    static func < (lhs: SafetyRiskLevel, rhs: SafetyRiskLevel) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

struct SafetyAssessment {
    let level: SafetyRiskLevel
    let matchedKeywords: [String]
    let userText: String
    let reason: String
    let shouldBlockRoleplay: Bool
}

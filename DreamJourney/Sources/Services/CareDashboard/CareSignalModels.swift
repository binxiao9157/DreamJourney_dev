import Foundation

struct CareSignalInputTurn: Codable, Equatable {
    let role: String
    let text: String
    let timestamp: Date
}

enum CareSignalRiskLevel: String, Codable, Equatable {
    case insufficientData
    case stable
    case watch
    case attention
}

struct CareSignalSnapshot: Codable, Equatable {
    let generatedAt: Date
    let windowStart: Date?
    let windowEnd: Date?
    let windowDayCount: Int
    let dataCoverageSummary: String
    let totalTurns: Int
    let userTurnCount: Int
    let characterCount: Int
    let uniqueTokenCount: Int
    let lexicalDiversity: Double
    let negativeEmotionMentions: Int
    let sleepMentions: Int
    let bodyDiscomfortMentions: Int
    let repetitionRatio: Double
    let riskLevel: CareSignalRiskLevel
    let summary: String
    let suggestions: [String]
    let weeklyHighlights: [String]
    let riskSignalDescriptions: [String]
}

enum CareDashboardInputPolicy {
    static func eligibleInputTurns(
        from turns: [ConversationTurn],
        viewerFamilyMemberID: String? = nil
    ) -> [CareSignalInputTurn] {
        PrivacyScopePolicy.sanitized(
            items: turns,
            surface: .careDashboard,
            familyMemberID: viewerFamilyMemberID
        )
        .filter(isCareEligibleTurn)
        .map {
            CareSignalInputTurn(role: $0.role, text: $0.text, timestamp: $0.timestamp)
        }
    }

    private static func isCareEligibleTurn(_ turn: ConversationTurn) -> Bool {
        guard turn.role.lowercased() == "user" else { return true }
        let excludedPrefixes = [
            "时空信箱写给",
            "记忆档案馆保存",
            "记忆档案馆上传旧照片"
        ]
        return !excludedPrefixes.contains { turn.text.hasPrefix($0) }
    }
}

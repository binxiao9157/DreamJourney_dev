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
}

import Foundation

struct WidgetKnowledgeSnapshot: Codable, Equatable {
    let schemaVersion: Int
    let ownerDigest: String
    let generatedAt: Date
    let events: [WidgetKnowledgeEventSummary]
}

struct WidgetKnowledgeEventSummary: Codable, Equatable {
    let idDigest: String
    let title: String
    let year: Int?
    let month: Int?
}

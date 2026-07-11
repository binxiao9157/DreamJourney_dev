import CryptoKit
import Foundation

struct KnowledgeWidgetSnapshot: Codable, Equatable {
    static let currentSchemaVersion = 2

    let schemaVersion: Int
    let ownerDigest: String
    let generatedAt: Date
    let events: [KnowledgeWidgetEventSummary]
}

struct KnowledgeWidgetEventSummary: Codable, Equatable, Identifiable {
    let idDigest: String
    let title: String
    let year: Int?
    let month: Int?

    var id: String { idDigest }
}

enum KnowledgeWidgetPrivacyPolicy {
    static let summaryAllowed = "summaryAllowed"
    static let maximumTitleLength = 80

    static func snapshot(
        graph: KBLiteGraph,
        ownerUserId: String,
        generatedAt: Date = Date()
    ) -> KnowledgeWidgetSnapshot? {
        guard let ownerDigest = ownerDigest(for: ownerUserId) else { return nil }
        let events = graph.events.compactMap { summary(for: $0, ownerUserId: ownerUserId) }
        return KnowledgeWidgetSnapshot(
            schemaVersion: KnowledgeWidgetSnapshot.currentSchemaVersion,
            ownerDigest: ownerDigest,
            generatedAt: generatedAt,
            events: events
        )
    }

    static func summary(
        for event: KBEvent,
        ownerUserId: String
    ) -> KnowledgeWidgetEventSummary? {
        let normalizedOwner = ownerUserId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedOwner.isEmpty,
              event.ownerUserId == normalizedOwner,
              event.personaScope == "personal",
              event.evidenceStatus == "confirmed",
              event.privacyMetadata?.scope == "generationAllowed",
              event.privacyMetadata?.widgetVisibility == summaryAllowed,
              let title = normalizedTitle(event.title) else {
            return nil
        }

        return KnowledgeWidgetEventSummary(
            idDigest: digest("\(normalizedOwner)|\(event.id)"),
            title: title,
            year: event.year,
            month: event.month
        )
    }

    static func ownerDigest(for userId: String) -> String? {
        let normalized = userId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else { return nil }
        return digest("dreamjourney-widget-owner-v2|\(normalized)")
    }

    private static func normalizedTitle(_ title: String) -> String? {
        let normalized = title
            .split(whereSeparator: { $0.isWhitespace })
            .joined(separator: " ")
        guard !normalized.isEmpty else { return nil }
        return String(normalized.prefix(maximumTitleLength))
    }

    private static func digest(_ value: String) -> String {
        SHA256.hash(data: Data(value.utf8)).map { String(format: "%02x", $0) }.joined()
    }
}

import Foundation

enum KBLitePrivacyScopePolicy {
    static func remoteExtractableTurns(from turns: [ConversationTurn]) -> [ConversationTurn] {
        turns.filter {
            PrivacyScopePolicy.canUse(metadata: $0.privacyMetadata, surface: .remoteExtraction)
        }
    }

    static func localExtractableTurns(from turns: [ConversationTurn]) -> [ConversationTurn] {
        turns.filter { $0.privacyMetadata.scope != .privateOnly }
    }

    static func derivedEntityMetadata(from turns: [ConversationTurn]) -> MemoryPrivacyMetadata {
        guard let scope = highestAvailableScope(in: turns) else {
            return MemoryPrivacyMetadata(scope: .localOnly)
        }
        return MemoryPrivacyMetadata(scope: scope)
    }

    private static func highestAvailableScope(in turns: [ConversationTurn]) -> MemoryPrivacyScope? {
        let scopes = turns.map { $0.privacyMetadata.scope }
        if scopes.contains(.generationAllowed) { return .generationAllowed }
        if scopes.contains(.familyCircle) { return .familyCircle }
        if scopes.contains(.localOnly) { return .localOnly }
        return nil
    }
}

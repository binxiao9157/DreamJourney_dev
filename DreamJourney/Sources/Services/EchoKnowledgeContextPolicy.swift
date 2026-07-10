import Foundation

struct EchoKnowledgeContextIdentity: Equatable {
    let userId: String
    let personaScope: String
    let digitalHumanId: String

    init(userId: String, personaScope: String, digitalHumanId: String) {
        self.userId = Self.normalizedIdentifier(userId)
        self.personaScope = personaScope.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        self.digitalHumanId = Self.normalizedIdentifier(digitalHumanId)
    }

    var isComplete: Bool {
        !userId.isEmpty && !personaScope.isEmpty && !digitalHumanId.isEmpty
    }

    private static func normalizedIdentifier(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

enum EchoKnowledgeContextPolicy {
    static func canonicalDigitalHumanId(
        personaScope: String,
        ownerId: String,
        familyMemberDigitalHumanId: String?
    ) -> String {
        let normalizedScope = personaScope.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let normalizedOwnerId = ownerId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard normalizedScope == "family" else {
            return normalizedOwnerId
        }
        let memberDigitalHumanId = familyMemberDigitalHumanId?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return memberDigitalHumanId.isEmpty ? normalizedOwnerId : memberDigitalHumanId
    }

    static func allowsLocalKBLiteFallback(for identity: EchoKnowledgeContextIdentity) -> Bool {
        identity.personaScope == "personal" || identity.personaScope == "self"
    }

    static func responseIdentityMatches(
        expected: EchoKnowledgeContextIdentity,
        responseUserId: String,
        responsePersonaScope: String?,
        responseDigitalHumanId: String?
    ) -> Bool {
        guard let responsePersonaScope, let responseDigitalHumanId else {
            return false
        }
        let response = EchoKnowledgeContextIdentity(
            userId: responseUserId,
            personaScope: responsePersonaScope,
            digitalHumanId: responseDigitalHumanId
        )
        return expected.isComplete && response.isComplete && response == expected
    }
}

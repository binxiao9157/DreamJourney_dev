import Foundation

struct KBPersonaIdentity: Equatable {
    let ownerUserId: String
    let personaScope: String
    let digitalHumanId: String

    init(ownerUserId: String, personaScope: String, digitalHumanId: String) {
        self.ownerUserId = Self.normalizedIdentifier(ownerUserId)
        self.personaScope = Self.canonicalPersonaScope(personaScope)
        self.digitalHumanId = Self.normalizedIdentifier(digitalHumanId)
    }

    init(userId: String, personaScope: String, digitalHumanId: String) {
        self.init(
            ownerUserId: userId,
            personaScope: personaScope,
            digitalHumanId: digitalHumanId
        )
    }

    var userId: String { ownerUserId }
    var isComplete: Bool {
        !ownerUserId.isEmpty && !personaScope.isEmpty && !digitalHumanId.isEmpty
    }
    var isPersonal: Bool { personaScope == "personal" }

    static func canonicalPersonaScope(_ value: String) -> String {
        let normalized = value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return normalized == "self" ? "personal" : normalized
    }

    static func normalizedIdentifier(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

enum KBPersonaIdentityResolver {
    private static let personalRelations: Set<String> = ["本人", "自己", "我"]

    static func resolve(
        viewerUserId: String?,
        ownerId: String,
        relation: String?,
        isSelfAssistant: Bool,
        familyMemberDigitalHumanId: String?
    ) -> KBPersonaIdentity {
        let normalizedOwnerId = KBPersonaIdentity.normalizedIdentifier(ownerId)
        let normalizedViewerId = KBPersonaIdentity.normalizedIdentifier(viewerUserId ?? "")
        let effectiveViewerId = normalizedViewerId.isEmpty ? normalizedOwnerId : normalizedViewerId
        let normalizedRelation = relation?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let isPersonal = isSelfAssistant
            || (!normalizedOwnerId.isEmpty && normalizedOwnerId == effectiveViewerId)
            || personalRelations.contains(normalizedRelation)
        let personaScope = isPersonal ? "personal" : "family"
        let memberDigitalHumanId = KBPersonaIdentity.normalizedIdentifier(
            familyMemberDigitalHumanId ?? ""
        )
        let digitalHumanId = personaScope == "family" && !memberDigitalHumanId.isEmpty
            ? memberDigitalHumanId
            : normalizedOwnerId

        return KBPersonaIdentity(
            ownerUserId: effectiveViewerId,
            personaScope: personaScope,
            digitalHumanId: digitalHumanId
        )
    }
}

enum KBPersonaPolicy {
    static let supportedProposalSchemaVersion = 1
    static let supportedMutationSchemaVersion = 2

    static func responseIdentityMatches(
        expected: KBPersonaIdentity,
        ownerUserId: String,
        personaScope: String?,
        digitalHumanId: String?
    ) -> Bool {
        guard let personaScope, let digitalHumanId else { return false }
        let response = KBPersonaIdentity(
            ownerUserId: ownerUserId,
            personaScope: personaScope,
            digitalHumanId: digitalHumanId
        )
        return expected.isComplete && response.isComplete && response == expected
    }

    static func allowsEntity(
        ownerUserId: String?,
        personaScope: String?,
        digitalHumanId: String?,
        for expected: KBPersonaIdentity,
        legacyOwnerUserId: String
    ) -> Bool {
        guard expected.isComplete else { return false }

        if expected.personaScope == "family" {
            guard let ownerUserId, let personaScope, let digitalHumanId else { return false }
            return responseIdentityMatches(
                expected: expected,
                ownerUserId: ownerUserId,
                personaScope: personaScope,
                digitalHumanId: digitalHumanId
            )
        }

        guard expected.isPersonal else { return false }
        let entityOwner = KBPersonaIdentity.normalizedIdentifier(
            ownerUserId ?? legacyOwnerUserId
        )
        guard entityOwner == expected.ownerUserId else { return false }

        if let personaScope,
           KBPersonaIdentity.canonicalPersonaScope(personaScope) != "personal" {
            return false
        }
        if let digitalHumanId,
           KBPersonaIdentity.normalizedIdentifier(digitalHumanId) != expected.digitalHumanId {
            return false
        }
        return true
    }

    static func isValidProposal(
        _ proposal: KBKnowledgeMutationProposal,
        for expected: KBPersonaIdentity
    ) -> Bool {
        guard proposal.proposalSchemaVersion == supportedProposalSchemaVersion,
              proposal.mutationSchemaVersion == supportedMutationSchemaVersion,
              proposal.proposalPolicy.version == supportedProposalSchemaVersion,
              proposal.tombstones.isEmpty,
              responseIdentityMatches(
                expected: expected,
                ownerUserId: proposal.ownerUserId,
                personaScope: proposal.personaScope,
                digitalHumanId: proposal.digitalHumanId
              ) else {
            return false
        }

        let itemIdentities = proposal.upserts.people.map {
            ($0.id, $0.ownerUserId, $0.personaScope, $0.digitalHumanId)
        } + proposal.upserts.places.map {
            ($0.id, $0.ownerUserId, $0.personaScope, $0.digitalHumanId)
        } + proposal.upserts.events.map {
            ($0.id, $0.ownerUserId, $0.personaScope, $0.digitalHumanId)
        } + proposal.upserts.facts.map {
            ($0.id, $0.ownerUserId, $0.personaScope, $0.digitalHumanId)
        }

        return itemIdentities.allSatisfy { id, ownerUserId, personaScope, digitalHumanId in
            !KBPersonaIdentity.normalizedIdentifier(id).isEmpty
                && responseIdentityMatches(
                    expected: expected,
                    ownerUserId: ownerUserId,
                    personaScope: personaScope,
                    digitalHumanId: digitalHumanId
                )
        }
    }

    static func allowsEvidenceStatus(
        _ evidenceStatus: String?,
        for expected: KBPersonaIdentity
    ) -> Bool {
        let normalized = evidenceStatus?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased() ?? ""
        if normalized.isEmpty {
            return expected.isPersonal
        }
        return normalized == "observed" || normalized == "confirmed"
    }
}

typealias EchoKnowledgeContextIdentity = KBPersonaIdentity

enum EchoKnowledgeContextPolicy {
    static func canonicalDigitalHumanId(
        personaScope: String,
        ownerId: String,
        familyMemberDigitalHumanId: String?
    ) -> String {
        let identity = KBPersonaIdentityResolver.resolve(
            viewerUserId: ownerId,
            ownerId: ownerId,
            relation: nil,
            isSelfAssistant: KBPersonaIdentity.canonicalPersonaScope(personaScope) == "personal",
            familyMemberDigitalHumanId: familyMemberDigitalHumanId
        )
        if KBPersonaIdentity.canonicalPersonaScope(personaScope) == "family" {
            let memberId = KBPersonaIdentity.normalizedIdentifier(familyMemberDigitalHumanId ?? "")
            return memberId.isEmpty
                ? KBPersonaIdentity.normalizedIdentifier(ownerId)
                : memberId
        }
        return identity.digitalHumanId
    }

    static func allowsLocalKBLiteFallback(for identity: EchoKnowledgeContextIdentity) -> Bool {
        identity.isPersonal
    }

    static func responseIdentityMatches(
        expected: EchoKnowledgeContextIdentity,
        responseUserId: String,
        responsePersonaScope: String?,
        responseDigitalHumanId: String?
    ) -> Bool {
        KBPersonaPolicy.responseIdentityMatches(
            expected: expected,
            ownerUserId: responseUserId,
            personaScope: responsePersonaScope,
            digitalHumanId: responseDigitalHumanId
        )
    }
}

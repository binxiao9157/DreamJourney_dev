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

struct KBPersonaAuthorizationSnapshot: Equatable {
    let identity: KBPersonaIdentity
    let userGeneration: UUID
    let personaGeneration: UUID
    let familyAuthorizationGeneration: UUID?

    var isComplete: Bool {
        identity.isComplete
            && (identity.isPersonal || familyAuthorizationGeneration != nil)
    }
}

enum KBPersonaAuthorizationSnapshotPolicy {
    static func isCurrent(
        _ snapshot: KBPersonaAuthorizationSnapshot,
        currentIdentity: KBPersonaIdentity?,
        userGeneration: UUID,
        personaGeneration: UUID,
        familyAuthorizationGeneration: UUID?
    ) -> Bool {
        guard snapshot.isComplete,
              currentIdentity == snapshot.identity,
              userGeneration == snapshot.userGeneration,
              personaGeneration == snapshot.personaGeneration else {
            return false
        }
        return snapshot.identity.isPersonal
            || familyAuthorizationGeneration == snapshot.familyAuthorizationGeneration
    }
}

struct KnowledgeAuthorizationEpochState: Equatable {
    private(set) var currentEpoch: UUID

    init(currentEpoch: UUID = UUID()) {
        self.currentEpoch = currentEpoch
    }

    @discardableResult
    mutating func rotate() -> UUID {
        currentEpoch = UUID()
        return currentEpoch
    }

    func accepts(boundEpoch: UUID?) -> Bool {
        boundEpoch == currentEpoch
    }
}

enum KBPersonaIdentityResolver {
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
        let isPersonal = isSelfAssistant
            || (!normalizedOwnerId.isEmpty && normalizedOwnerId == effectiveViewerId)
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
        legacyOwnerUserId _: String
    ) -> Bool {
        guard expected.isComplete else { return false }
        guard let ownerUserId, let personaScope, let digitalHumanId else { return false }
        return responseIdentityMatches(
            expected: expected,
            ownerUserId: ownerUserId,
            personaScope: personaScope,
            digitalHumanId: digitalHumanId
        )
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
        if normalized.isEmpty { return false }
        return normalized == "observed" || normalized == "confirmed"
    }
}

typealias EchoKnowledgeContextIdentity = KBPersonaIdentity

enum EchoV4IdentityRoute: String, Equatable {
    case ownerPrivate
    case visitorPublic
    case familyContribution
    case denied
}

struct EchoV4IdentityRouteDecision: Equatable {
    let route: EchoV4IdentityRoute
    let reason: String
    let privateContextAllowed: Bool
    let legacyFallbackAllowed: Bool
}

enum EchoV4IdentityRoutingPolicy {
    static func evaluate(
        viewerSubjectID: String,
        targetOwnerSubjectID: String?,
        isSelfAssistant: Bool,
        relationshipAccepted: Bool,
        visitorSessionOwnerSubjectID: String?,
        visitorSessionActive: Bool
    ) -> EchoV4IdentityRouteDecision {
        let viewer = KBPersonaIdentity.normalizedIdentifier(viewerSubjectID)
        let target = KBPersonaIdentity.normalizedIdentifier(targetOwnerSubjectID ?? "")
        let visitorOwner = KBPersonaIdentity.normalizedIdentifier(visitorSessionOwnerSubjectID ?? "")
        if !viewer.isEmpty, viewer == target, isSelfAssistant {
            return EchoV4IdentityRouteDecision(
                route: .ownerPrivate,
                reason: "ownerPrincipalMatched",
                privateContextAllowed: true,
                legacyFallbackAllowed: false
            )
        }
        guard !viewer.isEmpty, !target.isEmpty, relationshipAccepted else {
            return EchoV4IdentityRouteDecision(
                route: .denied,
                reason: "familyRelationshipRequired",
                privateContextAllowed: false,
                legacyFallbackAllowed: false
            )
        }
        if visitorSessionActive, visitorOwner == target {
            return EchoV4IdentityRouteDecision(
                route: .visitorPublic,
                reason: "visitorSessionMatched",
                privateContextAllowed: false,
                legacyFallbackAllowed: false
            )
        }
        return EchoV4IdentityRouteDecision(
            route: .familyContribution,
            reason: visitorSessionActive && !visitorOwner.isEmpty
                ? "visitorSessionOwnerMismatch"
                : "shareGrantRequired",
            privateContextAllowed: false,
            legacyFallbackAllowed: false
        )
    }
}

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

    static func allowsLocalKBLiteFallback(
        for identity: EchoKnowledgeContextIdentity,
        strictOwnerTruthAuthorityRequired: Bool = false
    ) -> Bool {
        identity.isPersonal && !strictOwnerTruthAuthorityRequired
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

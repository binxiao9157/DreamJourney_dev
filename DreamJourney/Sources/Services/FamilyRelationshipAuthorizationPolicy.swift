import Foundation

enum FamilyAuthorizationRefreshState: String, Codable {
    case unknown
    case refreshing
    case ready
    case failed
}

struct FamilyAuthorizationFreshness: Equatable {
    private(set) var state: FamilyAuthorizationRefreshState = .unknown
    private(set) var generation = UUID()
    private(set) var lastSuccessfulRefreshAt: Date?
    private(set) var hasVerifiedSnapshot = false

    var allowsPreviouslyVerifiedUse: Bool {
        state == .ready || (state == .refreshing && hasVerifiedSnapshot)
    }

    var allowsKnowledgeSyncSnapshot: Bool {
        state == .ready && hasVerifiedSnapshot
    }

    mutating func beginRefresh() {
        state = .refreshing
        generation = UUID()
    }

    mutating func completeSuccess(at date: Date = Date()) {
        state = .ready
        hasVerifiedSnapshot = true
        lastSuccessfulRefreshAt = date
        generation = UUID()
    }

    mutating func completeFailure() {
        state = .failed
        hasVerifiedSnapshot = false
        generation = UUID()
    }

    mutating func reset() {
        state = .unknown
        hasVerifiedSnapshot = false
        lastSuccessfulRefreshAt = nil
        generation = UUID()
    }
}

enum FamilyAuthorizationRefreshResponsePolicy {
    static func accepts(
        capturedOwnerUserId: String,
        currentOwnerUserId: String,
        capturedUserGeneration: UUID,
        currentUserGeneration: UUID,
        capturedRefreshGeneration: UUID,
        currentRefreshGeneration: UUID
    ) -> Bool {
        let capturedOwner = capturedOwnerUserId.trimmingCharacters(in: .whitespacesAndNewlines)
        let currentOwner = currentOwnerUserId.trimmingCharacters(in: .whitespacesAndNewlines)
        return !capturedOwner.isEmpty
            && capturedOwner == currentOwner
            && capturedUserGeneration == currentUserGeneration
            && capturedRefreshGeneration == currentRefreshGeneration
    }
}

enum FamilyRelationshipAuthoritySource: String, Codable {
    case backendInvitation
    case knowledgeCandidate
    case localInvitationAttempt
    case qaFixture
    case legacyUnverified
}

struct FamilyRelationshipAuthorizationContext: Equatable {
    let currentOwnerUserId: String
    let allowQAFixtures: Bool

    init(currentOwnerUserId: String, allowQAFixtures: Bool = false) {
        self.currentOwnerUserId = Self.normalized(currentOwnerUserId)
        self.allowQAFixtures = allowQAFixtures
    }

    private static func normalized(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

enum FamilyRelationshipAuthorizationPolicy {
    static var currentBuildAllowsQAFixtures: Bool {
        #if UI_QA_SIMULATOR && targetEnvironment(simulator)
        return true
        #else
        return false
        #endif
    }

    static func isAuthorized(
        relationshipOwnerUserId: String,
        authoritySource: FamilyRelationshipAuthoritySource,
        accessStatus: String,
        invitationStatus: String,
        context: FamilyRelationshipAuthorizationContext
    ) -> Bool {
        let ownerUserId = normalized(relationshipOwnerUserId)
        guard !ownerUserId.isEmpty,
              ownerUserId == context.currentOwnerUserId,
              normalized(accessStatus).lowercased() == "active",
              normalized(invitationStatus).lowercased() == "accepted" else {
            return false
        }

        switch authoritySource {
        case .backendInvitation:
            return true
        case .qaFixture:
            return context.allowQAFixtures
        case .knowledgeCandidate, .localInvitationAttempt, .legacyUnverified:
            return false
        }
    }

    private static func normalized(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

enum FamilyContextReconciliationPolicy {
    static func shouldFallbackToSelf(
        viewerUserId: String,
        contextOwnerId: String,
        isSelfAssistant: Bool,
        hasAuthorizedFamilyMember: Bool
    ) -> Bool {
        let viewer = normalized(viewerUserId)
        let owner = normalized(contextOwnerId)
        guard !viewer.isEmpty, !owner.isEmpty else { return false }
        guard !isSelfAssistant, owner != viewer else { return false }
        return !hasAuthorizedFamilyMember
    }

    private static func normalized(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

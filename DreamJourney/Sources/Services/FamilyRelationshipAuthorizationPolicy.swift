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

enum FamilyRelationshipStatus: String, Codable, Equatable {
    case pending
    case accepted
    case paused
    case revoked
    case unknown

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = try container.decode(String.self)
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        self = Self(rawValue: rawValue) ?? .unknown
    }
}

enum FamilyAccessGrantStatus: String, Codable, Equatable {
    case active
    case revoked
    case expired
    case unknown

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = try container.decode(String.self)
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        self = Self(rawValue: rawValue) ?? .unknown
    }
}

struct FamilyAccessGrant: Codable, Equatable, Identifiable {
    let id: String
    let relationshipId: String
    let grantorSubjectId: String
    let granteeSubjectId: String
    let purpose: String
    let resourceType: String
    let resourceId: String?
    let operations: [String]
    let status: FamilyAccessGrantStatus
    let expiresAt: Date?
    let revokedAt: Date?
    let rowVersion: Int

    init(
        id: String,
        relationshipId: String,
        grantorSubjectId: String,
        granteeSubjectId: String,
        purpose: String,
        resourceType: String,
        resourceId: String? = nil,
        operations: [String],
        status: FamilyAccessGrantStatus,
        expiresAt: Date? = nil,
        revokedAt: Date? = nil,
        rowVersion: Int
    ) {
        self.id = id
        self.relationshipId = relationshipId
        self.grantorSubjectId = grantorSubjectId
        self.granteeSubjectId = granteeSubjectId
        self.purpose = purpose
        self.resourceType = resourceType
        self.resourceId = resourceId
        self.operations = operations
        self.status = status
        self.expiresAt = expiresAt
        self.revokedAt = revokedAt
        self.rowVersion = rowVersion
    }

    func isValid(
        at now: Date = Date(),
        purpose expectedPurpose: String,
        operation expectedOperation: String,
        resourceType expectedResourceType: String,
        resourceId expectedResourceId: String? = nil
    ) -> Bool {
        guard status == .active,
              revokedAt == nil,
              expiresAt.map({ now < $0 }) ?? true,
              rowVersion > 0,
              !normalizedIdentifier(id).isEmpty,
              !normalizedIdentifier(relationshipId).isEmpty,
              !normalizedIdentifier(grantorSubjectId).isEmpty,
              !normalizedIdentifier(granteeSubjectId).isEmpty,
              normalizedToken(purpose) == normalizedToken(expectedPurpose),
              normalizedToken(resourceType) == normalizedToken(expectedResourceType),
              operations.contains(where: { normalizedToken($0) == normalizedToken(expectedOperation) }) else {
            return false
        }

        let actualResourceId = resourceId.map(normalizedIdentifier).flatMap { $0.isEmpty ? nil : $0 }
        let requestedResourceId = expectedResourceId.map(normalizedIdentifier).flatMap { $0.isEmpty ? nil : $0 }
        return actualResourceId == requestedResourceId
    }

    static func fromBackendJSON(_ object: [String: Any]) -> FamilyAccessGrant? {
        guard let id = stringValue(in: object, for: "id"),
              let relationshipId = stringValue(in: object, for: "relationshipId"),
              let grantorSubjectId = stringValue(in: object, for: "grantorSubjectId"),
              let granteeSubjectId = stringValue(in: object, for: "granteeSubjectId"),
              let purpose = stringValue(in: object, for: "purpose"),
              let resourceType = stringValue(in: object, for: "resourceType"),
              let operations = object["operations"] as? [String],
              let rawStatus = stringValue(in: object, for: "status"),
              let rowVersion = intValue(in: object, for: "rowVersion") else {
            return nil
        }

        let expiresAt: Date?
        if let rawExpiresAt = stringValue(in: object, for: "expiresAt") {
            guard let parsed = parseISO8601(rawExpiresAt) else { return nil }
            expiresAt = parsed
        } else {
            expiresAt = nil
        }

        let revokedAt: Date?
        if let rawRevokedAt = stringValue(in: object, for: "revokedAt") {
            guard let parsed = parseISO8601(rawRevokedAt) else { return nil }
            revokedAt = parsed
        } else {
            revokedAt = nil
        }

        return FamilyAccessGrant(
            id: id,
            relationshipId: relationshipId,
            grantorSubjectId: grantorSubjectId,
            granteeSubjectId: granteeSubjectId,
            purpose: purpose,
            resourceType: resourceType,
            resourceId: stringValue(in: object, for: "resourceId"),
            operations: operations,
            status: FamilyAccessGrantStatus(rawValue: normalizedToken(rawStatus)) ?? .unknown,
            expiresAt: expiresAt,
            revokedAt: revokedAt,
            rowVersion: rowVersion
        )
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case relationshipId
        case grantorSubjectId
        case granteeSubjectId
        case purpose
        case resourceType
        case resourceId
        case operations
        case status
        case expiresAt
        case revokedAt
        case rowVersion
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        relationshipId = try container.decode(String.self, forKey: .relationshipId)
        grantorSubjectId = try container.decode(String.self, forKey: .grantorSubjectId)
        granteeSubjectId = try container.decode(String.self, forKey: .granteeSubjectId)
        purpose = try container.decode(String.self, forKey: .purpose)
        resourceType = try container.decode(String.self, forKey: .resourceType)
        resourceId = try container.decodeIfPresent(String.self, forKey: .resourceId)
        operations = try container.decode([String].self, forKey: .operations)
        status = try container.decode(FamilyAccessGrantStatus.self, forKey: .status)
        expiresAt = try Self.decodeISO8601DateIfPresent(from: container, forKey: .expiresAt)
        revokedAt = try Self.decodeISO8601DateIfPresent(from: container, forKey: .revokedAt)
        rowVersion = try container.decode(Int.self, forKey: .rowVersion)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(relationshipId, forKey: .relationshipId)
        try container.encode(grantorSubjectId, forKey: .grantorSubjectId)
        try container.encode(granteeSubjectId, forKey: .granteeSubjectId)
        try container.encode(purpose, forKey: .purpose)
        try container.encode(resourceType, forKey: .resourceType)
        try container.encodeIfPresent(resourceId, forKey: .resourceId)
        try container.encode(operations, forKey: .operations)
        try container.encode(status, forKey: .status)
        try container.encodeIfPresent(expiresAt.map(Self.iso8601String), forKey: .expiresAt)
        try container.encodeIfPresent(revokedAt.map(Self.iso8601String), forKey: .revokedAt)
        try container.encode(rowVersion, forKey: .rowVersion)
    }

    private static func decodeISO8601DateIfPresent(
        from container: KeyedDecodingContainer<CodingKeys>,
        forKey key: CodingKeys
    ) throws -> Date? {
        guard let rawValue = try container.decodeIfPresent(String.self, forKey: key) else {
            return nil
        }
        guard let date = parseISO8601(rawValue) else {
            throw DecodingError.dataCorruptedError(
                forKey: key,
                in: container,
                debugDescription: "Expected an ISO8601 timestamp"
            )
        }
        return date
    }

    private static func parseISO8601(_ rawValue: String) -> Date? {
        let fractional = ISO8601DateFormatter()
        fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = fractional.date(from: rawValue) {
            return date
        }
        let standard = ISO8601DateFormatter()
        standard.formatOptions = [.withInternetDateTime]
        return standard.date(from: rawValue)
    }

    private static func iso8601String(_ date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.string(from: date)
    }

    private static func stringValue(in object: [String: Any], for key: String) -> String? {
        guard let rawValue = object[key] else { return nil }
        if let value = rawValue as? String {
            let trimmed = normalizedIdentifier(value)
            return trimmed.isEmpty ? nil : trimmed
        }
        if let value = rawValue as? NSNumber {
            return value.stringValue
        }
        return nil
    }

    private static func intValue(in object: [String: Any], for key: String) -> Int? {
        guard let rawValue = object[key] else { return nil }
        if let value = rawValue as? Int {
            return value
        }
        if let value = rawValue as? NSNumber {
            return value.intValue
        }
        if let value = rawValue as? String {
            return Int(value)
        }
        return nil
    }

    private static func normalizedToken(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private static func normalizedIdentifier(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func normalizedToken(_ value: String) -> String {
        Self.normalizedToken(value)
    }

    private func normalizedIdentifier(_ value: String) -> String {
        Self.normalizedIdentifier(value)
    }
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

    static func isAcceptedRelationship(
        relationshipId: String,
        relationshipOwnerUserId: String,
        relationshipStatus: FamilyRelationshipStatus,
        authoritySource: FamilyRelationshipAuthoritySource,
        accessStatus: String,
        invitationStatus: String,
        context: FamilyRelationshipAuthorizationContext
    ) -> Bool {
        let ownerUserId = normalized(relationshipOwnerUserId)
        guard !ownerUserId.isEmpty, ownerUserId == context.currentOwnerUserId else {
            return false
        }

        switch authoritySource {
        case .backendInvitation:
            return !normalized(relationshipId).isEmpty && relationshipStatus == .accepted
        case .qaFixture:
            guard context.allowQAFixtures else { return false }
            return relationshipStatus == .accepted
                || (
                    normalized(accessStatus).lowercased() == "active"
                        && normalized(invitationStatus).lowercased() == "accepted"
                )
        case .knowledgeCandidate, .localInvitationAttempt, .legacyUnverified:
            return false
        }
    }

    static func hasFamilyPersonaReadAccess(
        familyMemberId: String,
        memberSubjectId: String,
        relationshipId: String,
        relationshipOwnerUserId: String,
        relationshipStatus: FamilyRelationshipStatus,
        authoritySource: FamilyRelationshipAuthoritySource,
        accessStatus: String,
        invitationStatus: String,
        accessGrants: [FamilyAccessGrant],
        context: FamilyRelationshipAuthorizationContext,
        now: Date = Date()
    ) -> Bool {
        guard isAcceptedRelationship(
            relationshipId: relationshipId,
            relationshipOwnerUserId: relationshipOwnerUserId,
            relationshipStatus: relationshipStatus,
            authoritySource: authoritySource,
            accessStatus: accessStatus,
            invitationStatus: invitationStatus,
            context: context
        ) else {
            return false
        }

        if authoritySource == .qaFixture && context.allowQAFixtures && accessGrants.isEmpty {
            return true
        }

        guard authoritySource == .backendInvitation else { return false }
        let normalizedRelationshipId = normalized(relationshipId)
        let normalizedOwnerUserId = normalized(relationshipOwnerUserId)
        let normalizedMemberSubjectId = normalized(memberSubjectId)
        guard !normalizedMemberSubjectId.isEmpty else { return false }
        return accessGrants.contains { grant in
            normalized(grant.relationshipId) == normalizedRelationshipId
                && normalized(grant.grantorSubjectId) == normalizedOwnerUserId
                && normalized(grant.granteeSubjectId) == normalizedMemberSubjectId
                && grant.isValid(
                    at: now,
                    purpose: "family.persona",
                    operation: "read",
                    resourceType: "familyMember",
                    resourceId: familyMemberId
                )
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

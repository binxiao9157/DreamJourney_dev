import Foundation

public enum MemoryPrivacyScope: String, Codable, CaseIterable, Hashable {
    case privateOnly
    case localOnly
    case familyCircle
    case generationAllowed
}

public enum MemoryUseSurface: String, Codable, CaseIterable, Hashable {
    case remoteExtraction
    case prompt
    case memoirGeneration
    case timeMailboxEcho
    case export
    case widget
    case careDashboard
    case familySync
    case backendSync
}

public enum MemorySourceKind: String, Codable, CaseIterable, Hashable {
    case conversationTurn
    case memoryArchiveItem
    case timeMailboxLetter
    case kbLiteEntity
    case memoir
    case importRecord
    case userAuthorization
    case unknown
}

public struct MemorySourceRef: Codable, Equatable, Hashable {
    public let kind: MemorySourceKind
    public let id: String
    public let title: String?
    public let capturedAt: Date?

    public init(
        kind: MemorySourceKind,
        id: String,
        title: String? = nil,
        capturedAt: Date? = nil
    ) {
        self.kind = kind
        self.id = id
        self.title = title
        self.capturedAt = capturedAt
    }
}

public struct FamilyMemberVisibility: Codable, Equatable, Hashable {
    public let allowedMemberIDs: [String]

    public static let allMembers = FamilyMemberVisibility(allowedMemberIDs: [])

    public static func selectedMembers(_ memberIDs: [String]) -> FamilyMemberVisibility {
        FamilyMemberVisibility(allowedMemberIDs: memberIDs)
    }

    public init(allowedMemberIDs: [String] = []) {
        var seen: Set<String> = []
        self.allowedMemberIDs = allowedMemberIDs.compactMap { rawID in
            let id = rawID.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !id.isEmpty, !seen.contains(id) else {
                return nil
            }
            seen.insert(id)
            return id
        }
    }

    public func allows(memberID: String?) -> Bool {
        guard !allowedMemberIDs.isEmpty else {
            return true
        }
        guard let memberID else {
            return false
        }
        return allowedMemberIDs.contains(memberID)
    }
}

public struct MemoryPrivacyMetadata: Codable, Equatable, Hashable {
    public let scope: MemoryPrivacyScope
    public let sourceRefs: [MemorySourceRef]
    public let createdBySurface: MemoryUseSurface?
    public let createdAt: Date?
    public let familyVisibility: FamilyMemberVisibility

    public init(
        scope: MemoryPrivacyScope,
        sourceRefs: [MemorySourceRef] = [],
        createdBySurface: MemoryUseSurface? = nil,
        createdAt: Date? = nil,
        familyVisibility: FamilyMemberVisibility = .allMembers
    ) {
        self.scope = scope
        self.sourceRefs = sourceRefs
        self.createdBySurface = createdBySurface
        self.createdAt = createdAt
        self.familyVisibility = familyVisibility
    }

    private enum CodingKeys: String, CodingKey {
        case scope
        case sourceRefs
        case createdBySurface
        case createdAt
        case familyVisibility
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        scope = try container.decode(MemoryPrivacyScope.self, forKey: .scope)
        sourceRefs = try container.decodeIfPresent([MemorySourceRef].self, forKey: .sourceRefs) ?? []
        createdBySurface = try container.decodeIfPresent(MemoryUseSurface.self, forKey: .createdBySurface)
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt)
        familyVisibility = try container.decodeIfPresent(FamilyMemberVisibility.self, forKey: .familyVisibility)
            ?? .allMembers
    }
}

public protocol MemoryPrivacyScoped {
    var privacyMetadata: MemoryPrivacyMetadata { get }
}

public enum PrivacyScopePolicy {
    public static func canUse(scope: MemoryPrivacyScope, surface: MemoryUseSurface) -> Bool {
        switch scope {
        case .privateOnly:
            return false
        case .localOnly:
            switch surface {
            case .timeMailboxEcho:
                return true
            case .remoteExtraction,
                 .prompt,
                 .memoirGeneration,
                 .export,
                 .widget,
                 .careDashboard,
                 .familySync,
                 .backendSync:
                return false
            }
        case .generationAllowed:
            switch surface {
            case .remoteExtraction, .prompt, .memoirGeneration:
                return true
            case .timeMailboxEcho,
                 .export,
                 .widget,
                 .careDashboard,
                 .familySync,
                 .backendSync:
                return false
            }
        case .familyCircle:
            switch surface {
            case .careDashboard, .familySync:
                return true
            case .remoteExtraction,
                 .prompt,
                 .memoirGeneration,
                 .timeMailboxEcho,
                 .export,
                 .widget,
                 .backendSync:
                return false
            }
        }
    }

    public static func canUse(
        metadata: MemoryPrivacyMetadata,
        surface: MemoryUseSurface,
        familyMemberID: String? = nil
    ) -> Bool {
        guard canUse(scope: metadata.scope, surface: surface) else {
            return false
        }
        guard metadata.scope == .familyCircle,
              surface == .careDashboard || surface == .familySync
        else {
            return true
        }
        return metadata.familyVisibility.allows(memberID: familyMemberID)
    }

    public static func canUse(scopeRawValue: String, surfaceRawValue: String) -> Bool {
        guard
            let scope = MemoryPrivacyScope(rawValue: scopeRawValue),
            let surface = MemoryUseSurface(rawValue: surfaceRawValue)
        else {
            return false
        }

        return canUse(scope: scope, surface: surface)
    }

    public static func sanitized<Item: MemoryPrivacyScoped>(
        items: [Item],
        surface: MemoryUseSurface,
        familyMemberID: String? = nil
    ) -> [Item] {
        items.filter { canUse(metadata: $0.privacyMetadata, surface: surface, familyMemberID: familyMemberID) }
    }
}

public enum MemoryPrivacyMigration {
    public static func scopeFromLegacy(isPrivate: Bool) -> MemoryPrivacyScope {
        isPrivate ? .privateOnly : .localOnly
    }

    public static func scopeFromLegacy(isPrivate: Bool?) -> MemoryPrivacyScope {
        guard let isPrivate else {
            return .localOnly
        }

        return scopeFromLegacy(isPrivate: isPrivate)
    }

    public static func defaultConversationScope() -> MemoryPrivacyScope {
        .localOnly
    }

    public static func scopeForExplicitGenerationAuthorization() -> MemoryPrivacyScope {
        .generationAllowed
    }

    public static func scopeForExplicitFamilyAuthorization() -> MemoryPrivacyScope {
        .familyCircle
    }
}

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

public struct MemoryPrivacyMetadata: Codable, Equatable, Hashable {
    public let scope: MemoryPrivacyScope
    public let sourceRefs: [MemorySourceRef]
    public let createdBySurface: MemoryUseSurface?
    public let createdAt: Date?

    public init(
        scope: MemoryPrivacyScope,
        sourceRefs: [MemorySourceRef] = [],
        createdBySurface: MemoryUseSurface? = nil,
        createdAt: Date? = nil
    ) {
        self.scope = scope
        self.sourceRefs = sourceRefs
        self.createdBySurface = createdBySurface
        self.createdAt = createdAt
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

    public static func canUse(metadata: MemoryPrivacyMetadata, surface: MemoryUseSurface) -> Bool {
        canUse(scope: metadata.scope, surface: surface)
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
        surface: MemoryUseSurface
    ) -> [Item] {
        items.filter { canUse(metadata: $0.privacyMetadata, surface: surface) }
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

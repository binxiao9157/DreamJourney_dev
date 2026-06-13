import Foundation

enum HomeDialogPrivacyMetadataFactory {
    static func make(
        scope: MemoryPrivacyScope,
        familyVisibility: FamilyMemberVisibility = .allMembers,
        createdAt: Date = Date()
    ) -> MemoryPrivacyMetadata {
        MemoryPrivacyMetadata(
            scope: scope,
            sourceRefs: [
                MemorySourceRef(
                    kind: .userAuthorization,
                    id: "home-dialog-\(scope.rawValue)",
                    title: title(for: scope),
                    capturedAt: createdAt
                )
            ],
            createdAt: createdAt,
            familyVisibility: scope == .familyCircle ? familyVisibility : .allMembers
        )
    }

    static func title(for scope: MemoryPrivacyScope) -> String {
        switch scope {
        case .privateOnly:
            return "私密"
        case .localOnly:
            return "本机"
        case .generationAllowed:
            return "可生成"
        case .familyCircle:
            return "亲友"
        }
    }

    static func iconName(for scope: MemoryPrivacyScope) -> String {
        switch scope {
        case .privateOnly, .localOnly:
            return "lock.shield"
        case .generationAllowed:
            return "wand.and.stars"
        case .familyCircle:
            return "person.2"
        }
    }

    static func buttonTitle(for metadata: MemoryPrivacyMetadata, familySummary: String) -> String {
        guard metadata.scope == .familyCircle else {
            return title(for: metadata.scope)
        }
        return "亲友·\(familySummary)"
    }
}

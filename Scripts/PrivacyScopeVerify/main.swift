import Foundation

private func assertCondition(_ condition: @autoclosure () -> Bool, _ message: String) {
    guard condition() else {
        fputs("FAIL: \(message)\n", stderr)
        exit(1)
    }
}

private struct VerifyItem: MemoryPrivacyScoped {
    let id: String
    let text: String
    let privacyMetadata: MemoryPrivacyMetadata
}

private let allSurfaces = Set(MemoryUseSurface.allCases)
private let generationSurfaces: Set<MemoryUseSurface> = [
    .remoteExtraction,
    .prompt,
    .memoirGeneration
]
private let familySurfaces: Set<MemoryUseSurface> = [
    .careDashboard,
    .familySync
]
private let outwardLocalDenied: Set<MemoryUseSurface> = [
    .remoteExtraction,
    .prompt,
    .memoirGeneration,
    .export,
    .widget,
    .careDashboard,
    .familySync,
    .backendSync
]

assertCondition(
    Set(MemoryPrivacyScope.allCases) == [.privateOnly, .localOnly, .familyCircle, .generationAllowed],
    "MemoryPrivacyScope should expose the minimum accepted cases"
)

assertCondition(
    allSurfaces == [
        .remoteExtraction,
        .prompt,
        .memoirGeneration,
        .timeMailboxEcho,
        .export,
        .widget,
        .careDashboard,
        .familySync,
        .backendSync
    ],
    "MemoryUseSurface should expose the accepted listed surfaces"
)

for surface in MemoryUseSurface.allCases {
    assertCondition(
        !PrivacyScopePolicy.canUse(scope: .privateOnly, surface: surface),
        "privateOnly should deny \(surface.rawValue)"
    )
}

for surface in outwardLocalDenied {
    assertCondition(
        !PrivacyScopePolicy.canUse(scope: .localOnly, surface: surface),
        "localOnly should deny outward surface \(surface.rawValue)"
    )
}

for surface in MemoryUseSurface.allCases {
    assertCondition(
        PrivacyScopePolicy.canUse(scope: .generationAllowed, surface: surface) == generationSurfaces.contains(surface),
        "generationAllowed should only allow generation chain surface \(surface.rawValue)"
    )
}

for surface in MemoryUseSurface.allCases {
    assertCondition(
        PrivacyScopePolicy.canUse(scope: .familyCircle, surface: surface) == familySurfaces.contains(surface),
        "familyCircle should only allow family aggregation surface \(surface.rawValue)"
    )
}

let privateMetadata = MemoryPrivacyMetadata(scope: .privateOnly)
let localMetadata = MemoryPrivacyMetadata(scope: .localOnly)
let generationMetadata = MemoryPrivacyMetadata(
    scope: .generationAllowed,
    sourceRefs: [MemorySourceRef(kind: .conversationTurn, id: "turn-1")],
    createdBySurface: .prompt
)
let familyMetadata = MemoryPrivacyMetadata(
    scope: .familyCircle,
    sourceRefs: [MemorySourceRef(kind: .memoryArchiveItem, id: "archive-1")]
)

assertCondition(
    !PrivacyScopePolicy.canUse(metadata: privateMetadata, surface: .prompt),
    "metadata helper should deny private prompt use"
)
assertCondition(
    PrivacyScopePolicy.canUse(metadata: generationMetadata, surface: .memoirGeneration),
    "metadata helper should allow generation metadata for memoir generation"
)

private let items = [
    VerifyItem(id: "private", text: "secret sentinel", privacyMetadata: privateMetadata),
    VerifyItem(id: "local", text: "local sentinel", privacyMetadata: localMetadata),
    VerifyItem(id: "generation", text: "generation sentinel", privacyMetadata: generationMetadata),
    VerifyItem(id: "family", text: "family sentinel", privacyMetadata: familyMetadata)
]

private let promptItems = PrivacyScopePolicy.sanitized(items: items, surface: .prompt)
assertCondition(
    promptItems.map(\.id) == ["generation"],
    "sanitized prompt items should only contain generationAllowed entries"
)

private let familyItems = PrivacyScopePolicy.sanitized(items: items, surface: .familySync)
assertCondition(
    familyItems.map(\.id) == ["family"],
    "sanitized family sync items should only contain familyCircle entries"
)

assertCondition(
    MemoryPrivacyMigration.scopeFromLegacy(isPrivate: true) == .privateOnly,
    "legacy private data should migrate to privateOnly"
)
assertCondition(
    MemoryPrivacyMigration.scopeFromLegacy(isPrivate: false) == .localOnly,
    "legacy non-private data should migrate to localOnly"
)
assertCondition(
    MemoryPrivacyMigration.defaultConversationScope() == .localOnly,
    "ordinary conversation turns should default to localOnly"
)
assertCondition(
    MemoryPrivacyMigration.scopeForExplicitGenerationAuthorization() == .generationAllowed,
    "explicit generation authorization should use generationAllowed"
)
assertCondition(
    MemoryPrivacyMigration.scopeForExplicitFamilyAuthorization() == .familyCircle,
    "explicit family authorization should use familyCircle"
)

print("PrivacyScope verification passed")

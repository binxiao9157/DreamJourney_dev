import Foundation

struct ConversationTurn {
    let privacyMetadata: MemoryPrivacyMetadata
}

private struct VerificationSharePackage: Codable {
    let sourceUserId: String
    let sourceNickname: String
    let exportDate: Date
    let graphJSON: String
}

private func assertCondition(_ condition: @autoclosure () -> Bool, _ message: String) {
    guard condition() else {
        fputs("FAIL: \(message)\n", stderr)
        exit(1)
    }
}

private func graphJSON(_ graph: KBLiteGraph) -> String {
    let encoder = JSONEncoder()
    encoder.dateEncodingStrategy = .iso8601
    encoder.outputFormatting = [.sortedKeys]
    guard let data = try? encoder.encode(graph),
          let json = String(data: data, encoding: .utf8) else {
        fputs("FAIL: graph should encode to JSON\n", stderr)
        exit(1)
    }
    return json
}

private func packageJSON(_ graph: KBLiteGraph, familyMemberID: String? = nil) -> String {
    let sanitized = KBLitePrivacyScopePolicy.sanitizedGraph(
        graph,
        for: .familySync,
        familyMemberID: familyMemberID
    )
    let package = VerificationSharePackage(
        sourceUserId: "roadshow-user",
        sourceNickname: "陈岚",
        exportDate: Date(timeIntervalSince1970: 0),
        graphJSON: graphJSON(sanitized)
    )
    let encoder = JSONEncoder()
    encoder.dateEncodingStrategy = .iso8601
    encoder.outputFormatting = [.sortedKeys]
    guard let data = try? encoder.encode(package),
          let json = String(data: data, encoding: .utf8) else {
        fputs("FAIL: share package should encode to JSON\n", stderr)
        exit(1)
    }
    return json
}

private let familyAll = MemoryPrivacyMetadata(scope: .familyCircle)
private let daughterOnly = MemoryPrivacyMetadata(
    scope: .familyCircle,
    familyVisibility: .selectedMembers(["fm_daughter"])
)
private let sonOnly = MemoryPrivacyMetadata(
    scope: .familyCircle,
    familyVisibility: .selectedMembers(["fm_son"])
)

private let sourceGraph = KBLiteGraph(
    version: 2,
    lastUpdated: Date(timeIntervalSince1970: 0),
    sessionCount: 6,
    people: [
        KBPerson(
            id: "private-person",
            name: "PRIVATE_PERSON_SENTINEL",
            aliases: [],
            relation: nil,
            traits: ["PRIVATE_TRAIT_SENTINEL"],
            sourceSessionIds: [1],
            createdAt: Date(timeIntervalSince1970: 0),
            updatedAt: Date(timeIntervalSince1970: 0),
            privacyMetadata: MemoryPrivacyMetadata(scope: .privateOnly)
        ),
        KBPerson(
            id: "local-person",
            name: "LOCAL_PERSON_SENTINEL",
            aliases: [],
            relation: nil,
            traits: ["LOCAL_TRAIT_SENTINEL"],
            sourceSessionIds: [2],
            createdAt: Date(timeIntervalSince1970: 0),
            updatedAt: Date(timeIntervalSince1970: 0),
            privacyMetadata: MemoryPrivacyMetadata(scope: .localOnly)
        ),
        KBPerson(
            id: "generation-person",
            name: "GENERATION_PERSON_SENTINEL",
            aliases: [],
            relation: nil,
            traits: ["GENERATION_TRAIT_SENTINEL"],
            sourceSessionIds: [3],
            createdAt: Date(timeIntervalSince1970: 0),
            updatedAt: Date(timeIntervalSince1970: 0),
            privacyMetadata: MemoryPrivacyMetadata(scope: .generationAllowed)
        ),
        KBPerson(
            id: "family-person",
            name: "FAMILY_PERSON_SENTINEL",
            aliases: [],
            relation: nil,
            traits: ["FAMILY_TRAIT_SENTINEL"],
            relatedPersonIds: [
                "private-person",
                "local-person",
                "generation-person",
                "daughter-person",
                "son-person"
            ],
            sourceSessionIds: [4],
            createdAt: Date(timeIntervalSince1970: 0),
            updatedAt: Date(timeIntervalSince1970: 0),
            privacyMetadata: familyAll
        ),
        KBPerson(
            id: "daughter-person",
            name: "DAUGHTER_PERSON_SENTINEL",
            aliases: [],
            relation: nil,
            traits: ["DAUGHTER_TRAIT_SENTINEL"],
            relatedPersonIds: ["family-person", "son-person"],
            sourceSessionIds: [5],
            createdAt: Date(timeIntervalSince1970: 0),
            updatedAt: Date(timeIntervalSince1970: 0),
            privacyMetadata: daughterOnly
        ),
        KBPerson(
            id: "son-person",
            name: "SON_PERSON_SENTINEL",
            aliases: [],
            relation: nil,
            traits: ["SON_TRAIT_SENTINEL"],
            relatedPersonIds: ["family-person", "daughter-person"],
            sourceSessionIds: [6],
            createdAt: Date(timeIntervalSince1970: 0),
            updatedAt: Date(timeIntervalSince1970: 0),
            privacyMetadata: sonOnly
        )
    ],
    places: [
        KBPlace(
            id: "family-place",
            name: "FAMILY_PLACE_SENTINEL",
            description: "FAMILY_PLACE_DESCRIPTION_SENTINEL",
            relatedPersonIds: ["family-person", "private-person", "generation-person", "daughter-person", "son-person"],
            privacyMetadata: familyAll
        ),
        KBPlace(
            id: "daughter-place",
            name: "DAUGHTER_PLACE_SENTINEL",
            description: "DAUGHTER_PLACE_DESCRIPTION_SENTINEL",
            relatedPersonIds: ["daughter-person", "family-person", "son-person"],
            privacyMetadata: daughterOnly
        ),
        KBPlace(
            id: "generation-place",
            name: "GENERATION_PLACE_SENTINEL",
            description: "GENERATION_PLACE_DESCRIPTION_SENTINEL",
            relatedPersonIds: ["generation-person"],
            privacyMetadata: MemoryPrivacyMetadata(scope: .generationAllowed)
        )
    ],
    events: [
        KBEvent(
            id: "family-event",
            title: "FAMILY_EVENT_SENTINEL",
            description: "FAMILY_EVENT_DESCRIPTION_SENTINEL",
            locationId: "family-place",
            participantIds: ["family-person", "private-person", "daughter-person", "son-person"],
            privacyMetadata: familyAll
        ),
        KBEvent(
            id: "daughter-event",
            title: "DAUGHTER_EVENT_SENTINEL",
            description: "DAUGHTER_EVENT_DESCRIPTION_SENTINEL",
            locationId: "daughter-place",
            participantIds: ["daughter-person", "family-person", "son-person"],
            privacyMetadata: daughterOnly
        ),
        KBEvent(
            id: "local-event",
            title: "LOCAL_EVENT_SENTINEL",
            description: "LOCAL_EVENT_DESCRIPTION_SENTINEL",
            locationId: "family-place",
            participantIds: ["local-person"],
            privacyMetadata: MemoryPrivacyMetadata(scope: .localOnly)
        )
    ],
    facts: [
        KBFact(
            id: "family-fact",
            statement: "FAMILY_FACT_SENTINEL",
            confidence: "high",
            relatedPersonIds: ["family-person", "private-person", "daughter-person", "son-person"],
            relatedPlaceIds: ["family-place", "generation-place"],
            relatedEventIds: ["family-event", "daughter-event", "local-event"],
            privacyMetadata: familyAll
        ),
        KBFact(
            id: "daughter-fact",
            statement: "DAUGHTER_FACT_SENTINEL",
            confidence: "high",
            relatedPersonIds: ["daughter-person", "family-person", "son-person"],
            relatedPlaceIds: ["daughter-place", "family-place"],
            relatedEventIds: ["daughter-event", "family-event"],
            privacyMetadata: daughterOnly
        ),
        KBFact(
            id: "private-fact",
            statement: "PRIVATE_FACT_SENTINEL",
            confidence: "high",
            relatedPersonIds: ["private-person"],
            privacyMetadata: MemoryPrivacyMetadata(scope: .privateOnly)
        ),
        KBFact(
            id: "generation-fact",
            statement: "GENERATION_FACT_SENTINEL",
            confidence: "high",
            relatedPersonIds: ["generation-person"],
            relatedPlaceIds: ["generation-place"],
            privacyMetadata: MemoryPrivacyMetadata(scope: .generationAllowed)
        )
    ]
)

private let untargetedGraph = KBLitePrivacyScopePolicy.sanitizedGraph(sourceGraph, for: .familySync)
assertCondition(untargetedGraph.people.map(\.id) == ["family-person"], "untargeted package should include all-family people only")
assertCondition(untargetedGraph.places.map(\.id) == ["family-place"], "untargeted package should include all-family places only")
assertCondition(untargetedGraph.events.map(\.id) == ["family-event"], "untargeted package should include all-family events only")
assertCondition(untargetedGraph.facts.map(\.id) == ["family-fact"], "untargeted package should include all-family facts only")
assertCondition(untargetedGraph.people.first?.relatedPersonIds == [], "untargeted package should prune hidden person references")
assertCondition(untargetedGraph.events.first?.participantIds == ["family-person"], "untargeted package should prune hidden event participants")
assertCondition(untargetedGraph.facts.first?.relatedPersonIds == ["family-person"], "untargeted package should prune hidden fact people")
assertCondition(untargetedGraph.facts.first?.relatedPlaceIds == ["family-place"], "untargeted package should prune hidden fact places")
assertCondition(untargetedGraph.facts.first?.relatedEventIds == ["family-event"], "untargeted package should prune hidden fact events")

private let daughterGraph = KBLitePrivacyScopePolicy.sanitizedGraph(
    sourceGraph,
    for: .familySync,
    familyMemberID: "fm_daughter"
)
assertCondition(
    daughterGraph.people.map(\.id) == ["family-person", "daughter-person"],
    "daughter package should include all-family plus daughter-authorized people"
)
assertCondition(
    daughterGraph.places.map(\.id) == ["family-place", "daughter-place"],
    "daughter package should include all-family plus daughter-authorized places"
)
assertCondition(
    daughterGraph.events.map(\.id) == ["family-event", "daughter-event"],
    "daughter package should include all-family plus daughter-authorized events"
)
assertCondition(
    daughterGraph.facts.map(\.id) == ["family-fact", "daughter-fact"],
    "daughter package should include all-family plus daughter-authorized facts"
)
assertCondition(
    daughterGraph.people.first(where: { $0.id == "family-person" })?.relatedPersonIds == ["daughter-person"],
    "daughter package should prune family-person relation to son/private/local/generation"
)
assertCondition(
    daughterGraph.people.first(where: { $0.id == "daughter-person" })?.relatedPersonIds == ["family-person"],
    "daughter package should prune daughter relation to son"
)
assertCondition(
    daughterGraph.events.first(where: { $0.id == "daughter-event" })?.participantIds == ["daughter-person", "family-person"],
    "daughter package should prune daughter event participants"
)
assertCondition(
    daughterGraph.facts.first(where: { $0.id == "daughter-fact" })?.relatedPersonIds == ["daughter-person", "family-person"],
    "daughter package should prune daughter fact people"
)
assertCondition(
    daughterGraph.facts.first(where: { $0.id == "daughter-fact" })?.relatedEventIds == ["daughter-event", "family-event"],
    "daughter package should keep only visible related events"
)

private let sonGraph = KBLitePrivacyScopePolicy.sanitizedGraph(
    sourceGraph,
    for: .familySync,
    familyMemberID: "fm_son"
)
assertCondition(
    sonGraph.people.map(\.id) == ["family-person", "son-person"],
    "son package should include all-family plus son-authorized people"
)
assertCondition(
    !sonGraph.people.map(\.id).contains("daughter-person"),
    "son package should not include daughter-only person"
)

private let packageStrings = [
    packageJSON(sourceGraph),
    packageJSON(sourceGraph, familyMemberID: "fm_daughter"),
    packageJSON(sourceGraph, familyMemberID: "fm_son")
]
for package in packageStrings {
    assertCondition(!package.contains("PRIVATE_"), "share package JSON should not contain private sentinel")
    assertCondition(!package.contains("LOCAL_"), "share package JSON should not contain local sentinel")
    assertCondition(!package.contains("GENERATION_"), "share package JSON should not contain generation sentinel")
    assertCondition(package.contains("FAMILY_"), "share package JSON should retain all-family sentinel")
}
assertCondition(
    packageStrings[1].contains("DAUGHTER_PERSON_SENTINEL")
        && !packageStrings[1].contains("SON_PERSON_SENTINEL")
        && !packageStrings[1].contains("SON_TRAIT_SENTINEL"),
    "daughter share package JSON should contain daughter sentinel but not son-only sentinel"
)
assertCondition(
    packageStrings[2].contains("SON_PERSON_SENTINEL")
        && !packageStrings[2].contains("DAUGHTER_PERSON_SENTINEL")
        && !packageStrings[2].contains("DAUGHTER_TRAIT_SENTINEL"),
    "son share package JSON should contain son sentinel but not daughter-only sentinel"
)

print("SharePackagePrivacy verification passed")

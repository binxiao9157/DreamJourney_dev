import Foundation

private struct VerificationSharePackage: Codable {
    let sourceUserId: String
    let sourceNickname: String
    let exportDate: Date
    let graphJSON: String
}

private func fail(_ message: String) -> Never {
    fputs("FAIL: \(message)\n", stderr)
    exit(1)
}

private func assertCondition(_ condition: @autoclosure () -> Bool, _ message: String) {
    guard condition() else {
        fail(message)
    }
}

private func encodedGraphJSON(_ graph: KBLiteGraph) -> String {
    let encoder = JSONEncoder()
    encoder.dateEncodingStrategy = .iso8601
    encoder.outputFormatting = [.sortedKeys]
    guard let data = try? encoder.encode(graph),
          let json = String(data: data, encoding: .utf8) else {
        fail("graph should encode to JSON")
    }
    return json
}

private func sharePackageJSON(
    sourceGraph: KBLiteGraph,
    package: RoadshowDemoSeed.Package,
    familyMemberID: String?
) -> (json: String, graph: KBLiteGraph) {
    let sanitizedGraph = KBLitePrivacyScopePolicy.sanitizedGraph(
        sourceGraph,
        for: .familySync,
        familyMemberID: familyMemberID
    )
    let sharePackage = VerificationSharePackage(
        sourceUserId: "roadshow-seed-user",
        sourceNickname: package.members.first(where: { $0.id == package.selectedMemberIDForVisibility })?.displayName ?? "路演家庭",
        exportDate: Date(timeIntervalSince1970: 1_800_000_600),
        graphJSON: encodedGraphJSON(sanitizedGraph)
    )
    let encoder = JSONEncoder()
    encoder.dateEncodingStrategy = .iso8601
    encoder.outputFormatting = [.sortedKeys]
    guard let data = try? encoder.encode(sharePackage),
          let json = String(data: data, encoding: .utf8) else {
        fail("share package should encode to JSON")
    }
    return (json, sanitizedGraph)
}

private func assertDoesNotContain(_ text: String, _ forbidden: [String], context: String) {
    for term in forbidden where text.contains(term) {
        fail("\(context) should not contain forbidden term: \(term)")
    }
}

private func assertContains(_ text: String, _ required: [String], context: String) {
    for term in required where !text.contains(term) {
        fail("\(context) should contain required term: \(term)")
    }
}

private func makeRoadshowSeedGraph(package: RoadshowDemoSeed.Package, now: Date) -> KBLiteGraph {
    let familyMetadata = MemoryPrivacyMetadata(scope: .familyCircle, createdBySurface: .familySync, createdAt: now)
    let selectedMemberMetadata = MemoryPrivacyMetadata(
        scope: .familyCircle,
        createdBySurface: .familySync,
        createdAt: now,
        familyVisibility: .selectedMembers([package.selectedMemberIDForVisibility])
    )
    let sonOnlyMetadata = MemoryPrivacyMetadata(
        scope: .familyCircle,
        createdBySurface: .familySync,
        createdAt: now,
        familyVisibility: .selectedMembers(["fm_son_chen_hao"])
    )

    return KBLiteGraph(
        lastUpdated: now,
        sessionCount: 1,
        people: [
            KBPerson(
                id: "roadshow_person_grandpa",
                name: "陈树安",
                aliases: ["爷爷"],
                relation: "祖父",
                traits: ["说话慢", "重视团圆"],
                briefBio: "家人记忆中的温和长辈，常提醒晚辈慢慢来。",
                relatedPersonIds: [
                    "roadshow_person_grandma",
                    "roadshow_private_person",
                    "roadshow_generation_person",
                    "roadshow_son_only_person"
                ],
                sourceSessionIds: [1],
                createdAt: now,
                updatedAt: now,
                privacyMetadata: familyMetadata
            ),
            KBPerson(
                id: "roadshow_person_grandma",
                name: "陈静文",
                aliases: [],
                relation: "祖母",
                traits: ["喜欢整理老照片"],
                sourceSessionIds: [1],
                createdAt: now,
                updatedAt: now,
                privacyMetadata: selectedMemberMetadata
            ),
            KBPerson(
                id: "roadshow_son_only_person",
                name: "SON_ONLY_ROADSHOW_PERSON_SENTINEL",
                aliases: [],
                relation: "儿子可见",
                traits: ["SON_ONLY_ROADSHOW_TRAIT_SENTINEL"],
                sourceSessionIds: [2],
                createdAt: now,
                updatedAt: now,
                privacyMetadata: sonOnlyMetadata
            ),
            KBPerson(
                id: "roadshow_private_person",
                name: "PRIVATE_ROADSHOW_PERSON_SENTINEL",
                aliases: [],
                relation: nil,
                traits: ["PRIVATE_ROADSHOW_TRAIT_SENTINEL"],
                sourceSessionIds: [3],
                createdAt: now,
                updatedAt: now,
                privacyMetadata: MemoryPrivacyMetadata(scope: .privateOnly)
            ),
            KBPerson(
                id: "roadshow_local_person",
                name: "LOCAL_ROADSHOW_PERSON_SENTINEL",
                aliases: [],
                relation: nil,
                traits: ["LOCAL_ROADSHOW_TRAIT_SENTINEL"],
                sourceSessionIds: [4],
                createdAt: now,
                updatedAt: now,
                privacyMetadata: MemoryPrivacyMetadata(scope: .localOnly)
            ),
            KBPerson(
                id: "roadshow_generation_person",
                name: "GENERATION_ROADSHOW_PERSON_SENTINEL",
                aliases: [],
                relation: nil,
                traits: ["GENERATION_ROADSHOW_TRAIT_SENTINEL"],
                sourceSessionIds: [5],
                createdAt: now,
                updatedAt: now,
                privacyMetadata: MemoryPrivacyMetadata(scope: .generationAllowed)
            )
        ],
        places: [
            KBPlace(
                id: "roadshow_place_bund",
                name: "上海外滩",
                category: "visited",
                latitude: 31.2400,
                longitude: 121.4900,
                description: "路演样例中的家庭合影地点。",
                relatedPersonIds: [
                    "roadshow_person_grandpa",
                    "roadshow_person_grandma",
                    "roadshow_private_person",
                    "roadshow_generation_person",
                    "roadshow_son_only_person"
                ],
                sourceSessionIds: [1],
                createdAt: now,
                privacyMetadata: familyMetadata
            ),
            KBPlace(
                id: "roadshow_son_only_place",
                name: "SON_ONLY_ROADSHOW_PLACE_SENTINEL",
                description: "SON_ONLY_ROADSHOW_PLACE_DESCRIPTION_SENTINEL",
                relatedPersonIds: ["roadshow_son_only_person", "roadshow_person_grandpa"],
                sourceSessionIds: [2],
                createdAt: now,
                privacyMetadata: sonOnlyMetadata
            ),
            KBPlace(
                id: "roadshow_local_place",
                name: "LOCAL_ROADSHOW_PLACE_SENTINEL",
                description: "LOCAL_ROADSHOW_PLACE_DESCRIPTION_SENTINEL",
                sourceSessionIds: [3],
                createdAt: now,
                privacyMetadata: MemoryPrivacyMetadata(scope: .localOnly)
            )
        ],
        events: [
            KBEvent(
                id: "roadshow_event_bund_photo",
                title: "外滩全家合影",
                description: "1975 年 7 月家人在外滩留下的合影记忆。",
                year: 1975,
                month: 7,
                locationId: "roadshow_place_bund",
                participantIds: [
                    "roadshow_person_grandpa",
                    "roadshow_person_grandma",
                    "roadshow_private_person",
                    "roadshow_generation_person",
                    "roadshow_son_only_person"
                ],
                sourceSessionIds: [1],
                createdAt: now,
                privacyMetadata: familyMetadata
            ),
            KBEvent(
                id: "roadshow_son_only_event",
                title: "SON_ONLY_ROADSHOW_EVENT_SENTINEL",
                description: "SON_ONLY_ROADSHOW_EVENT_DESCRIPTION_SENTINEL",
                locationId: "roadshow_son_only_place",
                participantIds: ["roadshow_son_only_person", "roadshow_person_grandpa"],
                sourceSessionIds: [2],
                createdAt: now,
                privacyMetadata: sonOnlyMetadata
            ),
            KBEvent(
                id: "roadshow_generation_event",
                title: "GENERATION_ROADSHOW_EVENT_SENTINEL",
                description: "GENERATION_ROADSHOW_EVENT_DESCRIPTION_SENTINEL",
                participantIds: ["roadshow_generation_person"],
                sourceSessionIds: [3],
                createdAt: now,
                privacyMetadata: MemoryPrivacyMetadata(scope: .generationAllowed)
            )
        ],
        facts: [
            KBFact(
                id: "roadshow_fact_boundary",
                statement: "时空信箱回声只基于保存记忆整理，不代表逝者真实回复。",
                confidence: "confirmed",
                relatedPersonIds: [
                    "roadshow_person_grandpa",
                    "roadshow_person_grandma",
                    "roadshow_private_person",
                    "roadshow_generation_person",
                    "roadshow_son_only_person"
                ],
                relatedPlaceIds: ["roadshow_place_bund", "roadshow_local_place", "roadshow_son_only_place"],
                relatedEventIds: ["roadshow_event_bund_photo", "roadshow_son_only_event", "roadshow_generation_event"],
                sourceSessionIds: [1],
                createdAt: now,
                privacyMetadata: familyMetadata
            ),
            KBFact(
                id: "roadshow_son_only_fact",
                statement: "SON_ONLY_ROADSHOW_FACT_SENTINEL",
                confidence: "high",
                relatedPersonIds: ["roadshow_son_only_person", "roadshow_person_grandpa"],
                relatedPlaceIds: ["roadshow_son_only_place", "roadshow_place_bund"],
                relatedEventIds: ["roadshow_son_only_event", "roadshow_event_bund_photo"],
                sourceSessionIds: [2],
                createdAt: now,
                privacyMetadata: sonOnlyMetadata
            ),
            KBFact(
                id: "roadshow_private_fact",
                statement: "PRIVATE_ROADSHOW_FACT_SENTINEL",
                confidence: "high",
                relatedPersonIds: ["roadshow_private_person"],
                sourceSessionIds: [3],
                createdAt: now,
                privacyMetadata: MemoryPrivacyMetadata(scope: .privateOnly)
            ),
            KBFact(
                id: "roadshow_local_fact",
                statement: "LOCAL_ROADSHOW_FACT_SENTINEL",
                confidence: "high",
                relatedPersonIds: ["roadshow_local_person"],
                sourceSessionIds: [4],
                createdAt: now,
                privacyMetadata: MemoryPrivacyMetadata(scope: .localOnly)
            ),
            KBFact(
                id: "roadshow_generation_fact",
                statement: "GENERATION_ROADSHOW_FACT_SENTINEL",
                confidence: "high",
                relatedPersonIds: ["roadshow_generation_person"],
                relatedEventIds: ["roadshow_generation_event"],
                sourceSessionIds: [5],
                createdAt: now,
                privacyMetadata: MemoryPrivacyMetadata(scope: .generationAllowed)
            )
        ]
    )
}

private let now = Date(timeIntervalSince1970: 1_800_000_600)
private let roadshowPackage = RoadshowDemoSeed.makePackage(now: now)
private let selectedMemberID = roadshowPackage.selectedMemberIDForVisibility
private let sourceGraph = makeRoadshowSeedGraph(package: roadshowPackage, now: now)

assertCondition(
    roadshowPackage.members.contains { $0.id == selectedMemberID },
    "selected-member visibility ID should come from roadshow seed members"
)
assertCondition(
    sourceGraph.people.contains { $0.id == "roadshow_person_grandma" && !$0.privacyMetadata.familyVisibility.includesAllMembers },
    "roadshow seed graph should include a selected-member-only entity"
)

private let allFamilyPackage = sharePackageJSON(sourceGraph: sourceGraph, package: roadshowPackage, familyMemberID: nil)
private let selectedMemberPackage = sharePackageJSON(sourceGraph: sourceGraph, package: roadshowPackage, familyMemberID: selectedMemberID)
private let sonMemberPackage = sharePackageJSON(sourceGraph: sourceGraph, package: roadshowPackage, familyMemberID: "fm_son_chen_hao")
private let packageCases = [
    ("all-family", allFamilyPackage),
    ("selected-member", selectedMemberPackage),
    ("son-member", sonMemberPackage)
]

private let forbiddenScopeSentinels = [
    "PRIVATE_ROADSHOW_",
    "LOCAL_ROADSHOW_",
    "GENERATION_ROADSHOW_"
]

for (name, packageCase) in packageCases {
    assertDoesNotContain(packageCase.json, forbiddenScopeSentinels, context: "\(name) share package")
    assertContains(
        packageCase.json,
        ["外滩全家合影", "时空信箱回声只基于保存记忆整理"],
        context: "\(name) share package"
    )
}

private let fullUserTranscriptTexts = roadshowPackage.transcript
    .filter { $0.role.lowercased() == "user" }
    .map(\.text)
private let fullLetterBodies = roadshowPackage.demoItems
    .filter { $0.stepID == RoadshowDemoSeed.DemoStepID.timeMailbox.rawValue }
    .map(\.body)

for (name, packageCase) in packageCases {
    assertDoesNotContain(
        packageCase.json,
        fullUserTranscriptTexts,
        context: "\(name) share package"
    )
    assertDoesNotContain(
        packageCase.json,
        fullLetterBodies,
        context: "\(name) share package"
    )
}

assertCondition(
    allFamilyPackage.graph.people.map(\.id) == ["roadshow_person_grandpa"],
    "all-family package should not include selected-member-only people"
)
assertCondition(
    allFamilyPackage.graph.places.map(\.id) == ["roadshow_place_bund"],
    "all-family package should include only all-family places"
)
assertCondition(
    allFamilyPackage.graph.events.map(\.id) == ["roadshow_event_bund_photo"],
    "all-family package should include only all-family events"
)
assertCondition(
    allFamilyPackage.graph.facts.map(\.id) == ["roadshow_fact_boundary"],
    "all-family package should include only all-family facts"
)
assertCondition(
    allFamilyPackage.graph.people.first?.relatedPersonIds == [],
    "all-family package should prune selected/private/local/generation person references"
)
assertCondition(
    allFamilyPackage.graph.events.first?.participantIds == ["roadshow_person_grandpa"],
    "all-family package should prune hidden event participants"
)
assertCondition(
    allFamilyPackage.graph.facts.first?.relatedPersonIds == ["roadshow_person_grandpa"],
    "all-family package should prune hidden fact people"
)
assertCondition(
    allFamilyPackage.graph.facts.first?.relatedPlaceIds == ["roadshow_place_bund"],
    "all-family package should prune hidden fact places"
)
assertCondition(
    allFamilyPackage.graph.facts.first?.relatedEventIds == ["roadshow_event_bund_photo"],
    "all-family package should prune hidden fact events"
)

assertCondition(
    selectedMemberPackage.graph.people.map(\.id) == ["roadshow_person_grandpa", "roadshow_person_grandma"],
    "selected-member package should include all-family plus selected-member-only people"
)
assertCondition(
    selectedMemberPackage.graph.people.first(where: { $0.id == "roadshow_person_grandpa" })?.relatedPersonIds == ["roadshow_person_grandma"],
    "selected-member package should prune grandpa relations to only visible people"
)
assertCondition(
    selectedMemberPackage.graph.events.first?.participantIds == ["roadshow_person_grandpa", "roadshow_person_grandma"],
    "selected-member package should retain only visible event participants"
)
assertCondition(
    selectedMemberPackage.json.contains("陈静文"),
    "selected-member package should retain selected-member roadshow entity"
)
assertCondition(
    !selectedMemberPackage.json.contains("SON_ONLY_ROADSHOW_"),
    "selected-member package should not leak another member's selected data"
)

assertCondition(
    sonMemberPackage.graph.people.map(\.id) == ["roadshow_person_grandpa", "roadshow_son_only_person"],
    "son package should include all-family plus son-only people"
)
assertCondition(
    sonMemberPackage.json.contains("SON_ONLY_ROADSHOW_PERSON_SENTINEL"),
    "son package should retain son-only sentinel for the son viewer"
)
assertCondition(
    !sonMemberPackage.json.contains("陈静文"),
    "son package should not include selected daughter-only roadshow entity"
)

print("RoadshowSharePackage verification passed")

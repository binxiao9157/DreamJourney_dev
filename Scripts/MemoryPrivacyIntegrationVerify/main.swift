import Foundation

private func assertCondition(_ condition: @autoclosure () -> Bool, _ message: String) {
    guard condition() else {
        fputs("FAIL: \(message)\n", stderr)
        exit(1)
    }
}

let localTurnJSON = """
{"role":"user","text":"只在本机聊聊","timestamp":0}
""".data(using: .utf8)!

let decodedLegacyTurn = try JSONDecoder().decode(ConversationTurn.self, from: localTurnJSON)
assertCondition(decodedLegacyTurn.privacyMetadata.scope == .localOnly, "legacy turn should default to localOnly")

let legacyMemoryJSON = """
{"lastSessionDate":0,"lastSummary":{"time":"1968年","place":"杭州","person":"爷爷","event":"散步"},"sessionCount":1,"recentTranscript":[]}
""".data(using: .utf8)!
let decodedLegacyMemory = try JSONDecoder().decode(ConversationMemory.self, from: legacyMemoryJSON)
assertCondition(decodedLegacyMemory.lastSummaryPrivacyMetadata.scope == .localOnly, "legacy memory summary should default to localOnly")
assertCondition(
    !PrivacyScopePolicy.canUse(metadata: decodedLegacyMemory.lastSummaryPrivacyMetadata, surface: .prompt),
    "legacy local summary should not be prompt-usable"
)
var generationMemory = ConversationMemory()
generationMemory.lastSummary = decodedLegacyMemory.lastSummary
generationMemory.lastSummaryPrivacyMetadata = MemoryPrivacyMetadata(scope: .generationAllowed)
assertCondition(
    PrivacyScopePolicy.canUse(metadata: generationMemory.lastSummaryPrivacyMetadata, surface: .prompt),
    "explicit generation summary should be prompt-usable"
)

let generationInput = Stage1MailboxMemoryInput(
    text: "可以用于生成的上海工作记忆",
    privacyMetadata: MemoryPrivacyMetadata(scope: .generationAllowed)
)
assertCondition(generationInput.privacyMetadata.scope == .generationAllowed, "input should carry explicit generation scope")

let dialogMessages = [
    DialogMessage(role: "user", text: "本机对话", privacyMetadata: MemoryPrivacyMetadata(scope: .localOnly)),
    DialogMessage(role: "user", text: "生成授权对话", privacyMetadata: MemoryPrivacyMetadata(scope: .generationAllowed)),
    DialogMessage(role: "ai", text: "亲友对话", privacyMetadata: MemoryPrivacyMetadata(scope: .familyCircle))
]
let memoirDialogMessages = PrivacyScopePolicy.sanitized(items: dialogMessages, surface: .memoirGeneration)
assertCondition(memoirDialogMessages.map(\.text) == ["生成授权对话"], "memoir generation should only use generationAllowed dialog messages")

let scopedTurns = [
    ConversationTurn(role: "user", text: "私密内容", timestamp: Date(), privacyMetadata: MemoryPrivacyMetadata(scope: .privateOnly)),
    ConversationTurn(role: "user", text: "本机内容", timestamp: Date(), privacyMetadata: MemoryPrivacyMetadata(scope: .localOnly)),
    ConversationTurn(role: "user", text: "可生成内容", timestamp: Date(), privacyMetadata: MemoryPrivacyMetadata(scope: .generationAllowed)),
    ConversationTurn(role: "user", text: "家庭关怀内容", timestamp: Date(), privacyMetadata: MemoryPrivacyMetadata(scope: .familyCircle))
]
let remoteTurns = KBLitePrivacyScopePolicy.remoteExtractableTurns(from: scopedTurns)
assertCondition(remoteTurns.map(\.text) == ["可生成内容"], "only generationAllowed turns should enter remote extraction")
let careTurns = scopedTurns.filter {
    PrivacyScopePolicy.canUse(metadata: $0.privacyMetadata, surface: .careDashboard)
}
assertCondition(careTurns.map(\.text) == ["家庭关怀内容"], "only familyCircle turns should enter care dashboard")
assertCondition(
    KBLitePrivacyScopePolicy.derivedEntityMetadata(from: remoteTurns).scope == .generationAllowed,
    "entities derived only from generationAllowed turns should remain generationAllowed"
)
assertCondition(
    KBLitePrivacyScopePolicy.derivedEntityMetadata(from: careTurns).scope == .familyCircle,
    "entities derived only from familyCircle turns should remain familyCircle"
)
let mixedDerivedMetadata = KBLitePrivacyScopePolicy.derivedEntityMetadata(from: [
    ConversationTurn(role: "user", text: "本机片段", timestamp: Date(), privacyMetadata: MemoryPrivacyMetadata(scope: .localOnly)),
    ConversationTurn(role: "user", text: "可生成片段", timestamp: Date(), privacyMetadata: MemoryPrivacyMetadata(scope: .generationAllowed))
])
assertCondition(
    mixedDerivedMetadata.scope == .localOnly,
    "mixed-scope derived entities should not upgrade local content into remote-usable scope"
)
assertCondition(
    KBLitePrivacyScopePolicy.canMerge(
        existing: MemoryPrivacyMetadata(scope: .generationAllowed),
        incoming: MemoryPrivacyMetadata(scope: .generationAllowed)
    ),
    "same-scope generation entities should be mergeable"
)
assertCondition(
    !KBLitePrivacyScopePolicy.canMerge(
        existing: MemoryPrivacyMetadata(scope: .familyCircle),
        incoming: MemoryPrivacyMetadata(scope: .generationAllowed)
    ),
    "cross-scope family and generation entities should not merge"
)

var person = KBPerson(id: "p1", name: "爷爷", aliases: [], relation: nil, traits: [], sourceSessionIds: [1], createdAt: Date(), updatedAt: Date())
assertCondition(person.privacyMetadata.scope == .localOnly, "new KBPerson should default to localOnly")
person.privacyMetadata = MemoryPrivacyMetadata(scope: .generationAllowed)
assertCondition(PrivacyScopePolicy.canUse(metadata: person.privacyMetadata, surface: .prompt), "generation KBPerson should be prompt-usable")

let legacyGraphJSON = """
{"version":1,"lastUpdated":0,"sessionCount":0,"people":[],"places":[],"events":[],"facts":[]}
""".data(using: .utf8)!
let graph = try JSONDecoder().decode(KBLiteGraph.self, from: legacyGraphJSON)
assertCondition(graph.version == 2, "decoded graph should migrate to v2 in memory")

let sentinelGraph = KBLiteGraph(
    version: 2,
    lastUpdated: Date(timeIntervalSince1970: 0),
    sessionCount: 7,
    people: [
        KBPerson(
            id: "private-person",
            name: "PRIVATE_PERSON_SENTINEL",
            aliases: [],
            relation: nil,
            traits: [],
            sourceSessionIds: [1],
            createdAt: Date(),
            updatedAt: Date(),
            privacyMetadata: MemoryPrivacyMetadata(scope: .privateOnly)
        ),
        KBPerson(
            id: "generation-person",
            name: "GENERATION_PERSON_SENTINEL",
            aliases: [],
            relation: nil,
            traits: [],
            relatedPersonIds: ["family-person", "private-person"],
            sourceSessionIds: [2],
            createdAt: Date(),
            updatedAt: Date(),
            privacyMetadata: MemoryPrivacyMetadata(scope: .generationAllowed)
        ),
        KBPerson(
            id: "family-person",
            name: "FAMILY_PERSON_SENTINEL",
            aliases: [],
            relation: nil,
            traits: [],
            relatedPersonIds: ["generation-person", "private-person"],
            sourceSessionIds: [3],
            createdAt: Date(),
            updatedAt: Date(),
            privacyMetadata: MemoryPrivacyMetadata(scope: .familyCircle)
        )
    ],
    places: [
        KBPlace(
            id: "local-place",
            name: "LOCAL_PLACE_SENTINEL",
            privacyMetadata: MemoryPrivacyMetadata(scope: .localOnly)
        ),
        KBPlace(
            id: "generation-place",
            name: "GENERATION_PLACE_SENTINEL",
            relatedPersonIds: ["generation-person", "family-person", "private-person"],
            privacyMetadata: MemoryPrivacyMetadata(scope: .generationAllowed)
        ),
        KBPlace(
            id: "family-place",
            name: "FAMILY_PLACE_SENTINEL",
            relatedPersonIds: ["family-person", "generation-person", "private-person"],
            privacyMetadata: MemoryPrivacyMetadata(scope: .familyCircle)
        )
    ],
    events: [
        KBEvent(
            id: "family-event",
            title: "FAMILY_EVENT_SENTINEL",
            locationId: "generation-place",
            participantIds: ["family-person", "generation-person", "private-person"],
            privacyMetadata: MemoryPrivacyMetadata(scope: .familyCircle)
        ),
        KBEvent(
            id: "generation-event",
            title: "GENERATION_EVENT_SENTINEL",
            locationId: "family-place",
            participantIds: ["generation-person", "family-person"],
            privacyMetadata: MemoryPrivacyMetadata(scope: .generationAllowed)
        )
    ],
    facts: [
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
            relatedPersonIds: ["generation-person", "family-person"],
            relatedPlaceIds: ["generation-place", "family-place"],
            relatedEventIds: ["generation-event", "family-event"],
            privacyMetadata: MemoryPrivacyMetadata(scope: .generationAllowed)
        ),
        KBFact(
            id: "family-fact",
            statement: "FAMILY_FACT_SENTINEL",
            confidence: "high",
            relatedPersonIds: ["family-person", "generation-person"],
            relatedPlaceIds: ["family-place", "generation-place"],
            relatedEventIds: ["family-event", "generation-event"],
            privacyMetadata: MemoryPrivacyMetadata(scope: .familyCircle)
        )
    ]
)

let promptGraph = KBLitePrivacyScopePolicy.sanitizedGraph(sentinelGraph, for: .prompt)
assertCondition(promptGraph.people.map(\.id) == ["generation-person"], "prompt graph should only contain generationAllowed people")
assertCondition(promptGraph.places.map(\.id) == ["generation-place"], "prompt graph should only contain generationAllowed places")
assertCondition(promptGraph.events.map(\.id) == ["generation-event"], "prompt graph should only contain generationAllowed events")
assertCondition(promptGraph.facts.map(\.id) == ["generation-fact"], "prompt graph should only contain generationAllowed facts")
assertCondition(promptGraph.people.first?.relatedPersonIds == [], "prompt graph should prune person relations")
assertCondition(promptGraph.places.first?.relatedPersonIds == ["generation-person"], "prompt graph should prune place person refs")
assertCondition(promptGraph.events.first?.locationId == nil, "prompt graph should prune event location")
assertCondition(promptGraph.events.first?.participantIds == ["generation-person"], "prompt graph should prune event participants")
assertCondition(promptGraph.facts.first?.relatedPersonIds == ["generation-person"], "prompt graph should prune fact person refs")
assertCondition(promptGraph.facts.first?.relatedPlaceIds == ["generation-place"], "prompt graph should prune fact place refs")
assertCondition(promptGraph.facts.first?.relatedEventIds == ["generation-event"], "prompt graph should prune fact event refs")
let promptRelatedFacts = KBLitePrivacyScopePolicy.relatedFacts(
    in: sentinelGraph,
    relatedPersonId: "generation-person",
    surface: .prompt
)
assertCondition(
    promptRelatedFacts.map(\.id) == ["generation-fact"],
    "prompt related facts should not include family/private facts linked to a prompt-usable person"
)

let familyGraph = KBLitePrivacyScopePolicy.sanitizedGraph(sentinelGraph, for: .familySync)
assertCondition(familyGraph.people.map(\.id) == ["family-person"], "family sync graph should only contain familyCircle people")
assertCondition(familyGraph.places.map(\.id) == ["family-place"], "family sync graph should only contain familyCircle places")
assertCondition(familyGraph.events.map(\.id) == ["family-event"], "family sync graph should only contain familyCircle events")
assertCondition(familyGraph.facts.map(\.id) == ["family-fact"], "family sync graph should only contain familyCircle facts")
assertCondition(familyGraph.people.first?.relatedPersonIds == [], "family sync graph should prune person relations")
assertCondition(familyGraph.places.first?.relatedPersonIds == ["family-person"], "family sync graph should prune place person refs")
assertCondition(familyGraph.events.first?.locationId == nil, "family sync graph should prune event location")
assertCondition(familyGraph.events.first?.participantIds == ["family-person"], "family sync graph should prune event participants")
assertCondition(familyGraph.facts.first?.relatedPersonIds == ["family-person"], "family sync graph should prune fact person refs")
assertCondition(familyGraph.facts.first?.relatedPlaceIds == ["family-place"], "family sync graph should prune fact place refs")
assertCondition(familyGraph.facts.first?.relatedEventIds == ["family-event"], "family sync graph should prune fact event refs")
let familyData = try JSONEncoder().encode(familyGraph)
let familyJSON = String(data: familyData, encoding: .utf8) ?? ""
assertCondition(!familyJSON.contains("PRIVATE_"), "family sync JSON should not contain private sentinel")
assertCondition(!familyJSON.contains("LOCAL_"), "family sync JSON should not contain local sentinel")
assertCondition(!familyJSON.contains("GENERATION_"), "family sync JSON should not contain generation sentinel")
assertCondition(familyJSON.contains("FAMILY_"), "family sync JSON should contain family sentinel")

let exportGraph = KBLitePrivacyScopePolicy.sanitizedGraph(sentinelGraph, for: .export)
assertCondition(exportGraph.people.isEmpty, "export graph should be empty until explicit export scope exists")
assertCondition(exportGraph.places.isEmpty, "export graph should omit localOnly places")
assertCondition(exportGraph.events.isEmpty, "export graph should omit events by default")
assertCondition(exportGraph.facts.isEmpty, "export graph should omit facts by default")
let exportData = try JSONEncoder().encode(exportGraph)
let exportJSON = String(data: exportData, encoding: .utf8) ?? ""
assertCondition(!exportJSON.contains("_SENTINEL"), "export JSON should not contain sentinel text by default")

let widgetGraph = KBLitePrivacyScopePolicy.sanitizedGraph(sentinelGraph, for: .widget)
assertCondition(widgetGraph.events.isEmpty, "widget graph should omit events by default")

let backendGraph = KBLitePrivacyScopePolicy.sanitizedGraph(sentinelGraph, for: .backendSync)
assertCondition(backendGraph.people.isEmpty, "backend sync graph should be empty until explicit backend scope exists")

let careGraph = KBLitePrivacyScopePolicy.sanitizedGraph(sentinelGraph, for: .careDashboard)
assertCondition(careGraph.people.map(\.id) == ["family-person"], "care dashboard graph should only contain familyCircle people")

print("MemoryPrivacyIntegration verification passed")

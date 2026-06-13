import Foundation

private func assertCondition(_ condition: @autoclosure () -> Bool, _ message: String) {
    guard condition() else {
        fputs("FAIL: \(message)\n", stderr)
        exit(1)
    }
}

let metadata = MemoryPrivacyMetadata(scope: .generationAllowed)
let graph = KBLiteGraph(
    version: 2,
    lastUpdated: Date(timeIntervalSince1970: 1_800_000_000),
    sessionCount: 1,
    people: [
        KBPerson(
            id: "p_self",
            name: "陈建国",
            aliases: [],
            relation: "本人",
            traits: [],
            sourceSessionIds: [1],
            createdAt: Date(),
            updatedAt: Date(),
            privacyMetadata: metadata
        ),
        KBPerson(
            id: "p_wife",
            name: "林桂芳",
            aliases: [],
            relation: "妻子",
            traits: [],
            sourceSessionIds: [1],
            createdAt: Date(),
            updatedAt: Date(),
            privacyMetadata: metadata
        )
    ],
    places: [
        KBPlace(
            id: "pl_shaoxing",
            name: "绍兴越城区仓桥直街",
            category: "lived",
            description: "用户明确提到曾住在这里。",
            sourceSessionIds: [1],
            privacyMetadata: metadata
        )
    ],
    events: [
        KBEvent(
            id: "e_photo",
            title: "开小照相馆",
            description: "1978年我和妻子林桂芳在杭州西湖边开过一家小照相馆",
            year: 1978,
            participantIds: ["p_self", "p_wife"],
            sourceSessionIds: [1],
            privacyMetadata: metadata
        )
    ],
    facts: [
        KBFact(
            id: "f_lived",
            statement: "1968年住在绍兴越城区仓桥直街",
            confidence: "high",
            relatedPersonIds: ["p_self"],
            relatedPlaceIds: ["pl_shaoxing"],
            sourceSessionIds: [1],
            privacyMetadata: metadata
        ),
        KBFact(
            id: "f_photo",
            statement: "1978年我和妻子林桂芳在杭州西湖边开过一家小照相馆",
            confidence: "high",
            relatedPersonIds: ["p_self", "p_wife"],
            relatedEventIds: ["e_photo"],
            sourceSessionIds: [1],
            privacyMetadata: metadata
        )
    ]
)

let role = DialogMemoryGroundingPolicy.systemRoleAppendix()
assertCondition(role.contains("已知家庭记忆"), "system role should name the evidence source")
assertCondition(role.contains("不得编造"), "system role should prohibit fabrication")
assertCondition(role.contains("还没有记住这段"), "system role should define unknown-answer behavior")

assertCondition(
    MemoryIntentClassifier.classify("我以前住在哪里？和谁开过照相馆？") == .factQuestion,
    "fact questions should be classified for evidence-first answering"
)
assertCondition(
    MemoryIntentClassifier.classify("我叫陈建国，1968年住在绍兴越城区仓桥直街。") == .newMemoryCapture,
    "first-person factual narration should be classified as new memory capture"
)
assertCondition(
    MemoryIntentClassifier.classify("今天天气不错，我们随便聊聊") == .casualChat,
    "casual chat should not force evidence retrieval"
)

let evidencePack = MemoryEvidencePack.build(
    query: "我以前住在哪里？和谁开过照相馆？",
    graph: graph,
    maxItems: 4
)
assertCondition(evidencePack.intent == .factQuestion, "evidence pack should keep classified intent")
assertCondition(evidencePack.items.count >= 3, "evidence pack should collect relevant people/place/event/facts")
assertCondition(
    evidencePack.items.contains { $0.kind == .place && $0.text.contains("仓桥直街") },
    "evidence pack should include relevant place evidence"
)
assertCondition(
    evidencePack.items.contains { $0.kind == .person && $0.text.contains("林桂芳") },
    "evidence pack should include relevant person evidence"
)
assertCondition(
    MemoryGroundedReplyPlanner.makePlan(pack: evidencePack).mode == .answerWithEvidence,
    "planner should answer with evidence when evidence exists"
)

let missingPack = MemoryEvidencePack.build(
    query: "我年轻时候去过巴黎吗？",
    graph: KBLiteGraph(),
    maxItems: 4
)
let missingPlan = MemoryGroundedReplyPlanner.makePlan(pack: missingPack)
assertCondition(missingPlan.mode == .askForMissingMemory, "planner should ask for missing memory when evidence is absent")
assertCondition(missingPlan.instruction.contains("不要编造"), "missing-memory plan should prohibit fabrication")

let capturePack = MemoryEvidencePack.build(
    query: "我叫陈建国，1968年住在绍兴越城区仓桥直街。",
    graph: graph,
    maxItems: 4
)
assertCondition(capturePack.intent == .newMemoryCapture, "new facts should be recognized before answering")
assertCondition(
    MemoryGroundedReplyPlanner.makePlan(pack: capturePack).mode == .captureNewMemory,
    "planner should confirm and continue when user contributes new memory"
)

let queryContext = DialogMemoryGroundingPolicy.queryContext(
    for: "我以前住在哪里？和谁开过照相馆？",
    graph: graph,
    maxItems: 4
)
assertCondition(queryContext.contains("【本轮记忆意图】factQuestion"), "query context should expose the memory intent")
assertCondition(queryContext.contains("【回复计划】answerWithEvidence"), "query context should expose the reply plan")
assertCondition(queryContext.contains("1968年住在绍兴越城区仓桥直街"), "query context should include relevant lived fact")
assertCondition(queryContext.contains("林桂芳"), "query context should include relevant person")
assertCondition(queryContext.contains("开过一家小照相馆"), "query context should include relevant event/fact")
assertCondition(queryContext.contains("如果没有证据"), "query context should repeat unknown-answer rule")

let emptyContext = DialogMemoryGroundingPolicy.queryContext(
    for: "我年轻时候去过巴黎吗？",
    graph: KBLiteGraph(),
    maxItems: 4
)
assertCondition(emptyContext.contains("没有检索到相关家庭记忆"), "empty query context should explicitly say no evidence was found")
assertCondition(emptyContext.contains("不要编造"), "empty query context should prohibit fabrication")
assertCondition(emptyContext.contains("【回复计划】askForMissingMemory"), "empty query context should expose missing-memory plan")

print("DialogMemoryGrounding verification passed")

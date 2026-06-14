import Foundation

func assertCondition(_ condition: @autoclosure () -> Bool, _ message: String) {
    if !condition() {
        fputs("DialogMemoryRAGPayload verification failed: \(message)\n", stderr)
        exit(1)
    }
}

let now = Date(timeIntervalSince1970: 1_800_000_200)
let promptMetadata = MemoryPrivacyMetadata(scope: .generationAllowed, createdAt: now)
let privateMetadata = MemoryPrivacyMetadata(scope: .privateOnly, createdAt: now)

let graph = KBLiteGraph(
    people: [
        KBPerson(
            id: "person-lin-guifang",
            name: "林桂芳",
            aliases: ["桂芳"],
            relation: "妻子",
            traits: ["慢性子", "说话轻"],
            briefBio: "林桂芳常说慢慢来，饭要趁热吃。",
            sourceSessionIds: [1],
            createdAt: now,
            updatedAt: now,
            privacyMetadata: promptMetadata
        )
    ],
    facts: [
        KBFact(
            id: "fact-catchphrase",
            statement: "林桂芳的口头禅是“慢慢来，饭要趁热吃”。",
            confidence: "high",
            relatedPersonIds: ["person-lin-guifang"],
            sourceSessionIds: [1],
            createdAt: now,
            privacyMetadata: promptMetadata
        ),
        KBFact(
            id: "fact-private",
            statement: "林桂芳有一条私密家庭记录，不能用于生成。",
            confidence: "high",
            relatedPersonIds: ["person-lin-guifang"],
            sourceSessionIds: [1],
            createdAt: now,
            privacyMetadata: privateMetadata
        )
    ]
)

guard let payload = DialogMemoryRAGPayloadBuilder.makePayload(
    query: "林桂芳平时怎么说话？",
    graph: graph,
    maxItems: 5
) else {
    fputs("DialogMemoryRAGPayload verification failed: expected payload for matching archive evidence\n", stderr)
    exit(1)
}

assertCondition(payload.contains("external_rag"), "payload should use official external_rag field")
assertCondition(payload.count <= DialogMemoryRAGPayloadBuilder.maxPayloadCharacters, "payload should stay within realtime RAG size budget")
assertCondition(payload.contains("慢慢来"), "payload should include query-specific persona evidence")
assertCondition(!payload.contains("私密家庭记录"), "payload must not include private-only evidence")

guard let data = payload.data(using: .utf8),
      let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
      let externalRAG = object["external_rag"] as? String,
      let ragData = externalRAG.data(using: .utf8),
      let ragItems = try? JSONSerialization.jsonObject(with: ragData) as? [[String: Any]]
else {
    fputs("DialogMemoryRAGPayload verification failed: external_rag should be a JSON array string\n", stderr)
    exit(1)
}

assertCondition(!ragItems.isEmpty, "external_rag should include at least one item")
assertCondition(ragItems.allSatisfy { ($0["title"] as? String)?.isEmpty == false }, "each RAG item should have title")
assertCondition(ragItems.allSatisfy { ($0["content"] as? String)?.isEmpty == false }, "each RAG item should have content")

let noMatchPayload = DialogMemoryRAGPayloadBuilder.makePayload(
    query: "今天天气不错",
    graph: graph,
    maxItems: 5
)
assertCondition(noMatchPayload == nil, "casual query with no matching evidence should not send RAG payload")

let missingFactPayload = DialogMemoryRAGPayloadBuilder.makePayload(
    query: "张三是谁？",
    graph: graph,
    maxItems: 5
)
assertCondition(missingFactPayload?.contains("没有检索到相关家庭记忆") == true, "missing fact questions should still send a no-evidence boundary")

print("DialogMemoryRAGPayload verification passed")

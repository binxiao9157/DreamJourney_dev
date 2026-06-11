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

let generationInput = Stage1MailboxMemoryInput(
    text: "可以用于生成的上海工作记忆",
    privacyMetadata: MemoryPrivacyMetadata(scope: .generationAllowed)
)
assertCondition(generationInput.privacyMetadata.scope == .generationAllowed, "input should carry explicit generation scope")

let scopedTurns = [
    ConversationTurn(role: "user", text: "私密内容", timestamp: Date(), privacyMetadata: MemoryPrivacyMetadata(scope: .privateOnly)),
    ConversationTurn(role: "user", text: "本机内容", timestamp: Date(), privacyMetadata: MemoryPrivacyMetadata(scope: .localOnly)),
    ConversationTurn(role: "user", text: "可生成内容", timestamp: Date(), privacyMetadata: MemoryPrivacyMetadata(scope: .generationAllowed))
]
let remoteTurns = KBLitePrivacyScopePolicy.remoteExtractableTurns(from: scopedTurns)
assertCondition(remoteTurns.map(\.text) == ["可生成内容"], "only generationAllowed turns should enter remote extraction")

var person = KBPerson(id: "p1", name: "爷爷", aliases: [], relation: nil, traits: [], sourceSessionIds: [1], createdAt: Date(), updatedAt: Date())
assertCondition(person.privacyMetadata.scope == .localOnly, "new KBPerson should default to localOnly")
person.privacyMetadata = MemoryPrivacyMetadata(scope: .generationAllowed)
assertCondition(PrivacyScopePolicy.canUse(metadata: person.privacyMetadata, surface: .prompt), "generation KBPerson should be prompt-usable")

let legacyGraphJSON = """
{"version":1,"lastUpdated":0,"sessionCount":0,"people":[],"places":[],"events":[],"facts":[]}
""".data(using: .utf8)!
let graph = try JSONDecoder().decode(KBLiteGraph.self, from: legacyGraphJSON)
assertCondition(graph.version == 2, "decoded graph should migrate to v2 in memory")

print("MemoryPrivacyIntegration verification passed")

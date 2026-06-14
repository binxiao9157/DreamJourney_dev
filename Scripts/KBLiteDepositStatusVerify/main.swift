import Foundation

func require(_ condition: @autoclosure () -> Bool, _ message: String) {
    if !condition() {
        fputs("KBLiteDepositStatus verification failed: \(message)\n", stderr)
        exit(1)
    }
}

let now = Date(timeIntervalSince1970: 1_781_234_567)

let conversationMetadata = MemoryPrivacyMetadata(
    scope: .generationAllowed,
    sourceRefs: [
        MemorySourceRef(kind: .conversationTurn, id: "turn-1", title: "绍兴往事", capturedAt: now)
    ],
    createdBySurface: .prompt,
    createdAt: now
)

let archiveMetadata = MemoryPrivacyMetadata(
    scope: .familyCircle,
    sourceRefs: [
        MemorySourceRef(kind: .memoryArchiveItem, id: "archive-1", title: "西湖老照片", capturedAt: now)
    ],
    createdBySurface: .memoirGeneration,
    createdAt: now
)

let archiveMetadataOnlyMetadata = MemoryPrivacyMetadata(
    scope: .generationAllowed,
    sourceRefs: [
        MemorySourceRef(kind: .memoryArchiveItem, id: "archive-metadata-only", title: "未分析照片", capturedAt: now)
    ],
    createdBySurface: .memoirGeneration,
    createdAt: now
)

let mailboxMetadata = MemoryPrivacyMetadata(
    scope: .localOnly,
    sourceRefs: [
        MemorySourceRef(kind: .timeMailboxLetter, id: "letter-1", title: "写给孙女", capturedAt: now)
    ],
    createdBySurface: .timeMailboxEcho,
    createdAt: now
)

let graph = KBLiteGraph(
    lastUpdated: now,
    sessionCount: 3,
    people: [
        KBPerson(
            id: "p1",
            name: "陈建国",
            aliases: [],
            relation: "本人",
            traits: ["摄影"],
            sourceSessionIds: [1],
            createdAt: now,
            updatedAt: now,
            privacyMetadata: conversationMetadata
        )
    ],
    places: [
        KBPlace(
            id: "pl1",
            name: "杭州西湖",
            category: "worked",
            sourceSessionIds: [2],
            createdAt: now,
            privacyMetadata: archiveMetadata
        )
    ],
    facts: [
        KBFact(
            id: "archive-f1",
            statement: "西湖老照片记录了一次家庭合影",
            confidence: "confirmed",
            sourceSessionIds: [2],
            createdAt: now,
            privacyMetadata: archiveMetadata
        ),
        KBFact(
            id: "archive-metadata-only-f1",
            statement: "记忆档案馆保存照片素材《未分析照片》。",
            confidence: "confirmed",
            sourceSessionIds: [2],
            createdAt: now,
            privacyMetadata: archiveMetadataOnlyMetadata
        ),
        KBFact(
            id: "f1",
            statement: "写给孙女的信将在未来投递",
            confidence: "confirmed",
            sourceSessionIds: [3],
            createdAt: now,
            privacyMetadata: mailboxMetadata
        ),
        KBFact(
            id: "f2",
            statement: "旧版实体没有来源标记",
            confidence: "medium",
            sourceSessionIds: [3],
            createdAt: now,
            privacyMetadata: MemoryPrivacyMetadata(scope: .localOnly)
        )
    ]
)

let status = KBLiteDepositStatusBuilder.build(from: graph)

require(status.totalEntityCount == 6, "should count all knowledge entities")
require(status.sessionCount == 3, "should expose processed session count")
require(status.conversationSourceCount == 1, "should count conversation source refs")
require(status.archiveSourceCount == 2, "should count all unique archive source refs, including metadata-only sources")
require(status.archiveStructuredKnowledgeSourceCount == 1, "metadata-only archive source facts should not count as structured archive knowledge")
require(status.mailboxSourceCount == 1, "should count mailbox source refs")
require(status.untaggedSourceCount == 1, "should count untagged legacy entities")
require(status.generationAllowedCount == 2, "should count generationAllowed entities")
require(status.familyCircleCount == 2, "should count familyCircle entities")
require(status.localOnlyCount == 2, "should count localOnly entities")
require(status.sourceSummary.contains("对话 1"), "source summary should mention conversation")
require(status.sourceSummary.contains("档案 2"), "source summary should mention archive sources")
require(status.sourceSummary.contains("档案结构化 1"), "source summary should mention structured archive sources")
require(status.sourceSummary.contains("信箱 1"), "source summary should mention mailbox")
require(status.privacySummary.contains("本机 2"), "privacy summary should mention localOnly")
require(status.privacySummary.contains("可生成 2"), "privacy summary should mention generationAllowed")
require(status.privacySummary.contains("亲友 2"), "privacy summary should mention familyCircle")

print("KBLiteDepositStatus verification passed")

import Foundation

@main
enum KnowledgeGovernanceOutboxModelSmoke {
    static func main() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(
            "knowledge-governance-outbox-\(UUID().uuidString)",
            isDirectory: true
        )
        defer { try? FileManager.default.removeItem(at: root) }
        let store = KnowledgeGovernanceOutboxStore(rootDirectory: root)
        let decidedAt = Date(timeIntervalSince1970: 1_752_229_800)

        let first = item(
            operationId: "operation-1",
            userId: "user-a",
            action: .confirm(
                target: .init(entityType: .facts, entityId: "fact-1"),
                decidedAt: decidedAt
            )
        )
        let second = item(
            operationId: "operation-2",
            userId: "user-a",
            action: .deleteSource(
                sourceRef: .init(kind: "memoryArchiveItem", id: "archive-1"),
                decidedAt: decidedAt
            )
        )
        let otherUser = item(
            operationId: "operation-b",
            userId: "user-b",
            action: .reject(
                target: .init(entityType: .events, entityId: "event-1"),
                decidedAt: decidedAt
            )
        )

        try store.enqueue(first, for: "user-a")
        try store.enqueue(second, for: "user-a")
        try store.enqueue(otherUser, for: "user-b")
        try require(try store.load(for: "user-a") == [first, second], "queue order must persist")
        try require(try store.load(for: "user-b") == [otherUser], "users must be isolated")

        try store.enqueue(first, for: "user-a")
        try require(
            try store.load(for: "user-a") == [first, second],
            "same operation and semantic payload must be an idempotent no-op"
        )

        let replacement = item(
            operationId: "operation-1",
            userId: "user-a",
            action: .correct(
                target: .init(entityType: .facts, entityId: "fact-1"),
                correction: .fact(.init(statement: "corrected")),
                decidedAt: decidedAt
            )
        )
        requireThrows("duplicate operation with different payload must be rejected") {
            try store.enqueue(replacement, for: "user-a")
        }
        let rotated = first.rotatingOperation(to: "operation-1-retry")
        try store.replace(operationId: first.operationId, with: rotated, for: "user-a")
        try require(
            try store.load(for: "user-a") == [rotated, second],
            "payload conflict recovery must atomically rotate the operation"
        )
        let quarantined = rotated.quarantined(reason: "knowledgeOperationPayloadConflict")
        try store.replace(operationId: rotated.operationId, with: quarantined, for: "user-a")
        let afterQuarantine = try store.load(for: "user-a")
        require(afterQuarantine.first?.isQuarantined == true, "second conflict must persist quarantine")
        require(afterQuarantine.last == second, "quarantine must not remove later queue items")

        try store.remove(operationId: "operation-1-retry", for: "user-a")
        try require(try store.load(for: "user-a") == [second], "single removal must persist")
        try store.remove(operationId: "operation-2", for: "user-a")
        try require(try store.load(for: "user-a").isEmpty, "empty queue must remove its file")
        try require(try store.load(for: "user-b") == [otherUser], "user B must survive user A removal")

        try store.removeAll(for: "user-b")
        try require(try store.count(for: "user-b") == 0, "removeAll must clear the user queue")
        verifyInvalidItem(store: store, decidedAt: decidedAt)
        try verifyBackwardCompatibleEnvelope(root: root, decidedAt: decidedAt)
        try verifyCorruptEnvelope(root: root, decidedAt: decidedAt)
        print("Knowledge governance outbox model smoke passed")
    }

    private static func item(
        operationId: String,
        userId: String,
        action: KBKnowledgeGovernanceAction
    ) -> KnowledgeGovernanceOutboxItem {
        KnowledgeGovernanceOutboxItem(
            operationId: operationId,
            userId: userId,
            expectedOwnerUserId: userId,
            expectedPersonaScope: "personal",
            expectedDigitalHumanId: userId,
            action: action,
            createdAt: Date(timeIntervalSince1970: 1_752_229_800)
        )
    }

    private static func verifyInvalidItem(
        store: KnowledgeGovernanceOutboxStore,
        decidedAt: Date
    ) {
        let invalid = item(
            operationId: "",
            userId: "user-a",
            action: .confirm(
                target: .init(entityType: .facts, entityId: "fact-1"),
                decidedAt: decidedAt
            )
        )
        requireThrows("empty operation ID must be rejected") {
            try store.enqueue(invalid, for: "user-a")
        }
        let wrongUser = item(
            operationId: "wrong-user",
            userId: "user-b",
            action: .confirm(
                target: .init(entityType: .facts, entityId: "fact-1"),
                decidedAt: decidedAt
            )
        )
        requireThrows("cross-user item must be rejected") {
            try store.enqueue(wrongUser, for: "user-a")
        }
    }

    private static func verifyCorruptEnvelope(root: URL, decidedAt: Date) throws {
        let corruptRoot = root.appendingPathComponent("corrupt", isDirectory: true)
        let store = KnowledgeGovernanceOutboxStore(rootDirectory: corruptRoot)
        try store.enqueue(
            item(
                operationId: "corrupt-operation",
                userId: "corrupt-user",
                action: .confirm(
                    target: .init(entityType: .facts, entityId: "fact-1"),
                    decidedAt: decidedAt
                )
            ),
            for: "corrupt-user"
        )
        let files = try FileManager.default.contentsOfDirectory(
            at: corruptRoot,
            includingPropertiesForKeys: nil
        )
        guard let url = files.first else { fail("outbox file must exist") }
        var object = try JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any]
        object?["schemaVersion"] = 2
        let corrupted = try JSONSerialization.data(withJSONObject: object ?? [:])
        try corrupted.write(to: url, options: .atomic)
        requireThrows("unsupported envelope schema must be rejected") {
            _ = try store.load(for: "corrupt-user")
        }
    }

    private static func verifyBackwardCompatibleEnvelope(root: URL, decidedAt: Date) throws {
        let legacyRoot = root.appendingPathComponent("legacy", isDirectory: true)
        let store = KnowledgeGovernanceOutboxStore(rootDirectory: legacyRoot)
        let legacyItem = item(
            operationId: "legacy-operation",
            userId: "legacy-user",
            action: .confirm(
                target: .init(entityType: .facts, entityId: "fact-1"),
                decidedAt: decidedAt
            )
        )
        try store.enqueue(legacyItem, for: "legacy-user")
        let files = try FileManager.default.contentsOfDirectory(
            at: legacyRoot,
            includingPropertiesForKeys: nil
        )
        guard let url = files.first,
              var object = try JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any],
              var items = object["items"] as? [[String: Any]],
              !items.isEmpty else {
            fail("legacy outbox envelope must exist")
        }
        items[0].removeValue(forKey: "recoveryCount")
        items[0].removeValue(forKey: "quarantineReason")
        object["items"] = items
        try JSONSerialization.data(withJSONObject: object).write(to: url, options: .atomic)
        let decoded = try store.load(for: "legacy-user")
        require(decoded == [legacyItem], "legacy outbox must default recovery metadata")
    }

    private static func require(_ condition: @autoclosure () throws -> Bool, _ message: String) rethrows {
        guard try condition() else { fail(message) }
    }

    private static func requireThrows(_ message: String, _ body: () throws -> Void) {
        do {
            try body()
            fail(message)
        } catch {
            return
        }
    }

    private static func fail(_ message: String) -> Never {
        fputs("knowledge-governance-outbox-model-smoke failed: \(message)\n", stderr)
        exit(1)
    }
}

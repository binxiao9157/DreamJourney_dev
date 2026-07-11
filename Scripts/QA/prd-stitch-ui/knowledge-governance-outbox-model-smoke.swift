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

        let replacement = item(
            operationId: "operation-1",
            userId: "user-a",
            action: .correct(
                target: .init(entityType: .facts, entityId: "fact-1"),
                correction: .fact(.init(statement: "corrected")),
                decidedAt: decidedAt
            )
        )
        try store.enqueue(replacement, for: "user-a")
        try require(
            try store.load(for: "user-a") == [replacement, second],
            "duplicate operation must update in place without reordering"
        )

        try store.remove(operationId: "operation-1", for: "user-a")
        try require(try store.load(for: "user-a") == [second], "single removal must persist")
        try store.remove(operationId: "operation-2", for: "user-a")
        try require(try store.load(for: "user-a").isEmpty, "empty queue must remove its file")
        try require(try store.load(for: "user-b") == [otherUser], "user B must survive user A removal")

        try store.removeAll(for: "user-b")
        try require(try store.count(for: "user-b") == 0, "removeAll must clear the user queue")
        verifyInvalidItem(store: store, decidedAt: decidedAt)
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

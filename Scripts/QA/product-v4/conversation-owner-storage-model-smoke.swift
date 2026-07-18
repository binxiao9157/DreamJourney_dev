import Foundation

struct AccountLease: Codable, Equatable, Sendable {
    let subjectId: String
    let vaultId: String
    let sessionId: String
    let generation: UInt64
    let generationId: UUID
    let authorityEpoch: String
}

struct ConversationTurn: Codable {
    let role: String
    let text: String
    let timestamp: Date
}

struct MemorySummary: Codable {
    var time = ""
    var place = ""
    var person = ""
    var event = ""
}

struct ConversationMemory: Codable {
    var lastSessionDate = Date()
    var lastSummary = MemorySummary()
    var sessionCount = 0
    var recentTranscript: [ConversationTurn] = []
    var mentionedPeople: [String] = []
    var mentionedPlaces: [String] = []
    var mentionedFoods: [String] = []
    var lastTopic = ""
    var recentTopics: [String] = []
}

@main
enum ConversationOwnerStorageModelSmoke {
    static func main() throws {
        let fileManager = FileManager.default
        let root = fileManager.temporaryDirectory
            .appendingPathComponent("dj-conversation-owner-\(UUID().uuidString)", isDirectory: true)
        let support = root.appendingPathComponent("support", isDirectory: true)
        let documents = root.appendingPathComponent("documents", isDirectory: true)
        try fileManager.createDirectory(at: support, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: documents, withIntermediateDirectories: true)
        defer { try? fileManager.removeItem(at: root) }

        let fixedNow = Date(timeIntervalSince1970: 1_782_000_000)
        let storage = ConversationLocalStorage(
            fileManager: fileManager,
            applicationSupportRoot: support,
            legacyDocumentsRoot: documents,
            now: { fixedNow }
        )
        let leaseA = lease(subject: "account-a", vault: "vault-a", generation: 1)
        let leaseANext = lease(subject: "account-a", vault: "vault-a", generation: 2)
        let leaseB = lease(subject: "account-b", vault: "vault-b", generation: 1)
        let personalA = requireScope(leaseA, owner: "account-a", persona: .personal)
        let personalANext = requireScope(leaseANext, owner: "account-a", persona: .personal)
        let personalB = requireScope(leaseB, owner: "account-b", persona: .personal)

        require(storage.memoryURL(scope: personalA) != storage.memoryURL(scope: personalB), "A/B paths must differ")
        require(
            storage.memoryURL(scope: personalA) == storage.memoryURL(scope: personalANext),
            "generation rotation must not orphan persistent owner data"
        )

        var memoryA = ConversationMemory()
        memoryA.sessionCount = 3
        memoryA.lastSummary.event = "桂花糕"
        try storage.save(memory: memoryA, scope: personalA)
        require(storage.mount(scope: personalA).sessionCount == 3, "owner A data must round-trip")
        require(storage.mount(scope: personalANext).lastSummary.event == "桂花糕", "new generation must read same owner data")
        require(storage.mount(scope: personalB).sessionCount == 0, "owner B must not see owner A data")
        do {
            try storage.save(
                memory: memory(sessionCount: 99, event: "stale"),
                scope: personalA,
                commitValidator: { false }
            )
            fatalError("stale commit validator must reject the final write")
        } catch ConversationLocalStorageError.staleCommit {
            require(
                storage.mount(scope: personalA).sessionCount == 3,
                "a rejected stale commit must preserve the prior owner payload"
            )
        }

        let familyOwner = "family-member"
        let familyA = requireScope(leaseA, owner: familyOwner, persona: .family)
        let familyB = requireScope(leaseB, owner: familyOwner, persona: .family)
        require(storage.memoryURL(scope: familyA) != storage.memoryURL(scope: familyB), "family viewer/vault must remain isolated")

        let migrationRoot = root.appendingPathComponent("migration", isDirectory: true)
        let migrationSupport = migrationRoot.appendingPathComponent("support", isDirectory: true)
        let migrationDocuments = migrationRoot.appendingPathComponent("documents", isDirectory: true)
        try fileManager.createDirectory(at: migrationDocuments, withIntermediateDirectories: true)
        let migrationStorage = ConversationLocalStorage(
            fileManager: fileManager,
            applicationSupportRoot: migrationSupport,
            legacyDocumentsRoot: migrationDocuments,
            now: { fixedNow }
        )
        let legacyMemory = memory(sessionCount: 7, event: "老家院子")
        try encode(legacyMemory).write(
            to: migrationStorage.legacyScopedURL(scope: personalA),
            options: [.atomic]
        )
        let migrated = migrationStorage.mount(scope: personalA)
        require(migrated.sessionCount == 7, "explicit self legacy must migrate")
        require(
            migrationStorage.migrationReceipt(scope: personalA)?.disposition == .migrated,
            "self migration must leave a receipt"
        )
        require(
            fileManager.fileExists(atPath: migrationStorage.legacyScopedURL(scope: personalA).path),
            "copy-on-write migration must not destructively retire its source"
        )

        let familyRoot = root.appendingPathComponent("family", isDirectory: true)
        let familyStorage = ConversationLocalStorage(
            fileManager: fileManager,
            applicationSupportRoot: familyRoot.appendingPathComponent("support"),
            legacyDocumentsRoot: familyRoot.appendingPathComponent("documents"),
            now: { fixedNow }
        )
        try fileManager.createDirectory(
            at: familyStorage.legacyScopedURL(scope: familyA).deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try encode(memory(sessionCount: 9, event: "不应认领"))
            .write(to: familyStorage.legacyScopedURL(scope: familyA), options: [.atomic])
        require(familyStorage.mount(scope: familyA).sessionCount == 0, "family owner-only legacy must not auto-claim")
        require(
            familyStorage.migrationReceipt(scope: familyA)?.disposition == .quarantined,
            "ambiguous family legacy must leave a quarantine receipt"
        )
        require(
            familyStorage.quarantineRecord(sourceURL: familyStorage.legacyScopedURL(scope: familyA))?.reason == .ambiguousOwner,
            "family legacy quarantine reason must be explicit"
        )

        let globalRoot = root.appendingPathComponent("global", isDirectory: true)
        let globalStorage = ConversationLocalStorage(
            fileManager: fileManager,
            applicationSupportRoot: globalRoot.appendingPathComponent("support"),
            legacyDocumentsRoot: globalRoot.appendingPathComponent("documents"),
            now: { fixedNow }
        )
        try fileManager.createDirectory(at: globalStorage.globalLegacyURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try encode(memory(sessionCount: 11, event: "全局旧数据"))
            .write(to: globalStorage.globalLegacyURL, options: [.atomic])
        require(globalStorage.mount(scope: personalA).sessionCount == 0, "global legacy must never auto-mount")
        require(
            globalStorage.quarantineRecord(sourceURL: globalStorage.globalLegacyURL)?.reason == .ambiguousOwner,
            "global legacy must enter quarantine"
        )

        let corruptRoot = root.appendingPathComponent("corrupt", isDirectory: true)
        let corruptStorage = ConversationLocalStorage(
            fileManager: fileManager,
            applicationSupportRoot: corruptRoot.appendingPathComponent("support"),
            legacyDocumentsRoot: corruptRoot.appendingPathComponent("documents"),
            now: { fixedNow }
        )
        let corruptURL = corruptStorage.memoryURL(scope: personalA)
        try fileManager.createDirectory(at: corruptURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data("not-json".utf8).write(to: corruptURL)
        require(corruptStorage.mount(scope: personalA).sessionCount == 0, "corrupt envelope must fail closed")
        require(
            corruptStorage.quarantineRecord(sourceURL: corruptURL)?.reason == .corrupt,
            "corrupt envelope must be auditable"
        )

        try storage.save(memory: memory(sessionCount: 4, event: "B"), scope: personalB)
        storage.purge(accountLease: leaseA)
        require(storage.mount(scope: personalA).sessionCount == 0, "account purge must remove owner A")
        require(storage.mount(scope: personalB).sessionCount == 4, "account purge must preserve owner B")

        require(
            ConversationStorageScope(accountLease: leaseA, ownerId: "user_001", personaScope: .family) == nil,
            "reserved fallback owners must never form a production scope"
        )
        print("Conversation owner storage model smoke passed")
    }

    private static func lease(subject: String, vault: String, generation: UInt64) -> AccountLease {
        AccountLease(
            subjectId: subject,
            vaultId: vault,
            sessionId: "session-\(subject)-\(generation)",
            generation: generation,
            generationId: UUID(),
            authorityEpoch: "epoch-1"
        )
    }

    private static func requireScope(
        _ lease: AccountLease,
        owner: String,
        persona: ConversationPersonaScope
    ) -> ConversationStorageScope {
        guard let scope = ConversationStorageScope(accountLease: lease, ownerId: owner, personaScope: persona) else {
            fatalError("expected valid scope")
        }
        return scope
    }

    private static func memory(sessionCount: Int, event: String) -> ConversationMemory {
        var result = ConversationMemory()
        result.sessionCount = sessionCount
        result.lastSummary.event = event
        return result
    }

    private static func encode(_ memory: ConversationMemory) throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys]
        return try encoder.encode(memory)
    }

    private static func require(_ condition: @autoclosure () -> Bool, _ message: String) {
        guard condition() else { fatalError(message) }
    }
}

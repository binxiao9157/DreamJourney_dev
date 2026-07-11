import Foundation

struct KnowledgeSyncConflict: Equatable {
    let entityType: String
    let entityId: String
}

struct KnowledgeSyncMergeResult {
    let graph: [String: Any]
    let conflicts: [KnowledgeSyncConflict]

    var qaConflictSummary: String {
        let identities = conflicts
            .map { "\($0.entityType):\($0.entityId)" }
            .sorted()
            .joined(separator: ",")
        return "count=\(conflicts.count) entities=\(identities)"
    }
}

struct KnowledgeTombstone: Equatable {
    let entityType: String
    let entityId: String
    let deletedAt: String

    var jsonObject: [String: Any] {
        [
            "entityType": entityType,
            "entityId": entityId,
            "deletedAt": deletedAt,
        ]
    }
}

struct KnowledgeMutationDelta {
    let upserts: [String: [[String: Any]]]
    let tombstones: [KnowledgeTombstone]

    var isEmpty: Bool {
        tombstones.isEmpty && !upserts.values.contains(where: { !$0.isEmpty })
    }

    var jsonObject: [String: Any] {
        [
            "upserts": upserts,
            "tombstones": tombstones.map(\KnowledgeTombstone.jsonObject),
        ]
    }
}

struct KnowledgeRemoteBaseSnapshot {
    let revision: Int
    let graph: [String: Any]
}

struct KnowledgePendingMutation {
    let operationId: String
    let baseRevision: Int
    let localFingerprint: String
    let deletedAt: String
    let payload: [String: Any]
}

enum KnowledgeSyncModelError: LocalizedError {
    case invalidGraph(String)
    case invalidPersistenceEnvelope
    case operationPayloadConflict
    case invalidChangePage(String)

    var errorDescription: String? {
        switch self {
        case .invalidGraph(let reason):
            return "知识图谱无效：\(reason)"
        case .invalidPersistenceEnvelope:
            return "知识同步基线文件无效"
        case .operationPayloadConflict:
            return "同一知识操作编号不能对应不同治理内容"
        case .invalidChangePage(let reason):
            return "知识增量分页无效：\(reason)"
        }
    }
}

struct KnowledgeChangePage {
    let userId: String
    let sinceRevision: Int
    let currentRevision: Int
    let targetRevision: Int
    let nextSinceRevision: Int
    let hasMore: Bool
    let pageLimit: Int?
    let changes: [[String: Any]]
    let isLegacy: Bool

    init(
        json: [String: Any],
        expectedUserId: String,
        requestedSinceRevision: Int,
        requestedTargetRevision: Int?
    ) throws {
        guard let userId = json["userId"] as? String,
              userId == expectedUserId,
              let sinceRevision = Self.intValue(json["sinceRevision"]),
              sinceRevision == requestedSinceRevision,
              let currentRevision = Self.intValue(json["currentRevision"]),
              currentRevision >= 0,
              let changes = json["changes"] as? [[String: Any]] else {
            throw KnowledgeSyncModelError.invalidChangePage("identity or base fields mismatch")
        }

        let paginationKeys = ["targetRevision", "nextSinceRevision", "hasMore", "pageLimit"]
        let paginationFieldCount = paginationKeys.filter { json[$0] != nil }.count
        let isLegacy = paginationFieldCount == 0
        guard isLegacy || paginationFieldCount == paginationKeys.count else {
            throw KnowledgeSyncModelError.invalidChangePage("pagination fields must be all present")
        }

        var previousRevision = sinceRevision
        for change in changes {
            guard let revision = Self.intValue(change["revision"]),
                  revision == previousRevision + 1,
                  change["graph"] is [String: Any],
                  Self.hasValidMutationMetadata(change) else {
                throw KnowledgeSyncModelError.invalidChangePage("changes must be contiguous full snapshots")
            }
            previousRevision = revision
        }

        if isLegacy {
            guard requestedTargetRevision == nil,
                  previousRevision == currentRevision,
                  currentRevision >= sinceRevision else {
                throw KnowledgeSyncModelError.invalidChangePage("legacy response is not terminal")
            }
            self.userId = userId
            self.sinceRevision = sinceRevision
            self.currentRevision = currentRevision
            self.targetRevision = currentRevision
            self.nextSinceRevision = previousRevision
            self.hasMore = false
            self.pageLimit = nil
            self.changes = changes
            self.isLegacy = true
            return
        }

        guard let targetRevision = Self.intValue(json["targetRevision"]),
              let nextSinceRevision = Self.intValue(json["nextSinceRevision"]),
              let hasMore = json["hasMore"] as? Bool,
              let pageLimit = Self.intValue(json["pageLimit"]),
              (1...100).contains(pageLimit),
              changes.count <= pageLimit,
              currentRevision == targetRevision,
              sinceRevision <= targetRevision,
              requestedTargetRevision == nil || requestedTargetRevision == targetRevision,
              nextSinceRevision == previousRevision,
              hasMore == (nextSinceRevision < targetRevision),
              !hasMore || !changes.isEmpty,
              hasMore || nextSinceRevision == targetRevision else {
            throw KnowledgeSyncModelError.invalidChangePage("pagination watermarks are inconsistent")
        }

        self.userId = userId
        self.sinceRevision = sinceRevision
        self.currentRevision = currentRevision
        self.targetRevision = targetRevision
        self.nextSinceRevision = nextSinceRevision
        self.hasMore = hasMore
        self.pageLimit = pageLimit
        self.changes = changes
        self.isLegacy = false
    }

    private static func intValue(_ value: Any?) -> Int? {
        if let value = value as? Int { return value }
        if let value = value as? NSNumber { return value.intValue }
        if let value = value as? String { return Int(value) }
        return nil
    }

    private static func hasValidMutationMetadata(_ change: [String: Any]) -> Bool {
        guard let rawVersion = change["mutationSchemaVersion"] else { return true }
        guard let version = intValue(rawVersion) else { return false }
        if version == 1 { return true }
        return version == 2 && change["mutation"] is [String: Any]
    }
}

struct KnowledgeChangeFeedReduction {
    let nextSinceRevision: Int
    let targetRevision: Int
    let isTerminal: Bool
    let authoritativeSnapshot: KnowledgeRemoteBaseSnapshot?
}

struct KnowledgeChangeFeedReducer {
    let startRevision: Int
    let maxPageCount: Int
    private(set) var nextSinceRevision: Int
    private(set) var targetRevision: Int?
    private(set) var pageCount = 0
    private var latestSnapshot: KnowledgeRemoteBaseSnapshot?

    init(startRevision: Int, maxPageCount: Int = 200) {
        self.startRevision = max(0, startRevision)
        self.maxPageCount = max(1, maxPageCount)
        self.nextSinceRevision = max(0, startRevision)
    }

    mutating func consume(_ page: KnowledgeChangePage) throws -> KnowledgeChangeFeedReduction {
        guard pageCount < maxPageCount else {
            throw KnowledgeSyncModelError.invalidChangePage("page count exceeds limit")
        }
        guard page.sinceRevision == nextSinceRevision else {
            throw KnowledgeSyncModelError.invalidChangePage("page does not continue the prior watermark")
        }
        if let targetRevision {
            guard targetRevision == page.targetRevision, !page.isLegacy else {
                throw KnowledgeSyncModelError.invalidChangePage("target revision changed during pull")
            }
        } else {
            targetRevision = page.targetRevision
        }

        pageCount += 1
        nextSinceRevision = page.nextSinceRevision
        if let latest = page.changes.last,
           let revision = Self.intValue(latest["revision"]),
           let graph = latest["graph"] as? [String: Any] {
            latestSnapshot = KnowledgeRemoteBaseSnapshot(revision: revision, graph: graph)
        }

        if page.hasMore {
            return KnowledgeChangeFeedReduction(
                nextSinceRevision: nextSinceRevision,
                targetRevision: page.targetRevision,
                isTerminal: false,
                authoritativeSnapshot: nil
            )
        }

        guard nextSinceRevision == page.targetRevision else {
            throw KnowledgeSyncModelError.invalidChangePage("terminal page did not reach target")
        }
        return KnowledgeChangeFeedReduction(
            nextSinceRevision: nextSinceRevision,
            targetRevision: page.targetRevision,
            isTerminal: true,
            authoritativeSnapshot: latestSnapshot
        )
    }

    private static func intValue(_ value: Any?) -> Int? {
        if let value = value as? Int { return value }
        if let value = value as? NSNumber { return value.intValue }
        if let value = value as? String { return Int(value) }
        return nil
    }
}

enum KnowledgeGraphCASPolicy {
    static func canApply(
        expectedMutationToken: UInt64?,
        currentMutationToken: UInt64,
        expectedUserId: String?,
        currentUserId: String
    ) -> Bool {
        if let expectedUserId, expectedUserId != currentUserId {
            return false
        }
        if let expectedMutationToken, expectedMutationToken != currentMutationToken {
            return false
        }
        return true
    }
}

struct KnowledgeSyncAuthorizationScope: Equatable {
    private struct PersonaKey: Hashable {
        let personaScope: String
        let digitalHumanId: String
    }

    let ownerUserId: String
    private let allowedPersonaKeys: Set<PersonaKey>

    init(identity: KBPersonaIdentity, additionalIdentities: [KBPersonaIdentity] = []) {
        let normalizedOwner = KBPersonaIdentity.normalizedIdentifier(identity.ownerUserId)
        ownerUserId = normalizedOwner
        allowedPersonaKeys = Set(
            ([identity] + additionalIdentities).compactMap { candidate in
                let candidateOwner = KBPersonaIdentity.normalizedIdentifier(candidate.ownerUserId)
                let personaScope = KBPersonaIdentity.canonicalPersonaScope(candidate.personaScope)
                let digitalHumanId = KBPersonaIdentity.normalizedIdentifier(candidate.digitalHumanId)
                guard candidateOwner == normalizedOwner,
                      personaScope == "personal" || personaScope == "family",
                      !digitalHumanId.isEmpty else {
                    return nil
                }
                return PersonaKey(personaScope: personaScope, digitalHumanId: digitalHumanId)
            }
        )
    }

    var isComplete: Bool {
        !ownerUserId.isEmpty && !allowedPersonaKeys.isEmpty
    }

    func allows(ownerUserId: String, personaScope: String, digitalHumanId: String) -> Bool {
        let normalizedOwner = KBPersonaIdentity.normalizedIdentifier(ownerUserId)
        let key = PersonaKey(
            personaScope: KBPersonaIdentity.canonicalPersonaScope(personaScope),
            digitalHumanId: KBPersonaIdentity.normalizedIdentifier(digitalHumanId)
        )
        return normalizedOwner == self.ownerUserId && allowedPersonaKeys.contains(key)
    }

    func allows(identity: KBPersonaIdentity) -> Bool {
        allows(
            ownerUserId: identity.ownerUserId,
            personaScope: identity.personaScope,
            digitalHumanId: identity.digitalHumanId
        )
    }
}

enum KnowledgeSyncGraphEngine {
    static let entityTypes = ["people", "places", "events", "facts"]
    static let syncableScopes = Set(["generationAllowed", "familyCircle"])

    static func bootstrap(
        local: [String: Any],
        remote: [String: Any],
        authorization: KnowledgeSyncAuthorizationScope
    ) throws -> KnowledgeSyncMergeResult {
        try validate(local)
        try validate(remote)

        var output = graphTemplate(local: local, remote: remote)
        for entityType in entityTypes {
            let remoteEntities = try entities(in: remote, type: entityType)
                .filter { isSyncable($0, authorization: authorization) }
            let localEntities = try entities(in: local, type: entityType)
            var merged = index(remoteEntities)
            for entity in localEntities {
                merged[entityID(entity)] = entity
            }
            output[entityType] = orderedEntities(merged)
        }
        return KnowledgeSyncMergeResult(graph: output, conflicts: [])
    }

    static func merge(
        base: [String: Any],
        local: [String: Any],
        remote: [String: Any],
        authorization: KnowledgeSyncAuthorizationScope
    ) throws -> KnowledgeSyncMergeResult {
        try validate(base)
        try validate(local)
        try validate(remote)

        let comparableBase = try syncPayloadGraph(from: base, authorization: authorization)
        let comparableLocal = try syncPayloadGraph(from: local, authorization: authorization)
        let comparableRemote = try syncPayloadGraph(from: remote, authorization: authorization)
        var output = graphTemplate(local: local, remote: remote)
        var conflicts: [KnowledgeSyncConflict] = []

        for entityType in entityTypes {
            let rawBase = index(try entities(in: base, type: entityType).filter { isSyncable($0, authorization: authorization) })
            let rawLocal = index(try entities(in: local, type: entityType).filter { isSyncable($0, authorization: authorization) })
            let rawRemote = index(try entities(in: remote, type: entityType).filter { isSyncable($0, authorization: authorization) })
            let privateLocal = index(try entities(in: local, type: entityType).filter {
                !isSyncable($0, authorization: authorization)
            })

            let comparedBase = index(try entities(in: comparableBase, type: entityType))
            let comparedLocal = index(try entities(in: comparableLocal, type: entityType))
            let comparedRemote = index(try entities(in: comparableRemote, type: entityType))
            let ids = Set(rawBase.keys).union(rawLocal.keys).union(rawRemote.keys)
            var merged: [String: [String: Any]] = [:]

            for id in ids.sorted() {
                let baseValue = comparedBase[id]
                let localValue = comparedLocal[id]
                let remoteValue = comparedRemote[id]
                let chosen: [String: Any]?

                if jsonEqual(localValue, baseValue) {
                    chosen = rawRemote[id]
                } else if jsonEqual(remoteValue, baseValue) {
                    chosen = rawLocal[id]
                } else if jsonEqual(localValue, remoteValue) {
                    chosen = rawLocal[id] ?? rawRemote[id]
                } else {
                    chosen = rawLocal[id]
                    conflicts.append(KnowledgeSyncConflict(entityType: entityType, entityId: id))
                }
                if let chosen {
                    merged[id] = chosen
                }
            }

            // A local private entity is never replaced or removed by a remote entity with the same ID.
            for (id, entity) in privateLocal {
                merged[id] = entity
            }
            output[entityType] = orderedEntities(merged)
        }

        return KnowledgeSyncMergeResult(
            graph: output,
            conflicts: conflicts.sorted {
                ($0.entityType, $0.entityId) < ($1.entityType, $1.entityId)
            }
        )
    }

    static func makeDelta(
        base: [String: Any],
        local: [String: Any],
        deletedAt: String,
        authorization: KnowledgeSyncAuthorizationScope
    ) throws -> KnowledgeMutationDelta {
        try validate(base)
        try validate(local)
        let comparableBase = try syncPayloadGraph(from: base, authorization: authorization)
        let comparableLocal = try syncPayloadGraph(from: local, authorization: authorization)
        var upserts = emptyUpserts()
        var tombstones: [KnowledgeTombstone] = []

        for entityType in entityTypes {
            let baseByID = index(try entities(in: comparableBase, type: entityType))
            let localByID = index(try entities(in: comparableLocal, type: entityType))
            let allLocalByID = index(try entities(in: local, type: entityType))

            for id in localByID.keys.sorted() where !jsonEqual(localByID[id], baseByID[id]) {
                if let entity = localByID[id] {
                    upserts[entityType, default: []].append(entity)
                }
            }
            for id in baseByID.keys.sorted() where localByID[id] == nil {
                // A private/legacy local entity with the same ID must not produce a remote delete.
                guard allLocalByID[id] == nil else { continue }
                tombstones.append(
                    KnowledgeTombstone(
                        entityType: entityType,
                        entityId: id,
                        deletedAt: deletedAt
                    )
                )
            }
        }

        return KnowledgeMutationDelta(upserts: upserts, tombstones: tombstones)
    }

    static func syncPayloadGraph(
        from graph: [String: Any],
        authorization: KnowledgeSyncAuthorizationScope
    ) throws -> [String: Any] {
        try validate(graph)
        guard authorization.isComplete else {
            throw KnowledgeSyncModelError.invalidGraph("knowledge sync authorization is incomplete")
        }
        let people = try entities(in: graph, type: "people").filter {
            isSyncable($0, authorization: authorization)
        }
        let places = try entities(in: graph, type: "places").filter {
            isSyncable($0, authorization: authorization)
        }
        let peopleIDs = Set(people.map(entityID))
        let placeIDs = Set(places.map(entityID))

        let events = try entities(in: graph, type: "events")
            .filter { isSyncable($0, authorization: authorization) }
            .map { entity -> [String: Any] in
                var copy = sanitizeSourceReferences(in: entity)
                copy["participantIds"] = stringArray(copy["participantIds"]).filter(peopleIDs.contains)
                if let locationID = copy["locationId"] as? String, !placeIDs.contains(locationID) {
                    copy.removeValue(forKey: "locationId")
                }
                return copy
            }
        let eventIDs = Set(events.map(entityID))
        let facts = try entities(in: graph, type: "facts")
            .filter { isSyncable($0, authorization: authorization) }
            .map { entity -> [String: Any] in
                var copy = sanitizeSourceReferences(in: entity)
                copy["relatedPersonIds"] = stringArray(copy["relatedPersonIds"]).filter(peopleIDs.contains)
                copy["relatedPlaceIds"] = stringArray(copy["relatedPlaceIds"]).filter(placeIDs.contains)
                copy["relatedEventIds"] = stringArray(copy["relatedEventIds"]).filter(eventIDs.contains)
                return copy
            }

        var output = graph
        output["people"] = people.map(sanitizeSourceReferences)
        output["places"] = places.map(sanitizeSourceReferences)
        output["events"] = events
        output["facts"] = facts
        return output
    }

    static func fingerprint(of graph: [String: Any]) -> String? {
        guard JSONSerialization.isValidJSONObject(graph),
              let data = try? JSONSerialization.data(withJSONObject: graph, options: [.sortedKeys]) else {
            return nil
        }
        var hash: UInt64 = 14_695_981_039_346_656_037
        for byte in data {
            hash ^= UInt64(byte)
            hash &*= 1_099_511_628_211
        }
        return String(format: "%016llx", hash)
    }

    private static func validate(_ graph: [String: Any]) throws {
        for entityType in entityTypes {
            let values = try entities(in: graph, type: entityType)
            var ids = Set<String>()
            for entity in values {
                let id = entityID(entity)
                guard !id.isEmpty else {
                    throw KnowledgeSyncModelError.invalidGraph("\(entityType) entity requires id")
                }
                guard ids.insert(id).inserted else {
                    throw KnowledgeSyncModelError.invalidGraph("duplicate \(entityType) id \(id)")
                }
            }
        }
    }

    private static func entities(in graph: [String: Any], type: String) throws -> [[String: Any]] {
        guard let raw = graph[type] else { return [] }
        guard let values = raw as? [Any], values.allSatisfy({ $0 is [String: Any] }) else {
            throw KnowledgeSyncModelError.invalidGraph("\(type) must be an array of objects")
        }
        return values.compactMap { $0 as? [String: Any] }
    }

    private static func index(_ values: [[String: Any]]) -> [String: [String: Any]] {
        Dictionary(uniqueKeysWithValues: values.map { (entityID($0), $0) })
    }

    private static func orderedEntities(_ values: [String: [String: Any]]) -> [[String: Any]] {
        values.keys.sorted().compactMap { values[$0] }
    }

    private static func entityID(_ entity: [String: Any]) -> String {
        (entity["id"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }

    private static func isSyncable(
        _ entity: [String: Any],
        authorization: KnowledgeSyncAuthorizationScope
    ) -> Bool {
        guard let metadata = entity["privacyMetadata"] as? [String: Any],
              let scope = metadata["scope"] as? String,
              syncableScopes.contains(scope),
              let ownerUserId = normalizedString(entity["ownerUserId"]),
              let personaScope = normalizedString(entity["personaScope"]),
              let digitalHumanId = normalizedString(entity["digitalHumanId"]),
              authorization.allows(
                ownerUserId: ownerUserId,
                personaScope: personaScope,
                digitalHumanId: digitalHumanId
              ) else {
            return false
        }
        return true
    }

    private static func normalizedString(_ value: Any?) -> String? {
        guard let value = value as? String else { return nil }
        let normalized = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return normalized.isEmpty ? nil : normalized
    }

    private static func graphTemplate(local: [String: Any], remote: [String: Any]) -> [String: Any] {
        var output = remote
        output["version"] = max(intValue(local["version"], fallback: 1), intValue(remote["version"], fallback: 1))
        output["sessionCount"] = max(intValue(local["sessionCount"]), intValue(remote["sessionCount"]))
        output["lastUpdated"] = local["lastUpdated"] ?? remote["lastUpdated"] ?? isoTimestamp(Date())
        return output
    }

    private static func emptyUpserts() -> [String: [[String: Any]]] {
        Dictionary(uniqueKeysWithValues: entityTypes.map { ($0, []) })
    }

    private static func jsonEqual(_ lhs: [String: Any]?, _ rhs: [String: Any]?) -> Bool {
        switch (lhs, rhs) {
        case (nil, nil):
            return true
        case (.some(let lhs), .some(let rhs)):
            guard JSONSerialization.isValidJSONObject(lhs), JSONSerialization.isValidJSONObject(rhs),
                  let leftData = try? JSONSerialization.data(withJSONObject: lhs, options: [.sortedKeys]),
                  let rightData = try? JSONSerialization.data(withJSONObject: rhs, options: [.sortedKeys]) else {
                return false
            }
            return leftData == rightData
        default:
            return false
        }
    }

    private static func sanitizeSourceReferences(in entity: [String: Any]) -> [String: Any] {
        var copy = entity
        guard var metadata = copy["privacyMetadata"] as? [String: Any],
              let references = metadata["sourceRefs"] as? [Any] else {
            return copy
        }
        metadata["sourceRefs"] = references.compactMap { value -> [String: Any]? in
            guard var reference = value as? [String: Any] else { return nil }
            reference["title"] = externalSourceTitle(kind: reference["kind"] as? String)
            return reference
        }
        copy["privacyMetadata"] = metadata
        return copy
    }

    private static func externalSourceTitle(kind: String?) -> String {
        switch kind ?? "unknown" {
        case "conversationTurn": return "对话来源"
        case "memoryArchiveItem": return "档案素材"
        case "timeMailboxLetter": return "时空信件"
        case "kbLiteEntity": return "知识条目"
        case "memoir": return "回忆录"
        case "importRecord": return "导入记录"
        case "userAuthorization": return "授权记录"
        default: return "来源记录"
        }
    }

    private static func stringArray(_ value: Any?) -> [String] {
        (value as? [Any] ?? []).compactMap { $0 as? String }
    }

    private static func intValue(_ value: Any?, fallback: Int = 0) -> Int {
        if let value = value as? Int { return value }
        if let value = value as? NSNumber { return value.intValue }
        if let value = value as? String { return Int(value) ?? fallback }
        return fallback
    }

    private static func isoTimestamp(_ date: Date) -> String {
        ISO8601DateFormatter().string(from: date)
    }
}

final class KnowledgeRemoteBaseStore {
    private let rootDirectory: URL

    init(rootDirectory: URL? = nil) {
        self.rootDirectory = rootDirectory ?? Self.defaultRootDirectory()
    }

    func load(for userId: String) throws -> KnowledgeRemoteBaseSnapshot? {
        let url = fileURL(prefix: "kb_sync_base", userId: userId)
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        let data = try Data(contentsOf: url)
        guard let object = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              object["userKey"] as? String == Self.userKey(userId),
              let graph = object["graph"] as? [String: Any],
              let revision = Self.intValue(object["revision"]), revision >= 0 else {
            throw KnowledgeSyncModelError.invalidPersistenceEnvelope
        }
        return KnowledgeRemoteBaseSnapshot(revision: revision, graph: graph)
    }

    func save(_ snapshot: KnowledgeRemoteBaseSnapshot, for userId: String) throws {
        guard snapshot.revision >= 0 else { throw KnowledgeSyncModelError.invalidPersistenceEnvelope }
        try write(
            [
                "schemaVersion": 1,
                "userKey": Self.userKey(userId),
                "revision": snapshot.revision,
                "graph": snapshot.graph,
            ],
            to: fileURL(prefix: "kb_sync_base", userId: userId)
        )
    }

    func remove(for userId: String) throws {
        let url = fileURL(prefix: "kb_sync_base", userId: userId)
        if FileManager.default.fileExists(atPath: url.path) {
            try FileManager.default.removeItem(at: url)
        }
    }

    private func fileURL(prefix: String, userId: String) -> URL {
        rootDirectory.appendingPathComponent("\(prefix)_\(Self.userKey(userId)).json")
    }

    private func write(_ object: [String: Any], to url: URL) throws {
        try FileManager.default.createDirectory(at: rootDirectory, withIntermediateDirectories: true)
        let data = try JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted, .sortedKeys])
        try data.write(to: url, options: .atomic)
    }

    private static func defaultRootDirectory() -> URL {
        let applicationSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        return applicationSupport.appendingPathComponent("knowledge_base", isDirectory: true)
    }

    fileprivate static func userKey(_ userId: String) -> String {
        var hash: UInt64 = 14_695_981_039_346_656_037
        for byte in userId.utf8 {
            hash ^= UInt64(byte)
            hash &*= 1_099_511_628_211
        }
        return String(format: "%016llx", hash)
    }

    fileprivate static func intValue(_ value: Any?) -> Int? {
        if let value = value as? Int { return value }
        if let value = value as? NSNumber { return value.intValue }
        if let value = value as? String { return Int(value) }
        return nil
    }
}

final class KnowledgePendingMutationStore {
    private let rootDirectory: URL

    init(rootDirectory: URL? = nil) {
        if let rootDirectory {
            self.rootDirectory = rootDirectory
        } else {
            let applicationSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
                ?? FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
            self.rootDirectory = applicationSupport.appendingPathComponent("knowledge_base", isDirectory: true)
        }
    }

    func load(for userId: String) throws -> KnowledgePendingMutation? {
        let url = fileURL(userId: userId)
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        let data = try Data(contentsOf: url)
        guard let object = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              object["userKey"] as? String == KnowledgeRemoteBaseStore.userKey(userId),
              let operationId = object["operationId"] as? String, !operationId.isEmpty,
              let baseRevision = KnowledgeRemoteBaseStore.intValue(object["baseRevision"]),
              let localFingerprint = object["localFingerprint"] as? String,
              let deletedAt = object["deletedAt"] as? String,
              let payload = object["payload"] as? [String: Any] else {
            throw KnowledgeSyncModelError.invalidPersistenceEnvelope
        }
        return KnowledgePendingMutation(
            operationId: operationId,
            baseRevision: baseRevision,
            localFingerprint: localFingerprint,
            deletedAt: deletedAt,
            payload: payload
        )
    }

    func save(_ pending: KnowledgePendingMutation, for userId: String) throws {
        try FileManager.default.createDirectory(at: rootDirectory, withIntermediateDirectories: true)
        let object: [String: Any] = [
            "schemaVersion": 1,
            "userKey": KnowledgeRemoteBaseStore.userKey(userId),
            "operationId": pending.operationId,
            "baseRevision": pending.baseRevision,
            "localFingerprint": pending.localFingerprint,
            "deletedAt": pending.deletedAt,
            "payload": pending.payload,
        ]
        let data = try JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted, .sortedKeys])
        try data.write(to: fileURL(userId: userId), options: .atomic)
    }

    func remove(for userId: String) throws {
        let url = fileURL(userId: userId)
        if FileManager.default.fileExists(atPath: url.path) {
            try FileManager.default.removeItem(at: url)
        }
    }

    private func fileURL(userId: String) -> URL {
        rootDirectory.appendingPathComponent(
            "kb_pending_mutation_\(KnowledgeRemoteBaseStore.userKey(userId)).json"
        )
    }
}

struct KnowledgeGovernanceOutboxItem: Codable, Equatable {
    let operationId: String
    let userId: String
    let expectedOwnerUserId: String
    let expectedPersonaScope: String
    let expectedDigitalHumanId: String
    let action: KBKnowledgeGovernanceAction
    let createdAt: Date
    let recoveryCount: Int
    let quarantineReason: String?

    init(
        operationId: String,
        userId: String,
        expectedOwnerUserId: String,
        expectedPersonaScope: String,
        expectedDigitalHumanId: String,
        action: KBKnowledgeGovernanceAction,
        createdAt: Date,
        recoveryCount: Int = 0,
        quarantineReason: String? = nil
    ) {
        self.operationId = operationId.trimmingCharacters(in: .whitespacesAndNewlines)
        self.userId = userId
        self.expectedOwnerUserId = expectedOwnerUserId
        self.expectedPersonaScope = expectedPersonaScope
        self.expectedDigitalHumanId = expectedDigitalHumanId
        self.action = action
        self.createdAt = createdAt
        self.recoveryCount = max(0, recoveryCount)
        self.quarantineReason = quarantineReason?.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private enum CodingKeys: String, CodingKey {
        case operationId
        case userId
        case expectedOwnerUserId
        case expectedPersonaScope
        case expectedDigitalHumanId
        case action
        case createdAt
        case recoveryCount
        case quarantineReason
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            operationId: try container.decode(String.self, forKey: .operationId),
            userId: try container.decode(String.self, forKey: .userId),
            expectedOwnerUserId: try container.decode(String.self, forKey: .expectedOwnerUserId),
            expectedPersonaScope: try container.decode(String.self, forKey: .expectedPersonaScope),
            expectedDigitalHumanId: try container.decode(String.self, forKey: .expectedDigitalHumanId),
            action: try container.decode(KBKnowledgeGovernanceAction.self, forKey: .action),
            createdAt: try container.decode(Date.self, forKey: .createdAt),
            recoveryCount: try container.decodeIfPresent(Int.self, forKey: .recoveryCount) ?? 0,
            quarantineReason: try container.decodeIfPresent(String.self, forKey: .quarantineReason)
        )
    }

    var expectedIdentity: KBPersonaIdentity {
        KBPersonaIdentity(
            ownerUserId: expectedOwnerUserId,
            personaScope: expectedPersonaScope,
            digitalHumanId: expectedDigitalHumanId
        )
    }

    var isQuarantined: Bool {
        guard let quarantineReason else { return false }
        return !quarantineReason.isEmpty
    }

    func hasSameSemanticPayload(as other: KnowledgeGovernanceOutboxItem) -> Bool {
        userId == other.userId
            && expectedOwnerUserId == other.expectedOwnerUserId
            && expectedPersonaScope == other.expectedPersonaScope
            && expectedDigitalHumanId == other.expectedDigitalHumanId
            && action == other.action
    }

    func rotatingOperation(to operationId: String) -> KnowledgeGovernanceOutboxItem {
        KnowledgeGovernanceOutboxItem(
            operationId: operationId,
            userId: userId,
            expectedOwnerUserId: expectedOwnerUserId,
            expectedPersonaScope: expectedPersonaScope,
            expectedDigitalHumanId: expectedDigitalHumanId,
            action: action,
            createdAt: createdAt,
            recoveryCount: recoveryCount + 1
        )
    }

    func quarantined(reason: String) -> KnowledgeGovernanceOutboxItem {
        KnowledgeGovernanceOutboxItem(
            operationId: operationId,
            userId: userId,
            expectedOwnerUserId: expectedOwnerUserId,
            expectedPersonaScope: expectedPersonaScope,
            expectedDigitalHumanId: expectedDigitalHumanId,
            action: action,
            createdAt: createdAt,
            recoveryCount: recoveryCount,
            quarantineReason: reason
        )
    }
}

final class KnowledgeGovernanceOutboxStore {
    private struct Envelope: Codable {
        let schemaVersion: Int
        let userKey: String
        let items: [KnowledgeGovernanceOutboxItem]
    }

    private let rootDirectory: URL

    init(rootDirectory: URL? = nil) {
        if let rootDirectory {
            self.rootDirectory = rootDirectory
        } else {
            let applicationSupport = FileManager.default.urls(
                for: .applicationSupportDirectory,
                in: .userDomainMask
            ).first ?? FileManager.default.urls(
                for: .documentDirectory,
                in: .userDomainMask
            ).first!
            self.rootDirectory = applicationSupport.appendingPathComponent(
                "knowledge_base",
                isDirectory: true
            )
        }
    }

    func load(for userId: String) throws -> [KnowledgeGovernanceOutboxItem] {
        let normalizedUserId = try normalizedIdentifier(userId)
        let url = fileURL(userId: normalizedUserId)
        guard FileManager.default.fileExists(atPath: url.path) else { return [] }
        do {
            let data = try Data(contentsOf: url)
            let envelope = try decoder.decode(Envelope.self, from: data)
            guard envelope.schemaVersion == 1,
                  envelope.userKey == KnowledgeRemoteBaseStore.userKey(normalizedUserId) else {
                throw KnowledgeSyncModelError.invalidPersistenceEnvelope
            }
            var operations = Set<String>()
            for item in envelope.items {
                try validate(item, expectedUserId: normalizedUserId)
                guard operations.insert(item.operationId).inserted else {
                    throw KnowledgeSyncModelError.invalidPersistenceEnvelope
                }
            }
            return envelope.items
        } catch let error as KnowledgeSyncModelError {
            throw error
        } catch {
            throw KnowledgeSyncModelError.invalidPersistenceEnvelope
        }
    }

    func enqueue(_ item: KnowledgeGovernanceOutboxItem, for userId: String) throws {
        let normalizedUserId = try normalizedIdentifier(userId)
        try validate(item, expectedUserId: normalizedUserId)
        var items = try load(for: normalizedUserId)
        if let index = items.firstIndex(where: { $0.operationId == item.operationId }) {
            guard items[index].hasSameSemanticPayload(as: item) else {
                throw KnowledgeSyncModelError.operationPayloadConflict
            }
            return
        } else {
            items.append(item)
        }
        try write(items, for: normalizedUserId)
    }

    func replace(
        operationId: String,
        with replacement: KnowledgeGovernanceOutboxItem,
        for userId: String
    ) throws {
        let normalizedUserId = try normalizedIdentifier(userId)
        let normalizedOperationId = try normalizedIdentifier(operationId)
        try validate(replacement, expectedUserId: normalizedUserId)
        var items = try load(for: normalizedUserId)
        guard let index = items.firstIndex(where: { $0.operationId == normalizedOperationId }) else {
            throw KnowledgeSyncModelError.invalidPersistenceEnvelope
        }
        if replacement.operationId != normalizedOperationId,
           items.contains(where: { $0.operationId == replacement.operationId }) {
            throw KnowledgeSyncModelError.operationPayloadConflict
        }
        items[index] = replacement
        try write(items, for: normalizedUserId)
    }

    func remove(operationId: String, for userId: String) throws {
        let normalizedUserId = try normalizedIdentifier(userId)
        let normalizedOperationId = operationId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedOperationId.isEmpty else {
            throw KnowledgeSyncModelError.invalidPersistenceEnvelope
        }
        let remaining = try load(for: normalizedUserId).filter {
            $0.operationId != normalizedOperationId
        }
        if remaining.isEmpty {
            try removeAll(for: normalizedUserId)
        } else {
            try write(remaining, for: normalizedUserId)
        }
    }

    func removeAll(for userId: String) throws {
        let normalizedUserId = try normalizedIdentifier(userId)
        let url = fileURL(userId: normalizedUserId)
        if FileManager.default.fileExists(atPath: url.path) {
            try FileManager.default.removeItem(at: url)
        }
    }

    func count(for userId: String) throws -> Int {
        try load(for: userId).count
    }

    private func write(_ items: [KnowledgeGovernanceOutboxItem], for userId: String) throws {
        guard !items.isEmpty else {
            try removeAll(for: userId)
            return
        }
        try FileManager.default.createDirectory(
            at: rootDirectory,
            withIntermediateDirectories: true
        )
        let envelope = Envelope(
            schemaVersion: 1,
            userKey: KnowledgeRemoteBaseStore.userKey(userId),
            items: items
        )
        let data = try encoder.encode(envelope)
        try data.write(to: fileURL(userId: userId), options: .atomic)
    }

    private func validate(
        _ item: KnowledgeGovernanceOutboxItem,
        expectedUserId: String
    ) throws {
        guard item.userId.trimmingCharacters(in: .whitespacesAndNewlines) == expectedUserId,
              !item.operationId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              item.expectedIdentity.isComplete,
              item.expectedIdentity.ownerUserId == expectedUserId else {
            throw KnowledgeSyncModelError.invalidPersistenceEnvelope
        }
        do {
            _ = try item.action.backendJSONObject()
        } catch {
            throw KnowledgeSyncModelError.invalidPersistenceEnvelope
        }
    }

    private func normalizedIdentifier(_ value: String) throws -> String {
        let normalized = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else {
            throw KnowledgeSyncModelError.invalidPersistenceEnvelope
        }
        return normalized
    }

    private func fileURL(userId: String) -> URL {
        rootDirectory.appendingPathComponent(
            "kb_governance_outbox_\(KnowledgeRemoteBaseStore.userKey(userId)).json"
        )
    }

    private var encoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }

    private var decoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}

enum KnowledgeMutationV2Contract {
    static func authoritativeSnapshot(from object: [String: Any]) -> KnowledgeRemoteBaseSnapshot? {
        guard intValue(object["mutationSchemaVersion"]) == 2,
              object["mutation"] is [String: Any],
              let graph = object["graph"] as? [String: Any],
              let revision = intValue(object["revision"]), revision >= 0 else {
            return nil
        }
        return KnowledgeRemoteBaseSnapshot(revision: revision, graph: graph)
    }

    static func latestAuthoritativeSnapshot(
        fromChangeFeed object: [String: Any]
    ) -> KnowledgeRemoteBaseSnapshot? {
        guard let currentRevision = intValue(object["currentRevision"]), currentRevision >= 0,
              let changes = object["changes"] as? [[String: Any]],
              let latest = changes.max(by: {
                  (intValue($0["revision"]) ?? -1) < (intValue($1["revision"]) ?? -1)
              }),
              intValue(latest["revision"]) == currentRevision else {
            return nil
        }
        return authoritativeSnapshot(from: latest)
    }

    private static func intValue(_ value: Any?) -> Int? {
        KnowledgeRemoteBaseStore.intValue(value)
    }
}

enum KnowledgeMutationV2FallbackPolicy {
    static func shouldFallback(statusCode: Int?, detail: String) -> Bool {
        if statusCode == 404 || statusCode == 405 { return true }
        guard statusCode == 400 else { return false }
        let normalized = detail.lowercased().replacingOccurrences(of: "_", with: "")
        if normalized.contains("mutationschemaversion") { return true }
        let graphContractMissing = normalized.contains("graph") && (
            normalized.contains("required") ||
            normalized.contains("missing") ||
            normalized.contains("field required") ||
            normalized.contains("must be an object")
        )
        return graphContractMissing
    }
}

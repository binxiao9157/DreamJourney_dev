import Foundation

enum OwnerTruthFormalMemoryContractError: LocalizedError, Equatable, Sendable {
    case invalidList(String)
    case invalidDetail(String)
    case invalidQuery(String)
    case invalidRevision(String)

    var errorDescription: String? {
        switch self {
        case .invalidList(let detail):
            return "正式记忆列表合同无效：\(detail)"
        case .invalidDetail(let detail):
            return "正式记忆详情合同无效：\(detail)"
        case .invalidQuery(let detail):
            return "正式记忆筛选条件无效：\(detail)"
        case .invalidRevision(let detail):
            return "正式记忆修订合同无效：\(detail)"
        }
    }
}

enum OwnerTruthFormalMemoryVersionStatus: String, Equatable, Sendable {
    case current
    case superseded
}

struct OwnerTruthFormalMemoryVersion: Equatable, Sendable, Identifiable {
    let id: OwnerTruthRecordID
    let versionNumber: Int
    let status: OwnerTruthFormalMemoryVersionStatus
    let decision: OwnerTruthCandidateDecision
    let contentSchemaVersion: String
    let contentHash: String
    let content: [String: OwnerTruthJSONValue]
    let sourceCount: Int
    let createdAt: Date

    init(backendJSONObject object: [String: Any]) throws {
        guard let id = OwnerTruthFormalMemoryContract.recordID(object["versionId"]),
              let versionNumber = OwnerTruthFormalMemoryContract.positiveInt(object["versionNumber"]),
              let rawStatus = OwnerTruthFormalMemoryContract.requiredString(object["status"]),
              let status = OwnerTruthFormalMemoryVersionStatus(rawValue: rawStatus),
              let rawDecision = OwnerTruthFormalMemoryContract.requiredString(object["decision"]),
              let decision = OwnerTruthCandidateDecision(rawValue: rawDecision),
              decision == .accepted || decision == .corrected,
              let contentSchemaVersion = OwnerTruthFormalMemoryContract.requiredString(
                object["contentSchemaVersion"]
              ),
              let contentHash = OwnerTruthFormalMemoryContract.sha256(object["contentHash"]),
              let rawContent = object["content"] as? [String: Any],
              !rawContent.isEmpty,
              let sourceCount = OwnerTruthFormalMemoryContract.nonNegativeInt(object["sourceCount"]),
              sourceCount > 0,
              let createdAt = OwnerTruthFormalMemoryContract.date(object["createdAt"]) else {
            throw OwnerTruthFormalMemoryContractError.invalidDetail("版本字段缺失或越界")
        }
        var content: [String: OwnerTruthJSONValue] = [:]
        for (key, value) in rawContent {
            guard let parsed = OwnerTruthJSONValue(backendJSONObject: value) else {
                throw OwnerTruthFormalMemoryContractError.invalidDetail("版本内容不是有效 JSON")
            }
            content[key] = parsed
        }
        self.id = id
        self.versionNumber = versionNumber
        self.status = status
        self.decision = decision
        self.contentSchemaVersion = contentSchemaVersion
        self.contentHash = contentHash
        self.content = content
        self.sourceCount = sourceCount
        self.createdAt = createdAt
    }

    var summary: String {
        for key in ["summary", "title", "text", "claim", "label"] {
            guard case .string(let value)? = content[key] else { continue }
            let normalized = value.trimmingCharacters(in: .whitespacesAndNewlines)
            if !normalized.isEmpty { return normalized }
        }
        return "正式记忆"
    }

    var editableTextKey: String {
        for key in ["summary", "title", "text", "claim", "label"] {
            if case .string = content[key] { return key }
        }
        return "summary"
    }

    func content(replacingEditableText value: String) -> [String: OwnerTruthJSONValue] {
        var replacement = content
        replacement[editableTextKey] = .string(value)
        return replacement
    }

    func facetValues(named name: String) -> [String] {
        guard case .object(let facets)? = content["facets"],
              case .array(let values)? = facets[name] else { return [] }
        return values.compactMap { value in
            guard case .object(let object) = value,
                  case .string(let label)? = object["value"] else { return nil }
            return label
        }
    }
}

struct OwnerTruthFormalMemoryListItem: Equatable, Sendable, Identifiable {
    let id: OwnerTruthRecordID
    let memoryKind: OwnerTruthMemoryKind
    let perspective: OwnerTruthPerspectiveType
    let epistemicStatus: OwnerTruthEpistemicStatus
    let sensitivity: OwnerTruthSensitivityLevel
    let currentVersion: OwnerTruthFormalMemoryVersion

    init(backendJSONObject object: [String: Any]) throws {
        guard let id = OwnerTruthFormalMemoryContract.recordID(object["memoryId"]),
              let rawKind = OwnerTruthFormalMemoryContract.requiredString(object["memoryKind"]),
              let memoryKind = OwnerTruthMemoryKind(rawValue: rawKind),
              let rawPerspective = OwnerTruthFormalMemoryContract.requiredString(object["perspectiveType"]),
              let perspective = OwnerTruthPerspectiveType(rawValue: rawPerspective),
              let rawEpistemic = OwnerTruthFormalMemoryContract.requiredString(object["epistemicStatus"]),
              let epistemicStatus = OwnerTruthEpistemicStatus(rawValue: rawEpistemic),
              let rawSensitivity = OwnerTruthFormalMemoryContract.requiredString(object["sensitivity"]),
              let sensitivity = OwnerTruthSensitivityLevel(rawValue: rawSensitivity),
              let versionObject = object["currentVersion"] as? [String: Any] else {
            throw OwnerTruthFormalMemoryContractError.invalidList("记忆元数据缺失")
        }
        let currentVersion = try OwnerTruthFormalMemoryVersion(backendJSONObject: versionObject)
        guard currentVersion.status == .current else {
            throw OwnerTruthFormalMemoryContractError.invalidList("列表不得返回历史版本")
        }
        self.id = id
        self.memoryKind = memoryKind
        self.perspective = perspective
        self.epistemicStatus = epistemicStatus
        self.sensitivity = sensitivity
        self.currentVersion = currentVersion
    }
}

struct OwnerTruthFormalMemoryPage: Equatable, Sendable {
    static let schemaVersion = "owner-truth-formal-memory-list-v1"

    let vaultID: OwnerTruthVaultID
    let memories: [OwnerTruthFormalMemoryListItem]
    let nextCursor: String?

    init(backendJSONObject object: [String: Any], expectedVaultID: OwnerTruthVaultID) throws {
        guard OwnerTruthFormalMemoryContract.requiredString(object["schemaVersion"]) == Self.schemaVersion,
              OwnerTruthFormalMemoryContract.requiredString(object["vaultId"]) == expectedVaultID.rawValue,
              let rows = object["memories"] as? [[String: Any]] else {
            throw OwnerTruthFormalMemoryContractError.invalidList("schemaVersion、vaultId 或列表无效")
        }
        let memories = try rows.map(OwnerTruthFormalMemoryListItem.init)
        guard Set(memories.map(\.id)).count == memories.count else {
            throw OwnerTruthFormalMemoryContractError.invalidList("列表包含重复记忆")
        }
        if let rawCursor = object["nextCursor"], !(rawCursor is NSNull),
           OwnerTruthFormalMemoryContract.requiredString(rawCursor) == nil {
            throw OwnerTruthFormalMemoryContractError.invalidList("分页游标无效")
        }
        vaultID = expectedVaultID
        self.memories = memories
        nextCursor = OwnerTruthFormalMemoryContract.requiredString(object["nextCursor"])
    }
}

struct OwnerTruthFormalMemoryDetail: Equatable, Sendable {
    static let schemaVersion = "owner-truth-formal-memory-detail-v1"

    let vaultID: OwnerTruthVaultID
    let memory: OwnerTruthFormalMemoryListItem
    let historyLimit: Int
    let historyTruncated: Bool
    let versions: [OwnerTruthFormalMemoryVersion]

    init(backendJSONObject object: [String: Any], expectedVaultID: OwnerTruthVaultID) throws {
        guard OwnerTruthFormalMemoryContract.requiredString(object["schemaVersion"]) == Self.schemaVersion,
              OwnerTruthFormalMemoryContract.requiredString(object["vaultId"]) == expectedVaultID.rawValue,
              let memoryObject = object["memory"] as? [String: Any],
              let historyLimit = OwnerTruthFormalMemoryContract.nonNegativeInt(memoryObject["historyLimit"]),
              historyLimit == 3,
              let historyTruncated = memoryObject["historyTruncated"] as? Bool,
              let versionObjects = memoryObject["versions"] as? [[String: Any]],
              !versionObjects.isEmpty,
              versionObjects.count <= historyLimit + 1 else {
            throw OwnerTruthFormalMemoryContractError.invalidDetail("详情历史边界无效")
        }
        let memory = try OwnerTruthFormalMemoryListItem(backendJSONObject: memoryObject)
        let versions = try versionObjects.map(OwnerTruthFormalMemoryVersion.init)
        guard versions == versions.sorted(by: { $0.versionNumber > $1.versionNumber }),
              versions.first == memory.currentVersion,
              versions.filter({ $0.status == .current }).count == 1,
              Set(versions.map(\.id)).count == versions.count else {
            throw OwnerTruthFormalMemoryContractError.invalidDetail("版本顺序或当前指针无效")
        }
        vaultID = expectedVaultID
        self.memory = memory
        self.historyLimit = historyLimit
        self.historyTruncated = historyTruncated
        self.versions = versions
    }
}

struct OwnerTruthFormalMemoryFacetFilter: Equatable, Sendable {
    let name: String
    let value: String

    init(name: String, value: String) throws {
        let allowed = Set(["people", "time", "places", "relationships", "emotions", "values", "personality"])
        let normalizedValue = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard allowed.contains(name), !normalizedValue.isEmpty else {
            throw OwnerTruthFormalMemoryContractError.invalidQuery("线索筛选无效")
        }
        self.name = name
        self.value = normalizedValue
    }
}

struct OwnerTruthFormalMemoryQuery: Equatable, Sendable {
    let kind: OwnerTruthMemoryKind?
    let text: String?
    let facets: [OwnerTruthFormalMemoryFacetFilter]
    let cursor: String?
    let limit: Int

    init(
        kind: OwnerTruthMemoryKind? = nil,
        text: String? = nil,
        facets: [OwnerTruthFormalMemoryFacetFilter] = [],
        cursor: String? = nil,
        limit: Int = 20
    ) throws {
        let normalizedText = text?.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedCursor = cursor?.trimmingCharacters(in: .whitespacesAndNewlines)
        guard (normalizedText?.count ?? 0) <= 256, (1...100).contains(limit) else {
            throw OwnerTruthFormalMemoryContractError.invalidQuery("关键词或分页大小越界")
        }
        self.kind = kind
        self.text = normalizedText?.isEmpty == false ? normalizedText : nil
        self.facets = facets
        self.cursor = normalizedCursor?.isEmpty == false ? normalizedCursor : nil
        self.limit = limit
    }
}

struct OwnerTruthFormalMemoryRevisionCommand: Equatable, Sendable {
    let commandID: String
    let expectedVersion: Int
    let expectedContentHash: String
    let expectedContentSchemaVersion: String
    let contentSchemaVersion: String
    let correctedContent: [String: OwnerTruthJSONValue]
    let reasonCode: String

    init(
        commandID: String = UUID().uuidString.lowercased(),
        expectedVersion: Int,
        expectedContentHash: String,
        expectedContentSchemaVersion: String,
        contentSchemaVersion: String,
        correctedContent: [String: OwnerTruthJSONValue],
        secondConfirmation: Bool,
        reasonCode: String = "ownerConfirmedFormalMemoryCorrection"
    ) throws {
        guard secondConfirmation,
              !commandID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              expectedVersion > 0,
              OwnerTruthFormalMemoryContract.isSHA256(expectedContentHash),
              !expectedContentSchemaVersion.isEmpty,
              !contentSchemaVersion.isEmpty,
              !correctedContent.isEmpty,
              !reasonCode.isEmpty else {
            throw OwnerTruthFormalMemoryContractError.invalidRevision("必须二次确认且版本字段完整")
        }
        self.commandID = commandID
        self.expectedVersion = expectedVersion
        self.expectedContentHash = expectedContentHash.lowercased()
        self.expectedContentSchemaVersion = expectedContentSchemaVersion
        self.contentSchemaVersion = contentSchemaVersion
        self.correctedContent = correctedContent
        self.reasonCode = reasonCode
    }

    var backendPayload: [String: Any] {
        [
            "commandId": commandID,
            "expectedVersion": expectedVersion,
            "expectedContentHash": expectedContentHash,
            "expectedContentSchemaVersion": expectedContentSchemaVersion,
            "contentSchemaVersion": contentSchemaVersion,
            "correctedContent": correctedContent.mapValues(\.backendJSONObject),
            "secondConfirmation": true,
            "reasonCode": reasonCode,
        ]
    }
}

struct OwnerTruthFormalMemoryRevisionReceipt: Equatable, Sendable {
    let status: String
    let memoryID: OwnerTruthRecordID
    let supersededVersionID: OwnerTruthRecordID
    let replacementVersionID: OwnerTruthRecordID
    let replacementVersion: Int
    let contentHash: String

    init(
        backendJSONObject object: [String: Any],
        expectedVaultID: OwnerTruthVaultID,
        expectedMemoryID: OwnerTruthRecordID
    ) throws {
        guard OwnerTruthFormalMemoryContract.requiredString(object["vaultId"]) == expectedVaultID.rawValue,
              let revision = object["revision"] as? [String: Any],
              OwnerTruthFormalMemoryContract.requiredString(revision["schemaVersion"])
                == "owner-truth-formal-memory-correction-v1",
              let status = OwnerTruthFormalMemoryContract.requiredString(revision["status"]),
              status == "created" || status == "deduplicated",
              OwnerTruthFormalMemoryContract.recordID(revision["memoryId"]) == expectedMemoryID,
              let supersededVersionID = OwnerTruthFormalMemoryContract.recordID(
                revision["supersededVersionId"]
              ),
              let replacementVersionID = OwnerTruthFormalMemoryContract.recordID(
                revision["replacementVersionId"]
              ),
              let replacementVersion = OwnerTruthFormalMemoryContract.positiveInt(
                revision["replacementVersion"]
              ),
              let contentHash = OwnerTruthFormalMemoryContract.sha256(revision["contentHash"]) else {
            throw OwnerTruthFormalMemoryContractError.invalidRevision("修订回执无效")
        }
        self.status = status
        memoryID = expectedMemoryID
        self.supersededVersionID = supersededVersionID
        self.replacementVersionID = replacementVersionID
        self.replacementVersion = replacementVersion
        self.contentHash = contentHash
    }
}

protocol OwnerTruthFormalMemoryClient: AnyObject {
    func fetchOwnerTruthFormalMemories(
        vaultID: OwnerTruthVaultID,
        query: OwnerTruthFormalMemoryQuery,
        completion: @escaping (Result<OwnerTruthFormalMemoryPage, Error>) -> Void
    )

    func fetchOwnerTruthFormalMemory(
        vaultID: OwnerTruthVaultID,
        memoryID: OwnerTruthRecordID,
        completion: @escaping (Result<OwnerTruthFormalMemoryDetail, Error>) -> Void
    )

    func reviseOwnerTruthFormalMemory(
        vaultID: OwnerTruthVaultID,
        memoryID: OwnerTruthRecordID,
        command: OwnerTruthFormalMemoryRevisionCommand,
        completion: @escaping (Result<OwnerTruthFormalMemoryRevisionReceipt, Error>) -> Void
    )
}

private enum OwnerTruthFormalMemoryContract {
    static func requiredString(_ value: Any?) -> String? {
        guard let value = value as? String else { return nil }
        let normalized = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return normalized.isEmpty ? nil : normalized
    }

    static func recordID(_ value: Any?) -> OwnerTruthRecordID? {
        guard let raw = requiredString(value), let uuid = UUID(uuidString: raw) else { return nil }
        return OwnerTruthRecordID(rawValue: uuid)
    }

    static func nonNegativeInt(_ value: Any?) -> Int? {
        guard !(value is Bool), let value = value as? Int, value >= 0 else { return nil }
        return value
    }

    static func positiveInt(_ value: Any?) -> Int? {
        guard let value = nonNegativeInt(value), value > 0 else { return nil }
        return value
    }

    static func isSHA256(_ value: String) -> Bool {
        value.count == 64 && value.allSatisfy { $0.isHexDigit }
    }

    static func sha256(_ value: Any?) -> String? {
        guard let value = requiredString(value)?.lowercased(), isSHA256(value) else { return nil }
        return value
    }

    static func date(_ value: Any?) -> Date? {
        guard let value = requiredString(value) else { return nil }
        let fractional = ISO8601DateFormatter()
        fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return fractional.date(from: value) ?? ISO8601DateFormatter().date(from: value)
    }
}

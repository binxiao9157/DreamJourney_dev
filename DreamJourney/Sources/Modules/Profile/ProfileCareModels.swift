import Foundation

enum ProfileCareDataState {
    case available
    case loading
    case empty
    case stale
    case failed

    var title: String {
        switch self {
        case .available:
            return "关怀信号已同步"
        case .loading:
            return "正在同步关怀信号"
        case .empty:
            return "暂无可用关怀信号"
        case .stale:
            return "数据可能不是最新"
        case .failed:
            return "关怀信号加载失败"
        }
    }

    var message: String {
        switch self {
        case .available:
            return "关怀信号已同步。"
        case .loading:
            return "正在同步关怀信号，稍后会更新聚合结果。"
        case .empty:
            return "暂无可用关怀信号，后续有足够数据后会自动更新。"
        case .stale:
            return "数据可能不是最新，当前展示本地安全状态。"
        case .failed:
            return "关怀信号加载失败，请稍后重试。"
        }
    }

    var isRetryable: Bool {
        switch self {
        case .empty, .stale, .failed:
            return true
        case .available, .loading:
            return false
        }
    }

    var actionTitle: String? {
        isRetryable ? "重新同步" : nil
    }

    var accessibilityIdentifier: String {
        switch self {
        case .available:
            return "profileCareStateAvailable"
        case .loading:
            return "profileCareStateLoading"
        case .empty:
            return "profileCareStateEmpty"
        case .stale:
            return "profileCareStateStale"
        case .failed:
            return "profileCareStateFailed"
        }
    }
}

struct ProfileCareSnapshot {
    var moodTitle: String
    var moodStatus: String
    var emotionalIndex: Double
    var cognitiveIndex: Double
    var sleepStatus: String
    var lonelinessIndex: Double
    var riskReminder: String
    var isStale: Bool
    var dataState: ProfileCareDataState

    init(
        moodTitle: String,
        moodStatus: String,
        emotionalIndex: Double,
        cognitiveIndex: Double,
        sleepStatus: String,
        lonelinessIndex: Double,
        riskReminder: String,
        isStale: Bool = false,
        dataState: ProfileCareDataState = .available
    ) {
        self.moodTitle = moodTitle
        self.moodStatus = moodStatus
        self.emotionalIndex = emotionalIndex
        self.cognitiveIndex = cognitiveIndex
        self.sleepStatus = sleepStatus
        self.lonelinessIndex = lonelinessIndex
        self.riskReminder = riskReminder
        self.isStale = isStale
        self.dataState = dataState
    }

    init?(json: [String: Any]) {
        let source = ProfileCareSnapshot.payloadObject(from: json)
        guard let source else { return nil }
        let isStale = source.boolValue(for: "isStale")
            ?? source.boolValue(for: "stale")
            ?? Self.isStaleWindowEnd(source.stringValue(for: "windowEnd"))
        let dataState = Self.dataState(from: source, isStale: isStale)

        self.init(
            moodTitle: source.stringValue(for: "moodTitle") ?? "心境追踪",
            moodStatus: source.stringValue(for: "moodStatus") ?? "待同步",
            emotionalIndex: source.boundedDoubleValue(for: "emotionalIndex") ?? 0,
            cognitiveIndex: source.boundedDoubleValue(for: "cognitiveIndex") ?? 0,
            sleepStatus: source.stringValue(for: "sleepStatus") ?? "待同步",
            lonelinessIndex: source.boundedDoubleValue(for: "lonelinessIndex") ?? 0,
            riskReminder: source.stringValue(for: "riskReminder") ?? "暂无风险提醒",
            isStale: isStale,
            dataState: dataState
        )
    }

    static func loadingPlaceholder() -> ProfileCareSnapshot {
        ProfileCareSnapshot(
            moodTitle: "心境追踪",
            moodStatus: "同步中",
            emotionalIndex: 0.5,
            cognitiveIndex: 0.5,
            sleepStatus: "正在同步",
            lonelinessIndex: 0.5,
            riskReminder: ProfileCareDataState.loading.message,
            dataState: .loading
        )
    }

    static func retryingPlaceholder() -> ProfileCareSnapshot {
        ProfileCareSnapshot(
            moodTitle: "心境追踪",
            moodStatus: "重新同步中",
            emotionalIndex: 0.5,
            cognitiveIndex: 0.5,
            sleepStatus: "正在重新同步",
            lonelinessIndex: 0.5,
            riskReminder: "正在重新同步关怀信号，请稍候。",
            dataState: .loading
        )
    }

    static func emptyFallback() -> ProfileCareSnapshot {
        ProfileCareSnapshot(
            moodTitle: "心境追踪",
            moodStatus: "暂无数据",
            emotionalIndex: 0.5,
            cognitiveIndex: 0.5,
            sleepStatus: "暂无数据",
            lonelinessIndex: 0.5,
            riskReminder: ProfileCareDataState.empty.message,
            dataState: .empty
        )
    }

    static func failedFallback() -> ProfileCareSnapshot {
        ProfileCareSnapshot(
            moodTitle: "心境追踪",
            moodStatus: "加载失败",
            emotionalIndex: 0.5,
            cognitiveIndex: 0.5,
            sleepStatus: "暂不可用",
            lonelinessIndex: 0.5,
            riskReminder: ProfileCareDataState.failed.message,
            dataState: .failed
        )
    }

    static func staleFallback() -> ProfileCareSnapshot {
        ProfileCareSnapshot(
            moodTitle: "心境追踪",
            moodStatus: "待同步",
            emotionalIndex: 0.5,
            cognitiveIndex: 0.5,
            sleepStatus: "待同步",
            lonelinessIndex: 0.5,
            riskReminder: "关怀数据暂未同步，当前显示本地安全状态。",
            isStale: true,
            dataState: .stale
        )
    }

    static func offlineFallback() -> ProfileCareSnapshot {
        staleFallback()
    }

    var syncCaption: String {
        switch dataState {
        case .available:
            return riskReminder
        case .loading:
            return riskReminder
        case .empty, .failed:
            return dataState.message
        case .stale:
            return "关怀数据暂未同步，当前显示本地安全状态。"
        }
    }

    private static func payloadObject(from json: [String: Any]) -> [String: Any]? {
        if json["emotionalIndex"] != nil || json["moodStatus"] != nil {
            return json
        }
        if let item = json["item"] as? [String: Any] {
            return payloadObject(from: item)
        }
        if let data = json["data"] as? [String: Any] {
            return payloadObject(from: data)
        }
        if let snapshot = json["snapshot"] as? [String: Any] {
            return payloadObject(from: snapshot)
        }
        if let aggregate = aggregatePayloadObject(from: json) {
            return aggregate
        }
        return nil
    }

    private static func aggregatePayloadObject(from source: [String: Any]) -> [String: Any]? {
        guard source["riskLevel"] != nil || source["summary"] != nil || source["dailyTrend"] != nil else {
            return nil
        }

        let latestTrend = (source["dailyTrend"] as? [[String: Any]])?.first
        let riskLevel = source.stringValue(for: "riskLevel") ?? "insufficientData"
        let signalScore = latestTrend?.boundedDoubleValue(for: "signalScore")
            ?? source.boundedDoubleValue(for: "signalScore")
            ?? defaultSignalScore(for: riskLevel)
        let repetitionRatio = source.boundedDoubleValue(for: "repetitionRatio")
            ?? latestTrend?.boundedDoubleValue(for: "repetitionRatio")
            ?? 0
        let sleepMentions = source.integerValue(for: "sleepMentions")
            ?? latestTrend?.integerValue(for: "sleepMentions")
            ?? 0

        return [
            "moodTitle": "心境追踪",
            "moodStatus": statusText(for: riskLevel),
            "emotionalIndex": signalScore,
            "cognitiveIndex": 1 - repetitionRatio,
            "sleepStatus": sleepStatusText(mentions: sleepMentions),
            "lonelinessIndex": source.boundedDoubleValue(for: "lonelinessIndex") ?? 0,
            "riskReminder": firstString(in: source["suggestions"])
                ?? source.stringValue(for: "trendSummary")
                ?? source.stringValue(for: "summary")
                ?? "关怀数据已同步。",
            "windowEnd": source.stringValue(for: "windowEnd") ?? "",
            "dataState": source.stringValue(for: "dataState") ?? "",
            "isStale": source.boolValue(for: "isStale")
                ?? source.boolValue(for: "stale")
                ?? isStaleWindowEnd(source.stringValue(for: "windowEnd")),
        ]
    }

    private static func dataState(from source: [String: Any], isStale: Bool) -> ProfileCareDataState {
        if let rawState = source.stringValue(for: "dataState")?.lowercased() {
            switch rawState {
            case "available", "active", "synced":
                return isStale ? .stale : .available
            case "loading", "pending":
                return .loading
            case "empty", "none", "insufficientdata", "insufficient_data":
                return .empty
            case "stale", "expired":
                return .stale
            case "failed", "error":
                return .failed
            default:
                break
            }
        }

        let riskLevel = source.stringValue(for: "riskLevel")?
            .replacingOccurrences(of: "_", with: "")
            .replacingOccurrences(of: "-", with: "")
            .lowercased()
        if riskLevel == "insufficientdata" || riskLevel == "empty" {
            return .empty
        }
        return isStale ? .stale : .available
    }

    private static func isStaleWindowEnd(_ windowEnd: String?) -> Bool {
        guard let windowEnd,
              let date = ISO8601DateFormatter().date(from: windowEnd) else {
            return false
        }
        return date < Date().addingTimeInterval(-36 * 60 * 60)
    }

    private static func statusText(for riskLevel: String) -> String {
        switch riskLevel.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "stable":
            return "平稳"
        case "watch":
            return "需关注"
        case "attention":
            return "重点关注"
        default:
            return "待同步"
        }
    }

    private static func defaultSignalScore(for riskLevel: String) -> Double {
        switch riskLevel.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "stable":
            return 0.82
        case "watch":
            return 0.62
        case "attention":
            return 0.38
        default:
            return 0.5
        }
    }

    private static func sleepStatusText(mentions: Int) -> String {
        mentions > 0 ? "睡眠线索 \(mentions) 条" : "睡眠平稳"
    }

    private static func firstString(in value: Any?) -> String? {
        guard let values = value as? [Any] else { return nil }
        return values.compactMap { item -> String? in
            guard let string = item as? String else { return nil }
            let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? nil : trimmed
        }.first
    }
}

struct ProfileCareCachedSignal: Codable {
    let id: String
    let title: String
    let summary: String
    let status: String
    let severity: String
    let updatedAt: String
    let ownerUserId: String
}

final class ProfileCareSignalMessageStore {
    static let shared = ProfileCareSignalMessageStore()

    private let baseKey = "dj.profileCare.inAppMessageSignal"
    private let isoFormatter = ISO8601DateFormatter()

    private init() {}

    func save(snapshot: ProfileCareSnapshot, userId: String) {
        let signal = ProfileCareCachedSignal(
            id: userId,
            title: title(for: snapshot),
            summary: snapshot.syncCaption,
            status: snapshot.dataState.accessibilityIdentifier,
            severity: severity(for: snapshot),
            updatedAt: isoFormatter.string(from: Date()),
            ownerUserId: userId
        )
        guard let data = try? JSONEncoder().encode(signal) else {
            return
        }
        UserDefaults.standard.set(data, forKey: storageKey(userId: userId))
    }

    func cachedSignal(userId: String?) -> ProfileCareCachedSignal? {
        guard let userId = userId?.trimmingCharacters(in: .whitespacesAndNewlines),
              !userId.isEmpty,
              let data = UserDefaults.standard.data(forKey: storageKey(userId: userId)) else {
            return nil
        }
        return try? JSONDecoder().decode(ProfileCareCachedSignal.self, from: data)
    }

    private func storageKey(userId: String) -> String {
        "\(baseKey).\(userId)"
    }

    private func title(for snapshot: ProfileCareSnapshot) -> String {
        switch snapshot.dataState {
        case .failed:
            return "关怀信号加载失败"
        case .stale:
            return "关怀信号可能过期"
        case .available where snapshot.moodStatus.contains("关注"):
            return "心境状态需要关注"
        default:
            return "关怀提醒"
        }
    }

    private func severity(for snapshot: ProfileCareSnapshot) -> String {
        switch snapshot.dataState {
        case .failed:
            return "failed"
        case .stale:
            return "stale"
        case .available where snapshot.moodStatus.contains("重点关注"):
            return "attention"
        case .available where snapshot.moodStatus.contains("需关注") || snapshot.moodStatus.contains("关注"):
            return "needsAttention"
        default:
            return "normal"
        }
    }
}

struct ProfileCareMetric {
    let title: String
    let value: Double
    let status: String

    var boundedValue: Double {
        min(max(value, 0), 1)
    }
}

struct ProfileCareEscalationDraft {
    let personaDisplayName: String
    let riskSummary: String
    let nonEmergencyNotice: String
    let medicalBoundary: String
    let contractState: String

    static func make(snapshot: ProfileCareSnapshot, personaDisplayName: String) -> ProfileCareEscalationDraft {
        let displayName = personaDisplayName.trimmingCharacters(in: .whitespacesAndNewlines)
        let personaDisplayName = displayName.isEmpty ? "当前回响对象" : displayName
        let status = snapshot.moodStatus.trimmingCharacters(in: .whitespacesAndNewlines)
        let reminder = snapshot.riskReminder.trimmingCharacters(in: .whitespacesAndNewlines)
        let riskSummary: String
        if snapshot.isStale {
            riskSummary = "关怀数据暂未同步，当前只能生成本地安全草稿。"
        } else if !status.isEmpty, !reminder.isEmpty {
            riskSummary = "\(status)：\(reminder)"
        } else if !reminder.isEmpty {
            riskSummary = reminder
        } else if !status.isEmpty {
            riskSummary = status
        } else {
            riskSummary = "暂无明确风险提醒。"
        }

        return ProfileCareEscalationDraft(
            personaDisplayName: personaDisplayName,
            riskSummary: riskSummary,
            nonEmergencyNotice: "非紧急关怀草稿，仅用于家属或后续关怀服务接入前的人工确认。",
            medicalBoundary: "不是医疗诊断，不能替代心理医生、精神科医生或急救服务。",
            contractState: "真实联系契约未接入，当前不会拨打电话、发送消息或上传给第三方。"
        )
    }

    var alertMessage: String {
        """
        关怀升级草稿
        对象：\(personaDisplayName)
        状态摘要：\(riskSummary)

        \(nonEmergencyNotice)
        \(medicalBoundary)
        \(contractState)
        """
    }

    func backendCandidatePayload(viewerUserId: String, personaOwnerId: String) -> [String: Any] {
        [
            "schemaVersion": "profileCareEscalationDraft.v1",
            "deliveryState": "draftOnly",
            "viewerUserId": viewerUserId,
            "personaOwnerId": personaOwnerId,
            "personaDisplayName": personaDisplayName,
            "riskSummary": riskSummary,
            "nonEmergencyNotice": nonEmergencyNotice,
            "medicalBoundary": medicalBoundary,
            "contractState": contractState,
            "requiresHumanReview": true,
            "backendContractConnected": false,
            "willContactThirdParty": false,
            "allowsEmergencyUse": false,
            "containsRawTranscript": false,
        ]
    }
}

enum ProfileCareCopy {
    static func signalPercent(_ value: Double) -> String {
        "\(Int((min(max(value, 0), 1) * 100).rounded()))%"
    }
}

private extension Dictionary where Key == String, Value == Any {
    func stringValue(for key: String) -> String? {
        guard let value = self[key] else { return nil }
        if let string = value as? String {
            let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? nil : trimmed
        }
        if let number = value as? NSNumber {
            return number.stringValue
        }
        return nil
    }

    func boundedDoubleValue(for key: String) -> Double? {
        guard let value = self[key] else { return nil }
        let doubleValue: Double?
        if let double = value as? Double {
            doubleValue = double
        } else if let int = value as? Int {
            doubleValue = Double(int)
        } else if let number = value as? NSNumber {
            doubleValue = number.doubleValue
        } else if let string = value as? String {
            doubleValue = Double(string.trimmingCharacters(in: .whitespacesAndNewlines))
        } else {
            doubleValue = nil
        }
        guard let doubleValue else { return nil }
        return Swift.min(Swift.max(doubleValue, 0), 1)
    }

    func boolValue(for key: String) -> Bool? {
        guard let value = self[key] else { return nil }
        if let bool = value as? Bool {
            return bool
        }
        if let number = value as? NSNumber {
            return number.boolValue
        }
        if let string = value as? String {
            switch string.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
            case "true", "1", "yes", "y":
                return true
            case "false", "0", "no", "n":
                return false
            default:
                return nil
            }
        }
        return nil
    }

    func integerValue(for key: String) -> Int? {
        guard let value = self[key] else { return nil }
        if let int = value as? Int {
            return int
        }
        if let number = value as? NSNumber {
            return number.intValue
        }
        if let string = value as? String {
            return Int(string.trimmingCharacters(in: .whitespacesAndNewlines))
        }
        return nil
    }
}

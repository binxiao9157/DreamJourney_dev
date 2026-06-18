import Foundation

struct ProfileCareSnapshot {
    var moodTitle: String
    var moodStatus: String
    var emotionalIndex: Double
    var cognitiveIndex: Double
    var sleepStatus: String
    var lonelinessIndex: Double
    var riskReminder: String
    var isStale: Bool

    init(
        moodTitle: String,
        moodStatus: String,
        emotionalIndex: Double,
        cognitiveIndex: Double,
        sleepStatus: String,
        lonelinessIndex: Double,
        riskReminder: String,
        isStale: Bool = false
    ) {
        self.moodTitle = moodTitle
        self.moodStatus = moodStatus
        self.emotionalIndex = emotionalIndex
        self.cognitiveIndex = cognitiveIndex
        self.sleepStatus = sleepStatus
        self.lonelinessIndex = lonelinessIndex
        self.riskReminder = riskReminder
        self.isStale = isStale
    }

    init?(json: [String: Any]) {
        let source = ProfileCareSnapshot.payloadObject(from: json)
        guard let source else { return nil }

        self.init(
            moodTitle: source.stringValue(for: "moodTitle") ?? "心境追踪",
            moodStatus: source.stringValue(for: "moodStatus") ?? "待同步",
            emotionalIndex: source.boundedDoubleValue(for: "emotionalIndex") ?? 0,
            cognitiveIndex: source.boundedDoubleValue(for: "cognitiveIndex") ?? 0,
            sleepStatus: source.stringValue(for: "sleepStatus") ?? "待同步",
            lonelinessIndex: source.boundedDoubleValue(for: "lonelinessIndex") ?? 0,
            riskReminder: source.stringValue(for: "riskReminder") ?? "暂无风险提醒"
        )
    }

    static func offlineFallback() -> ProfileCareSnapshot {
        ProfileCareSnapshot(
            moodTitle: "心境追踪",
            moodStatus: "待同步",
            emotionalIndex: 0.5,
            cognitiveIndex: 0.5,
            sleepStatus: "待同步",
            lonelinessIndex: 0.5,
            riskReminder: "关怀数据暂未同步，当前显示本地安全状态。",
            isStale: true
        )
    }

    var syncCaption: String {
        if isStale {
            return "关怀数据暂未同步，当前显示本地安全状态。"
        }
        return riskReminder
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
        ]
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

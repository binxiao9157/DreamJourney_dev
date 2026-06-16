import Foundation

struct ProfileCareSnapshot {
    var moodTitle: String
    var moodStatus: String
    var emotionalIndex: Double
    var cognitiveIndex: Double
    var sleepStatus: String
    var lonelinessIndex: Double
    var riskReminder: String

    init(
        moodTitle: String,
        moodStatus: String,
        emotionalIndex: Double,
        cognitiveIndex: Double,
        sleepStatus: String,
        lonelinessIndex: Double,
        riskReminder: String
    ) {
        self.moodTitle = moodTitle
        self.moodStatus = moodStatus
        self.emotionalIndex = emotionalIndex
        self.cognitiveIndex = cognitiveIndex
        self.sleepStatus = sleepStatus
        self.lonelinessIndex = lonelinessIndex
        self.riskReminder = riskReminder
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

    private static func payloadObject(from json: [String: Any]) -> [String: Any]? {
        if json["emotionalIndex"] != nil || json["moodStatus"] != nil {
            return json
        }
        if let data = json["data"] as? [String: Any] {
            return payloadObject(from: data)
        }
        if let snapshot = json["snapshot"] as? [String: Any] {
            return payloadObject(from: snapshot)
        }
        return nil
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
}

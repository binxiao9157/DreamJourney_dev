import Foundation

struct ProfileCareSnapshot {
    var moodTitle: String
    var moodStatus: String
    var emotionalIndex: Double
    var cognitiveIndex: Double
    var sleepStatus: String
    var lonelinessIndex: Double
    var riskReminder: String
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

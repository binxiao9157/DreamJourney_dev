import Foundation

struct CareSignalInputTurn: Codable, Equatable {
    let role: String
    let text: String
    let timestamp: Date
    let speechDurationSeconds: Double?
    let pauseCount: Int?
    let emotionHint: String?

    init(
        role: String,
        text: String,
        timestamp: Date,
        speechDurationSeconds: Double? = nil,
        pauseCount: Int? = nil,
        emotionHint: String? = nil
    ) {
        self.role = role
        self.text = text
        self.timestamp = timestamp
        self.speechDurationSeconds = speechDurationSeconds
        self.pauseCount = pauseCount
        self.emotionHint = emotionHint
    }
}

enum CareSignalRiskLevel: String, Codable, Equatable {
    case insufficientData
    case stable
    case watch
    case attention
}

struct CareSignalSnapshot: Codable, Equatable {
    let generatedAt: Date
    let windowStart: Date?
    let windowEnd: Date?
    let windowDayCount: Int
    let dataCoverageSummary: String
    let totalTurns: Int
    let userTurnCount: Int
    let characterCount: Int
    let uniqueTokenCount: Int
    let lexicalDiversity: Double
    let negativeEmotionMentions: Int
    let sleepMentions: Int
    let bodyDiscomfortMentions: Int
    let repetitionRatio: Double
    let averageWordsPerMinute: Double?
    let slowSpeechTurnCount: Int?
    let longPauseTurnCount: Int?
    let emotionVolatilityScore: Double?
    let riskLevel: CareSignalRiskLevel
    let summary: String
    let suggestions: [String]
    let weeklyHighlights: [String]
    let riskSignalDescriptions: [String]
    let dailyTrend: [CareSignalDailyTrendPoint]
    let trendSummary: String

    init(
        generatedAt: Date,
        windowStart: Date?,
        windowEnd: Date?,
        windowDayCount: Int,
        dataCoverageSummary: String,
        totalTurns: Int,
        userTurnCount: Int,
        characterCount: Int,
        uniqueTokenCount: Int,
        lexicalDiversity: Double,
        negativeEmotionMentions: Int,
        sleepMentions: Int,
        bodyDiscomfortMentions: Int,
        repetitionRatio: Double,
        averageWordsPerMinute: Double? = nil,
        slowSpeechTurnCount: Int? = nil,
        longPauseTurnCount: Int? = nil,
        emotionVolatilityScore: Double? = nil,
        riskLevel: CareSignalRiskLevel,
        summary: String,
        suggestions: [String],
        weeklyHighlights: [String],
        riskSignalDescriptions: [String],
        dailyTrend: [CareSignalDailyTrendPoint],
        trendSummary: String
    ) {
        self.generatedAt = generatedAt
        self.windowStart = windowStart
        self.windowEnd = windowEnd
        self.windowDayCount = windowDayCount
        self.dataCoverageSummary = dataCoverageSummary
        self.totalTurns = totalTurns
        self.userTurnCount = userTurnCount
        self.characterCount = characterCount
        self.uniqueTokenCount = uniqueTokenCount
        self.lexicalDiversity = lexicalDiversity
        self.negativeEmotionMentions = negativeEmotionMentions
        self.sleepMentions = sleepMentions
        self.bodyDiscomfortMentions = bodyDiscomfortMentions
        self.repetitionRatio = repetitionRatio
        self.averageWordsPerMinute = averageWordsPerMinute
        self.slowSpeechTurnCount = slowSpeechTurnCount
        self.longPauseTurnCount = longPauseTurnCount
        self.emotionVolatilityScore = emotionVolatilityScore
        self.riskLevel = riskLevel
        self.summary = summary
        self.suggestions = suggestions
        self.weeklyHighlights = weeklyHighlights
        self.riskSignalDescriptions = riskSignalDescriptions
        self.dailyTrend = dailyTrend
        self.trendSummary = trendSummary
    }
}

struct CareSignalDailyTrendPoint: Codable, Equatable {
    let date: Date
    let userTurnCount: Int
    let negativeEmotionMentions: Int
    let sleepMentions: Int
    let bodyDiscomfortMentions: Int
    let repetitionRatio: Double
    let averageWordsPerMinute: Double?
    let slowSpeechTurnCount: Int?
    let longPauseTurnCount: Int?
    let emotionVolatilityScore: Double?
    let signalScore: Int

    init(
        date: Date,
        userTurnCount: Int,
        negativeEmotionMentions: Int,
        sleepMentions: Int,
        bodyDiscomfortMentions: Int,
        repetitionRatio: Double,
        averageWordsPerMinute: Double? = nil,
        slowSpeechTurnCount: Int? = nil,
        longPauseTurnCount: Int? = nil,
        emotionVolatilityScore: Double? = nil,
        signalScore: Int
    ) {
        self.date = date
        self.userTurnCount = userTurnCount
        self.negativeEmotionMentions = negativeEmotionMentions
        self.sleepMentions = sleepMentions
        self.bodyDiscomfortMentions = bodyDiscomfortMentions
        self.repetitionRatio = repetitionRatio
        self.averageWordsPerMinute = averageWordsPerMinute
        self.slowSpeechTurnCount = slowSpeechTurnCount
        self.longPauseTurnCount = longPauseTurnCount
        self.emotionVolatilityScore = emotionVolatilityScore
        self.signalScore = signalScore
    }

    var hasSignals: Bool {
        signalScore > 0 ||
            repetitionRatio >= 0.4 ||
            (slowSpeechTurnCount ?? 0) > 0 ||
            (longPauseTurnCount ?? 0) > 0 ||
            (emotionVolatilityScore ?? 0) >= 0.5
    }
}

struct CareDashboardShareReportDescriptor: Equatable {
    let title: String
    let riskTitle: String
    let generatedAtText: String
    let observationWindowText: String
    let coverageText: String
    let metricLines: [String]
    let summary: String
    let highlights: [String]
    let trendSummary: String
    let suggestions: [String]
    let boundaryNotice: String

    var plainText: String {
        var lines: [String] = [
            title,
            "风险等级：\(riskTitle)",
            "生成时间：\(generatedAtText)",
            "观测窗口：\(observationWindowText)",
            "数据覆盖：\(coverageText)",
            "",
            "脱敏指标"
        ]
        lines.append(contentsOf: metricLines.map { "- \($0)" })
        lines.append(contentsOf: ["", "观察摘要", summary])

        if !highlights.isEmpty {
            lines.append(contentsOf: ["", "需关注信号"])
            lines.append(contentsOf: highlights.map { "- \($0)" })
        }

        lines.append(contentsOf: ["", "趋势观察", Self.snapshotTrendLine(from: trendSummary, fallback: "暂无足够趋势数据。")])

        lines.append(contentsOf: ["", "关怀建议"])
        lines.append(contentsOf: suggestions.map { "- \($0)" })
        lines.append(contentsOf: ["", boundaryNotice])
        return lines.joined(separator: "\n")
    }

    static func make(
        snapshot: CareSignalSnapshot,
        viewerName: String? = nil,
        calendar: Calendar = .current
    ) -> CareDashboardShareReportDescriptor {
        let trimmedName = viewerName?.trimmingCharacters(in: .whitespacesAndNewlines)
        let target = (trimmedName?.isEmpty == false) ? "\(trimmedName!)的" : ""
        let highlights = snapshot.riskSignalDescriptions.isEmpty ? snapshot.weeklyHighlights : snapshot.riskSignalDescriptions
        return CareDashboardShareReportDescriptor(
            title: "\(target)家庭安心报（脱敏周报）",
            riskTitle: snapshot.riskLevel.reportTitle,
            generatedAtText: Self.dateTimeFormatter.string(from: snapshot.generatedAt),
            observationWindowText: observationWindowText(snapshot: snapshot),
            coverageText: snapshot.dataCoverageSummary,
            metricLines: Self.metricLines(snapshot: snapshot),
            summary: snapshot.summary,
            highlights: highlights,
            trendSummary: snapshot.trendSummary,
            suggestions: snapshot.suggestions,
            boundaryNotice: "仅包含脱敏聚合信号和关怀建议，不包含原始聊天内容；本周报不是医疗诊断。"
        )
    }

    private static func metricLines(snapshot: CareSignalSnapshot) -> [String] {
        var lines = [
            "用户发言 \(snapshot.userTurnCount) 轮",
            "观测天数 \(snapshot.windowDayCount) 天",
            "情绪信号 \(snapshot.negativeEmotionMentions)",
            "睡眠信号 \(snapshot.sleepMentions)",
            "身体信号 \(snapshot.bodyDiscomfortMentions)",
            "重复表达 \(Self.percent(snapshot.repetitionRatio))"
        ]
        if let rate = snapshot.averageWordsPerMinute {
            lines.append("平均语速 \(Int(rate.rounded()))字/分")
        }
        if let slowCount = snapshot.slowSpeechTurnCount {
            lines.append("慢语速轮次 \(slowCount)")
        }
        if let pauseCount = snapshot.longPauseTurnCount {
            lines.append("长停顿轮次 \(pauseCount)")
        }
        if let volatility = snapshot.emotionVolatilityScore {
            lines.append("情绪波动 \(Self.percent(volatility))")
        }
        return lines
    }

    private static func snapshotTrendLine(from value: String, fallback: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? fallback : trimmed
    }

    private static func observationWindowText(snapshot: CareSignalSnapshot) -> String {
        guard let start = snapshot.windowStart, let end = snapshot.windowEnd else {
            return "暂无足够数据"
        }
        return "\(dateFormatter.string(from: start))-\(dateFormatter.string(from: end))"
    }

    private static func percent(_ value: Double) -> String {
        "\(Int((value * 100).rounded()))%"
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "MM/dd"
        return formatter
    }()

    private static let dateTimeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        return formatter
    }()
}

struct CareDashboardReportReadiness: Equatable {
    let isReady: Bool
    let message: String

    static let ready = CareDashboardReportReadiness(
        isReady: true,
        message: "家庭安心报已达到最低真实数据覆盖。"
    )
}

enum CareDashboardReportReadinessPolicy {
    static let minimumUserTurns = 3
    static let minimumActiveDays = 2

    static func evaluate(snapshot: CareSignalSnapshot) -> CareDashboardReportReadiness {
        guard snapshot.riskLevel != .insufficientData, snapshot.userTurnCount > 0 else {
            return CareDashboardReportReadiness(
                isReady: false,
                message: "暂无真实亲友范围对话，先完成一次授权对话。"
            )
        }

        let missingTurns = max(0, minimumUserTurns - snapshot.userTurnCount)
        let activeDays = snapshot.dailyTrend.count
        let missingDays = max(0, minimumActiveDays - activeDays)
        guard missingTurns == 0, missingDays == 0 else {
            var parts: [String] = []
            if missingTurns > 0 {
                parts.append("还需 \(missingTurns) 轮亲友范围发言")
            }
            if missingDays > 0 {
                parts.append("还需 \(missingDays) 天有效记录")
            }
            return CareDashboardReportReadiness(
                isReady: false,
                message: parts.joined(separator: "，")
            )
        }
        return .ready
    }
}

private extension CareSignalRiskLevel {
    var reportTitle: String {
        switch self {
        case .insufficientData: return "数据不足"
        case .stable: return "状态稳定"
        case .watch: return "建议关注"
        case .attention: return "需要尽快确认"
        }
    }
}

enum CareDashboardInputPolicy {
    static func eligibleInputTurns(
        from turns: [ConversationTurn],
        viewerFamilyMemberID: String? = nil
    ) -> [CareSignalInputTurn] {
        PrivacyScopePolicy.sanitized(
            items: turns,
            surface: .careDashboard,
            familyMemberID: viewerFamilyMemberID
        )
        .filter(isCareEligibleTurn)
        .map {
            CareSignalInputTurn(
                role: $0.role,
                text: $0.text,
                timestamp: $0.timestamp,
                speechDurationSeconds: $0.speechDurationSeconds,
                pauseCount: $0.pauseCount,
                emotionHint: $0.emotionHint
            )
        }
    }

    private static func isCareEligibleTurn(_ turn: ConversationTurn) -> Bool {
        guard turn.role.lowercased() == "user" else { return true }
        let excludedPrefixes = [
            "时空信箱写给",
            "记忆档案馆保存",
            "记忆档案馆上传旧照片"
        ]
        return !excludedPrefixes.contains { turn.text.hasPrefix($0) }
    }
}

enum CareDashboardSnapshotSelectionPolicy {
    static func shouldPreferRemote(current: CareSignalSnapshot?, remote: CareSignalSnapshot) -> Bool {
        guard remote.userTurnCount > 0 else {
            return false
        }
        guard let current else {
            return true
        }
        if current.userTurnCount <= 0 {
            return true
        }
        if current.riskLevel == .insufficientData, remote.riskLevel != .insufficientData {
            return true
        }
        if remote.windowDayCount > current.windowDayCount,
           remote.userTurnCount >= current.userTurnCount {
            return true
        }
        if remote.userTurnCount > current.userTurnCount,
           remote.windowDayCount >= current.windowDayCount {
            return true
        }
        return false
    }
}

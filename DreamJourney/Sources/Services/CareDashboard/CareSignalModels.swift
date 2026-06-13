import Foundation

struct CareSignalInputTurn: Codable, Equatable {
    let role: String
    let text: String
    let timestamp: Date
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
    let riskLevel: CareSignalRiskLevel
    let summary: String
    let suggestions: [String]
    let weeklyHighlights: [String]
    let riskSignalDescriptions: [String]
    let dailyTrend: [CareSignalDailyTrendPoint]
    let trendSummary: String
}

struct CareSignalDailyTrendPoint: Codable, Equatable {
    let date: Date
    let userTurnCount: Int
    let negativeEmotionMentions: Int
    let sleepMentions: Int
    let bodyDiscomfortMentions: Int
    let repetitionRatio: Double
    let signalScore: Int

    var hasSignals: Bool {
        signalScore > 0 || repetitionRatio >= 0.4
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
            title: "\(target)脱敏关怀周报",
            riskTitle: snapshot.riskLevel.reportTitle,
            generatedAtText: Self.dateTimeFormatter.string(from: snapshot.generatedAt),
            observationWindowText: observationWindowText(snapshot: snapshot),
            coverageText: snapshot.dataCoverageSummary,
            metricLines: [
                "用户发言 \(snapshot.userTurnCount) 轮",
                "观测天数 \(snapshot.windowDayCount) 天",
                "情绪信号 \(snapshot.negativeEmotionMentions)",
                "睡眠信号 \(snapshot.sleepMentions)",
                "身体信号 \(snapshot.bodyDiscomfortMentions)",
                "重复表达 \(Self.percent(snapshot.repetitionRatio))"
            ],
            summary: snapshot.summary,
            highlights: highlights,
            trendSummary: snapshot.trendSummary,
            suggestions: snapshot.suggestions,
            boundaryNotice: "仅包含脱敏聚合信号和关怀建议，不包含原始聊天内容；本周报不是医疗诊断。"
        )
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
            CareSignalInputTurn(role: $0.role, text: $0.text, timestamp: $0.timestamp)
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

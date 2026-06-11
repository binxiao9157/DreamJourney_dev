import Foundation

final class CareSignalAnalyzer {

    private let negativeKeywords = ["孤单", "难过", "烦", "没意思", "没人", "太痛苦", "撑不住"]
    private let sleepKeywords = ["睡不着", "失眠", "早醒", "做噩梦", "睡不好"]
    private let bodyKeywords = ["头晕", "胸闷", "疼", "胃口差", "吃不下", "摔倒", "不舒服"]

    private let ignoredScalars: CharacterSet = {
        var set = CharacterSet.whitespacesAndNewlines
        set.insert(charactersIn: "，。！？；：、“”‘’（）()【】[]《》<>「」『』,.!?;:\"'`~@#$%^&*_-+=/\\|")
        return set
    }()

    func analyze(turns: [CareSignalInputTurn], now: Date = Date()) -> CareSignalSnapshot {
        let userTurns = turns
            .filter { $0.role.lowercased() == "user" }
            .map {
                CareSignalInputTurn(
                    role: $0.role,
                    text: $0.text.trimmingCharacters(in: .whitespacesAndNewlines),
                    timestamp: $0.timestamp
                )
            }
            .filter { !$0.text.isEmpty }
        let window = observationWindow(for: userTurns)
        let userTexts = userTurns.map(\.text)

        guard !userTexts.isEmpty else {
            return CareSignalSnapshot(
                generatedAt: now,
                windowStart: window.start,
                windowEnd: window.end,
                windowDayCount: window.dayCount,
                dataCoverageSummary: dataCoverageSummary(dayCount: window.dayCount, userTurnCount: 0),
                totalTurns: turns.count,
                userTurnCount: 0,
                characterCount: 0,
                uniqueTokenCount: 0,
                lexicalDiversity: 0,
                negativeEmotionMentions: 0,
                sleepMentions: 0,
                bodyDiscomfortMentions: 0,
                repetitionRatio: 0,
                riskLevel: .insufficientData,
                summary: "暂无足够对话数据生成关怀信号。",
                suggestions: ["先通过电话或日常对话积累真实近况，再观察趋势。"],
                weeklyHighlights: [],
                riskSignalDescriptions: []
            )
        }

        let normalizedTexts = userTexts.map(normalize)
        let allText = normalizedTexts.joined(separator: "")
        let tokens = tokenize(allText)
        let uniqueTokenCount = Set(tokens).count
        let characterCount = tokens.count
        let lexicalDiversity = characterCount == 0 ? 0 : Double(uniqueTokenCount) / Double(characterCount)
        let negativeCount = countMatches(in: allText, keywords: negativeKeywords)
        let sleepCount = countMatches(in: allText, keywords: sleepKeywords)
        let bodyCount = countMatches(in: allText, keywords: bodyKeywords)
        let repetitionRatio = repeatedRatio(for: normalizedTexts)
        let riskLevel = classify(
            negativeCount: negativeCount,
            sleepCount: sleepCount,
            bodyCount: bodyCount,
            repetitionRatio: repetitionRatio
        )

        return CareSignalSnapshot(
            generatedAt: now,
            windowStart: window.start,
            windowEnd: window.end,
            windowDayCount: window.dayCount,
            dataCoverageSummary: dataCoverageSummary(dayCount: window.dayCount, userTurnCount: userTexts.count),
            totalTurns: turns.count,
            userTurnCount: userTexts.count,
            characterCount: characterCount,
            uniqueTokenCount: uniqueTokenCount,
            lexicalDiversity: lexicalDiversity,
            negativeEmotionMentions: negativeCount,
            sleepMentions: sleepCount,
            bodyDiscomfortMentions: bodyCount,
            repetitionRatio: repetitionRatio,
            riskLevel: riskLevel,
            summary: summary(for: riskLevel, userTurnCount: userTexts.count),
            suggestions: suggestions(for: riskLevel),
            weeklyHighlights: weeklyHighlights(
                riskLevel: riskLevel,
                negativeCount: negativeCount,
                sleepCount: sleepCount,
                bodyCount: bodyCount,
                repetitionRatio: repetitionRatio
            ),
            riskSignalDescriptions: riskSignalDescriptions(
                negativeCount: negativeCount,
                sleepCount: sleepCount,
                bodyCount: bodyCount,
                repetitionRatio: repetitionRatio
            )
        )
    }

    private func observationWindow(for turns: [CareSignalInputTurn]) -> (start: Date?, end: Date?, dayCount: Int) {
        let timestamps = turns.map(\.timestamp)
        guard let start = timestamps.min(), let end = timestamps.max() else {
            return (nil, nil, 0)
        }

        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: start)
        let endOfDay = calendar.startOfDay(for: end)
        let dayDelta = calendar.dateComponents([.day], from: startOfDay, to: endOfDay).day ?? 0
        return (start, end, max(1, dayDelta + 1))
    }

    private func dataCoverageSummary(dayCount: Int, userTurnCount: Int) -> String {
        "近 \(dayCount) 天，用户发言 \(userTurnCount) 轮。"
    }

    private func classify(
        negativeCount: Int,
        sleepCount: Int,
        bodyCount: Int,
        repetitionRatio: Double
    ) -> CareSignalRiskLevel {
        let signalClasses = [negativeCount > 0, sleepCount > 0, bodyCount > 0].filter { $0 }.count
        let totalSignalMentions = negativeCount + sleepCount + bodyCount
        if (signalClasses >= 2 && totalSignalMentions >= 3) || repetitionRatio >= 0.4 || bodyCount >= 2 {
            return .attention
        }
        if signalClasses >= 1 {
            return .watch
        }
        return .stable
    }

    private func summary(for level: CareSignalRiskLevel, userTurnCount: Int) -> String {
        switch level {
        case .insufficientData:
            return "暂无足够真实对话数据生成关怀信号。"
        case .stable:
            return "最近 \(userTurnCount) 轮发言暂未出现明显异常关怀信号。"
        case .watch:
            return "最近对话出现个别睡眠、情绪或身体信号，建议增加日常问候。"
        case .attention:
            return "最近对话同时出现多类关怀信号，建议家人尽快主动联系并线下确认。"
        }
    }

    private func suggestions(for level: CareSignalRiskLevel) -> [String] {
        switch level {
        case .insufficientData:
            return ["先通过一次日常问候了解近况，不要把空数据解读为状态稳定。"]
        case .stable:
            return ["保持稳定问候频率，继续鼓励长辈讲述日常和回忆。"]
        case .watch:
            return ["主动打一次电话，优先询问睡眠、饮食和当天心情。", "后续几天观察同类表达是否持续出现。"]
        case .attention:
            return ["尽快由家人电话或线下探望确认近况。", "如果身体不适或痛苦表达持续，请协助联系社区医生或专业支持。"]
        }
    }

    private func weeklyHighlights(
        riskLevel: CareSignalRiskLevel,
        negativeCount: Int,
        sleepCount: Int,
        bodyCount: Int,
        repetitionRatio: Double
    ) -> [String] {
        switch riskLevel {
        case .insufficientData:
            return []
        case .stable:
            return ["当前观测窗口内对话以日常分享为主，暂未出现明显睡眠、情绪或身体风险信号。"]
        case .watch, .attention:
            return riskSignalDescriptions(
                negativeCount: negativeCount,
                sleepCount: sleepCount,
                bodyCount: bodyCount,
                repetitionRatio: repetitionRatio
            )
        }
    }

    private func riskSignalDescriptions(
        negativeCount: Int,
        sleepCount: Int,
        bodyCount: Int,
        repetitionRatio: Double
    ) -> [String] {
        var descriptions: [String] = []
        if sleepCount > 0 {
            descriptions.append("睡眠信号：出现入睡或睡眠质量相关表达，建议了解是否连续发生。")
        }
        if negativeCount > 0 {
            descriptions.append("情绪信号：出现孤独、烦闷或低落相关表达，建议增加主动陪伴。")
        }
        if bodyCount > 0 {
            descriptions.append("身体信号：出现身体不适或饮食状态相关表达，建议家人线下确认。")
        }
        if repetitionRatio >= 0.4 {
            descriptions.append("重复信号：相似表达多次出现，建议结合近期生活变化继续观察。")
        }
        return descriptions
    }

    private func countMatches(in text: String, keywords: [String]) -> Int {
        keywords.reduce(0) { count, keyword in
            count + occurrences(of: normalize(keyword), in: text)
        }
    }

    private func occurrences(of keyword: String, in text: String) -> Int {
        guard !keyword.isEmpty else { return 0 }
        var count = 0
        var searchRange = text.startIndex..<text.endIndex
        while let range = text.range(of: keyword, options: [], range: searchRange) {
            count += 1
            searchRange = range.upperBound..<text.endIndex
        }
        return count
    }

    private func repeatedRatio(for texts: [String]) -> Double {
        guard texts.count > 1 else { return 0 }
        var seen: Set<String> = []
        var repeated = 0
        for text in texts where text.count >= 4 {
            if seen.contains(text) {
                repeated += 1
            } else {
                seen.insert(text)
            }
        }
        return Double(repeated) / Double(texts.count)
    }

    private func tokenize(_ text: String) -> [Character] {
        text.filter { !$0.isWhitespace }
    }

    private func normalize(_ text: String) -> String {
        String(text.unicodeScalars.filter { !ignoredScalars.contains($0) }).lowercased()
    }
}

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
                    timestamp: $0.timestamp,
                    speechDurationSeconds: $0.speechDurationSeconds,
                    pauseCount: $0.pauseCount,
                    emotionHint: $0.emotionHint
                )
            }
            .filter { !$0.text.isEmpty }
        let recentUserTurns = userTurns.filter { isInsideRecentWindow($0.timestamp, now: now) }
        let recentTotalTurnCount = turns.filter { isInsideRecentWindow($0.timestamp, now: now) }.count
        let window = observationWindow(for: recentUserTurns)
        let userTexts = recentUserTurns.map(\.text)

        guard !userTexts.isEmpty else {
            return CareSignalSnapshot(
                generatedAt: now,
                windowStart: window.start,
                windowEnd: window.end,
                windowDayCount: window.dayCount,
                dataCoverageSummary: dataCoverageSummary(dayCount: window.dayCount, userTurnCount: 0),
                totalTurns: recentTotalTurnCount,
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
                riskSignalDescriptions: [],
                dailyTrend: [],
                trendSummary: "暂无足够数据形成趋势观察。"
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
        let speechMetrics = speechMetrics(for: recentUserTurns)
        let riskLevel = classify(
            negativeCount: negativeCount,
            sleepCount: sleepCount,
            bodyCount: bodyCount,
            repetitionRatio: repetitionRatio,
            slowSpeechTurnCount: speechMetrics.slowSpeechTurnCount,
            longPauseTurnCount: speechMetrics.longPauseTurnCount,
            emotionVolatilityScore: speechMetrics.emotionVolatilityScore
        )
        let dailyTrend = dailyTrend(for: recentUserTurns, endDate: now)

        return CareSignalSnapshot(
            generatedAt: now,
            windowStart: window.start,
            windowEnd: window.end,
            windowDayCount: window.dayCount,
            dataCoverageSummary: dataCoverageSummary(dayCount: window.dayCount, userTurnCount: userTexts.count),
            totalTurns: recentTotalTurnCount,
            userTurnCount: userTexts.count,
            characterCount: characterCount,
            uniqueTokenCount: uniqueTokenCount,
            lexicalDiversity: lexicalDiversity,
            negativeEmotionMentions: negativeCount,
            sleepMentions: sleepCount,
            bodyDiscomfortMentions: bodyCount,
            repetitionRatio: repetitionRatio,
            averageWordsPerMinute: speechMetrics.averageWordsPerMinute,
            slowSpeechTurnCount: speechMetrics.slowSpeechTurnCount,
            longPauseTurnCount: speechMetrics.longPauseTurnCount,
            emotionVolatilityScore: speechMetrics.emotionVolatilityScore,
            riskLevel: riskLevel,
            summary: summary(for: riskLevel, userTurnCount: userTexts.count),
            suggestions: suggestions(for: riskLevel),
            weeklyHighlights: weeklyHighlights(
                riskLevel: riskLevel,
                negativeCount: negativeCount,
                sleepCount: sleepCount,
                bodyCount: bodyCount,
                repetitionRatio: repetitionRatio,
                slowSpeechTurnCount: speechMetrics.slowSpeechTurnCount,
                longPauseTurnCount: speechMetrics.longPauseTurnCount,
                emotionVolatilityScore: speechMetrics.emotionVolatilityScore
            ),
            riskSignalDescriptions: riskSignalDescriptions(
                negativeCount: negativeCount,
                sleepCount: sleepCount,
                bodyCount: bodyCount,
                repetitionRatio: repetitionRatio,
                slowSpeechTurnCount: speechMetrics.slowSpeechTurnCount,
                longPauseTurnCount: speechMetrics.longPauseTurnCount,
                emotionVolatilityScore: speechMetrics.emotionVolatilityScore
            ),
            dailyTrend: dailyTrend,
            trendSummary: trendSummary(for: dailyTrend)
        )
    }

    private func isInsideRecentWindow(_ timestamp: Date, now: Date) -> Bool {
        let calendar = Calendar.current
        let todayStart = calendar.startOfDay(for: now)
        guard let windowStart = calendar.date(byAdding: .day, value: -6, to: todayStart) else {
            return timestamp <= now
        }
        return timestamp >= windowStart && timestamp <= now
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
        repetitionRatio: Double,
        slowSpeechTurnCount: Int?,
        longPauseTurnCount: Int?,
        emotionVolatilityScore: Double?
    ) -> CareSignalRiskLevel {
        let signalClasses = [negativeCount > 0, sleepCount > 0, bodyCount > 0].filter { $0 }.count
        let totalSignalMentions = negativeCount + sleepCount + bodyCount
        let slowCount = slowSpeechTurnCount ?? 0
        let pauseCount = longPauseTurnCount ?? 0
        let volatility = emotionVolatilityScore ?? 0
        if (signalClasses >= 2 && totalSignalMentions >= 3) ||
            repetitionRatio >= 0.4 ||
            bodyCount >= 2 ||
            pauseCount >= 3 ||
            (slowCount >= 3 && volatility >= 0.5) {
            return .attention
        }
        if signalClasses >= 1 || slowCount > 0 || pauseCount > 0 || volatility >= 0.5 {
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
        repetitionRatio: Double,
        slowSpeechTurnCount: Int?,
        longPauseTurnCount: Int?,
        emotionVolatilityScore: Double?
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
                repetitionRatio: repetitionRatio,
                slowSpeechTurnCount: slowSpeechTurnCount,
                longPauseTurnCount: longPauseTurnCount,
                emotionVolatilityScore: emotionVolatilityScore
            )
        }
    }

    private func riskSignalDescriptions(
        negativeCount: Int,
        sleepCount: Int,
        bodyCount: Int,
        repetitionRatio: Double,
        slowSpeechTurnCount: Int?,
        longPauseTurnCount: Int?,
        emotionVolatilityScore: Double?
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
        if (slowSpeechTurnCount ?? 0) > 0 {
            descriptions.append("语速信号：授权语音中出现慢语速聚合信号，建议结合当天精神状态温和确认。")
        }
        if (longPauseTurnCount ?? 0) > 0 {
            descriptions.append("停顿信号：授权语音中出现较长停顿聚合信号，建议关注是否疲惫或表达困难。")
        }
        if (emotionVolatilityScore ?? 0) >= 0.5 {
            descriptions.append("情绪波动：授权语音或文本情绪提示变化较明显，建议增加陪伴。")
        }
        return descriptions
    }

    private func speechMetrics(
        for turns: [CareSignalInputTurn]
    ) -> (
        averageWordsPerMinute: Double?,
        slowSpeechTurnCount: Int?,
        longPauseTurnCount: Int?,
        emotionVolatilityScore: Double?
    ) {
        let speechRates = turns.compactMap { turn -> Double? in
            guard let duration = turn.speechDurationSeconds, duration > 0 else { return nil }
            let tokenCount = tokenize(normalize(turn.text)).count
            guard tokenCount > 0 else { return nil }
            return Double(tokenCount) / (duration / 60.0)
        }
        let averageRate = speechRates.isEmpty ? nil : speechRates.reduce(0, +) / Double(speechRates.count)
        let slowSpeechCount = speechRates.isEmpty ? nil : speechRates.filter { $0 < 40 }.count

        let pauseCounts = turns.compactMap(\.pauseCount)
        let longPauseCount = pauseCounts.isEmpty ? nil : pauseCounts.filter { $0 >= 3 }.count

        let emotionHints = turns
            .compactMap { $0.emotionHint?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
            .filter { !$0.isEmpty }
        let emotionVolatility: Double?
        if emotionHints.isEmpty {
            emotionVolatility = nil
        } else if emotionHints.count == 1 {
            emotionVolatility = 0
        } else {
            let changedTransitions = zip(emotionHints, emotionHints.dropFirst()).filter { $0 != $1 }.count
            emotionVolatility = Double(changedTransitions) / Double(emotionHints.count - 1)
        }

        return (averageRate, slowSpeechCount, longPauseCount, emotionVolatility)
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

    private func dailyTrend(
        for turns: [CareSignalInputTurn],
        endDate: Date?
    ) -> [CareSignalDailyTrendPoint] {
        guard !turns.isEmpty else { return [] }

        let calendar = Calendar.current
        let latestDate = endDate ?? turns.map(\.timestamp).max() ?? Date()
        let latestDay = calendar.startOfDay(for: latestDate)
        let earliestDay = calendar.date(byAdding: .day, value: -6, to: latestDay) ?? latestDay

        let grouped = Dictionary(grouping: turns) { turn in
            calendar.startOfDay(for: turn.timestamp)
        }

        return grouped.keys
            .filter { $0 >= earliestDay && $0 <= latestDay }
            .sorted()
            .compactMap { day -> CareSignalDailyTrendPoint? in
                guard let dayTurns = grouped[day], !dayTurns.isEmpty else { return nil }
                let normalizedTexts = dayTurns.map { normalize($0.text) }.filter { !$0.isEmpty }
                guard !normalizedTexts.isEmpty else { return nil }

                let allText = normalizedTexts.joined(separator: "")
                let negativeCount = countMatches(in: allText, keywords: negativeKeywords)
                let sleepCount = countMatches(in: allText, keywords: sleepKeywords)
                let bodyCount = countMatches(in: allText, keywords: bodyKeywords)
                let repetitionRatio = repeatedRatio(for: normalizedTexts)
                let speechMetrics = speechMetrics(for: dayTurns)
                let speechSignalScore = (speechMetrics.slowSpeechTurnCount ?? 0) +
                    (speechMetrics.longPauseTurnCount ?? 0) +
                    (((speechMetrics.emotionVolatilityScore ?? 0) >= 0.5) ? 1 : 0)
                return CareSignalDailyTrendPoint(
                    date: day,
                    userTurnCount: normalizedTexts.count,
                    negativeEmotionMentions: negativeCount,
                    sleepMentions: sleepCount,
                    bodyDiscomfortMentions: bodyCount,
                    repetitionRatio: repetitionRatio,
                    averageWordsPerMinute: speechMetrics.averageWordsPerMinute,
                    slowSpeechTurnCount: speechMetrics.slowSpeechTurnCount,
                    longPauseTurnCount: speechMetrics.longPauseTurnCount,
                    emotionVolatilityScore: speechMetrics.emotionVolatilityScore,
                    signalScore: negativeCount + sleepCount + bodyCount + speechSignalScore
                )
            }
    }

    private func trendSummary(for trend: [CareSignalDailyTrendPoint]) -> String {
        guard !trend.isEmpty else {
            return "暂无足够数据形成趋势观察。"
        }
        guard trend.count > 1 else {
            return "当前只有 1 天可用数据，建议继续积累后再观察趋势。"
        }

        let scores = trend.map { Double($0.signalScore) + ($0.repetitionRatio >= 0.4 ? 1.0 : 0.0) }
        let totalScore = scores.reduce(0, +)
        if totalScore == 0 {
            return "近 \(trend.count) 天趋势以日常表达为主，暂未出现聚合关怀信号。"
        }

        let splitIndex = max(1, trend.count / 2)
        let earlyScores = scores.prefix(splitIndex)
        let recentScores = scores.suffix(trend.count - splitIndex)
        let earlyAverage = earlyScores.reduce(0, +) / Double(earlyScores.count)
        let recentAverage = recentScores.reduce(0, +) / Double(recentScores.count)

        if recentAverage > earlyAverage + 0.5 {
            return "近 \(trend.count) 天关怀信号较前段增加，建议家人提高问候频率。"
        }
        if recentAverage + 0.5 < earlyAverage {
            return "近 \(trend.count) 天关怀信号较前段回落，可继续保持稳定陪伴。"
        }
        return "近 \(trend.count) 天关怀信号维持在相近水平，建议结合线下近况继续观察。"
    }

    private func tokenize(_ text: String) -> [Character] {
        text.filter { !$0.isWhitespace }
    }

    private func normalize(_ text: String) -> String {
        String(text.unicodeScalars.filter { !ignoredScalars.contains($0) }).lowercased()
    }
}

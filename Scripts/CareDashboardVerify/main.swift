import Foundation

private func assertCondition(_ condition: @autoclosure () -> Bool, _ message: String) {
    guard condition() else {
        fputs("FAIL: \(message)\n", stderr)
        exit(1)
    }
}

let analyzer = CareSignalAnalyzer()
let now = Date(timeIntervalSince1970: 1_800_000_200)
let twoDaysAgo = now.addingTimeInterval(-2 * 24 * 60 * 60)

private func assertDoesNotExposeFullInput(
    _ snapshot: CareSignalSnapshot,
    sourceTexts: [String],
    _ message: String
) {
    let generatedText = ([snapshot.summary, snapshot.dataCoverageSummary]
        + snapshot.suggestions
        + snapshot.weeklyHighlights
        + snapshot.riskSignalDescriptions)
        .joined(separator: "\n")
    for text in sourceTexts {
        assertCondition(!generatedText.contains(text), "\(message): \(text)")
    }
}

private func assertReportDoesNotExposeFullInput(
    _ descriptor: CareDashboardShareReportDescriptor,
    sourceTexts: [String],
    _ message: String
) {
    for text in sourceTexts {
        assertCondition(!descriptor.plainText.contains(text), "\(message): \(text)")
    }
}

let stable = analyzer.analyze(turns: [
    CareSignalInputTurn(role: "user", text: "今天和孙子聊了外滩的老照片。", timestamp: twoDaysAgo),
    CareSignalInputTurn(role: "user", text: "下午整理了阳台花草，心情很平稳。", timestamp: now.addingTimeInterval(-24 * 60 * 60)),
    CareSignalInputTurn(role: "ai", text: "听起来很温暖。", timestamp: now)
], now: now)
assertCondition(stable.riskLevel == .stable, "warm memory talk should be stable")
assertCondition(stable.userTurnCount == 2, "only user turns should be counted")
assertCondition(stable.suggestions.contains { $0.contains("保持") }, "stable suggestion should encourage keeping contact")
assertCondition(stable.windowStart == twoDaysAgo, "stable snapshot should use earliest input timestamp as window start")
assertCondition(stable.windowEnd == now.addingTimeInterval(-24 * 60 * 60), "stable snapshot should use latest user input timestamp as window end")
assertCondition(stable.windowDayCount == 2, "stable snapshot should count an inclusive two-day user observation window")
assertCondition(stable.dataCoverageSummary.contains("近 2 天"), "stable snapshot should summarize user observation day coverage")
assertCondition(stable.dataCoverageSummary.contains("用户发言 2 轮"), "stable snapshot should summarize user turn coverage")
assertCondition(!stable.weeklyHighlights.isEmpty, "stable snapshot should include weekly highlights")
assertCondition(stable.dailyTrend.count == 2, "stable snapshot should include two active trend days")
assertCondition(stable.dailyTrend.allSatisfy { $0.userTurnCount > 0 }, "trend points should only contain aggregated active days")
assertCondition(stable.trendSummary.contains("近 2 天"), "stable snapshot should include a bounded trend summary")
assertDoesNotExposeFullInput(
    stable,
    sourceTexts: ["今天和孙子聊了外滩的老照片。", "下午整理了阳台花草，心情很平稳。", "听起来很温暖。"],
    "stable generated dashboard fields should not expose full input sentences"
)

let watch = analyzer.analyze(turns: [
    CareSignalInputTurn(role: "user", text: "最近总是睡不着，有点孤单。", timestamp: now)
], now: now)
assertCondition(watch.riskLevel == .watch, "sleep plus loneliness should be watch")
assertCondition(watch.sleepMentions == 1, "sleep keyword should be counted once")
assertCondition(watch.negativeEmotionMentions == 1, "negative keyword should be counted once")
assertCondition(watch.windowStart == now, "single-turn snapshot should use the turn timestamp as window start")
assertCondition(watch.windowEnd == now, "single-turn snapshot should use the turn timestamp as window end")
assertCondition(watch.windowDayCount == 1, "single-turn snapshot should count one observation day")
assertCondition(watch.dataCoverageSummary.contains("近 1 天"), "watch snapshot should summarize one-day coverage")
assertCondition(watch.dataCoverageSummary.contains("用户发言 1 轮"), "watch snapshot should summarize user turn coverage")
assertCondition(watch.riskSignalDescriptions.contains { $0.contains("睡眠") }, "watch risk descriptions should explain sleep signal")
assertCondition(watch.riskSignalDescriptions.contains { $0.contains("情绪") }, "watch risk descriptions should explain emotion signal")
assertDoesNotExposeFullInput(
    watch,
    sourceTexts: ["最近总是睡不着，有点孤单。"],
    "watch generated dashboard fields should not expose full input sentences"
)
let watchReport = CareDashboardShareReportDescriptor.make(snapshot: watch, viewerName: "陈岚")
assertCondition(watchReport.title.contains("陈岚"), "share report should include viewer target name when provided")
assertCondition(watchReport.plainText.contains("家庭安心报"), "share report should have the phase-one family assurance report title")
assertCondition(watchReport.plainText.contains("脱敏周报"), "share report should still disclose sanitized weekly-report framing")
assertCondition(watchReport.plainText.contains("风险等级：建议关注"), "share report should include risk level")
assertCondition(watchReport.plainText.contains("数据覆盖：近 1 天，用户发言 1 轮。"), "share report should include coverage")
assertCondition(watchReport.plainText.contains("观测窗口："), "share report should include observation window")
assertCondition(watchReport.plainText.contains("睡眠信号 1"), "share report should include aggregate sleep metric")
assertCondition(watchReport.plainText.contains("情绪信号 1"), "share report should include aggregate emotion metric")
assertCondition(watchReport.plainText.contains("趋势观察"), "share report should include trend observation")
assertCondition(watchReport.plainText.contains("当前只有 1 天可用数据"), "single-day share report should avoid overclaiming trend")
assertCondition(watchReport.plainText.contains("不包含原始聊天内容"), "share report should include no-raw-content boundary")
assertCondition(watchReport.plainText.contains("不是医疗诊断"), "share report should include medical boundary")
assertReportDoesNotExposeFullInput(
    watchReport,
    sourceTexts: ["最近总是睡不着，有点孤单。"],
    "watch share report should not expose full input sentences"
)

let speechRadar = analyzer.analyze(turns: [
    CareSignalInputTurn(
        role: "user",
        text: "今天不太想说话",
        timestamp: now.addingTimeInterval(-2 * 24 * 60 * 60),
        speechDurationSeconds: 36,
        pauseCount: 4,
        emotionHint: "low"
    ),
    CareSignalInputTurn(
        role: "user",
        text: "我有点烦，也睡不好",
        timestamp: now.addingTimeInterval(-24 * 60 * 60),
        speechDurationSeconds: 42,
        pauseCount: 5,
        emotionHint: "negative"
    )
], now: now)
assertCondition(speechRadar.averageWordsPerMinute != nil, "speech radar should compute average speech rate when durations are present")
assertCondition((speechRadar.averageWordsPerMinute ?? 999) < 40, "slow speech samples should lower average speech rate")
assertCondition(speechRadar.slowSpeechTurnCount == 2, "speech radar should count slow speech turns")
assertCondition(speechRadar.longPauseTurnCount == 2, "speech radar should count long-pause turns")
assertCondition((speechRadar.emotionVolatilityScore ?? 0) > 0, "speech radar should aggregate emotion hint changes")
assertCondition(speechRadar.riskSignalDescriptions.contains { $0.contains("语速") }, "speech radar should describe slow speech signal")
assertCondition(speechRadar.riskSignalDescriptions.contains { $0.contains("停顿") }, "speech radar should describe long pause signal")
assertCondition(speechRadar.dailyTrend.allSatisfy { $0.averageWordsPerMinute != nil }, "daily trend should include aggregate speech rate when present")
let speechRadarReport = CareDashboardShareReportDescriptor.make(snapshot: speechRadar, viewerName: "陈岚")
assertCondition(speechRadarReport.plainText.contains("平均语速"), "share report should include aggregate speech-rate metric")
assertCondition(speechRadarReport.plainText.contains("慢语速轮次 2"), "share report should include aggregate slow-speech count")
assertCondition(speechRadarReport.plainText.contains("长停顿轮次 2"), "share report should include aggregate long-pause count")
assertCondition(speechRadarReport.plainText.contains("情绪波动"), "share report should include aggregate emotion volatility")
assertReportDoesNotExposeFullInput(
    speechRadarReport,
    sourceTexts: ["今天不太想说话", "我有点烦，也睡不好", "raw audio", "rawTranscript"],
    "speech radar share report should not expose raw speech or transcript content"
)

let attention = analyzer.analyze(turns: [
    CareSignalInputTurn(role: "user", text: "我睡不好，胸闷，也吃不下。", timestamp: now),
    CareSignalInputTurn(role: "user", text: "我睡不好，胸闷，也吃不下。", timestamp: now)
], now: now)
assertCondition(attention.riskLevel == .attention, "multiple signal classes plus repetition should be attention")
assertCondition(attention.repetitionRatio > 0, "repeated user text should increase repetition ratio")
assertCondition(attention.bodyDiscomfortMentions >= 2, "body discomfort keywords should be counted")
assertCondition(attention.riskSignalDescriptions.contains { $0.contains("睡眠") }, "attention risk descriptions should explain sleep signal")
assertCondition(attention.riskSignalDescriptions.contains { $0.contains("身体") }, "attention risk descriptions should explain body signal")
assertDoesNotExposeFullInput(
    attention,
    sourceTexts: ["我睡不好，胸闷，也吃不下。"],
    "attention generated dashboard fields should not expose full input sentences"
)
let attentionReport = CareDashboardShareReportDescriptor.make(snapshot: attention)
assertCondition(attentionReport.plainText.contains("风险等级：需要尽快确认"), "attention share report should include attention risk title")
assertReportDoesNotExposeFullInput(
    attentionReport,
    sourceTexts: ["我睡不好，胸闷，也吃不下。"],
    "attention share report should not expose full input sentences"
)

let empty = analyzer.analyze(turns: [], now: now)
assertCondition(empty.userTurnCount == 0, "empty input should have no user turns")
assertCondition(empty.riskLevel == .insufficientData, "empty input should be data-insufficient instead of stable")
assertCondition(empty.summary.contains("暂无"), "empty summary should explain missing data")
assertCondition(empty.windowStart == nil, "empty snapshot should not have a window start")
assertCondition(empty.windowEnd == nil, "empty snapshot should not have a window end")
assertCondition(empty.windowDayCount == 0, "empty snapshot should count zero observation days")
assertCondition(empty.dataCoverageSummary.contains("近 0 天"), "empty snapshot should summarize zero-day coverage")
assertCondition(empty.dataCoverageSummary.contains("用户发言 0 轮"), "empty snapshot should summarize zero user turns")
let emptyReport = CareDashboardShareReportDescriptor.make(snapshot: empty)
assertCondition(emptyReport.plainText.contains("风险等级：数据不足"), "empty share report should preserve insufficient-data state")
assertCondition(!emptyReport.plainText.contains("风险等级：状态稳定"), "empty share report should not claim stable state")

let thirtyDaysAgo = now.addingTimeInterval(-30 * 24 * 60 * 60)
let recentWindow = analyzer.analyze(turns: [
    CareSignalInputTurn(role: "user", text: "一个月前我睡不好，胸闷，也很孤单。", timestamp: thirtyDaysAgo),
    CareSignalInputTurn(role: "user", text: "今天吃了晚饭，散步半小时。", timestamp: now)
], now: now)
assertCondition(recentWindow.userTurnCount == 1, "care dashboard should only count user turns inside the recent seven-day window")
assertCondition(recentWindow.riskLevel == .stable, "old risk signals outside seven days should not affect current dashboard risk")
assertCondition(recentWindow.sleepMentions == 0, "old sleep signals should be excluded from current dashboard metrics")
assertCondition(recentWindow.bodyDiscomfortMentions == 0, "old body signals should be excluded from current dashboard metrics")
assertCondition(recentWindow.negativeEmotionMentions == 0, "old emotion signals should be excluded from current dashboard metrics")

let staleOnly = analyzer.analyze(turns: [
    CareSignalInputTurn(role: "user", text: "一个月前我睡不好，胸闷，也很孤单。", timestamp: thirtyDaysAgo)
], now: now)
assertCondition(staleOnly.userTurnCount == 0, "stale-only care input should not be treated as current data")
assertCondition(staleOnly.riskLevel == .insufficientData, "stale-only care input should show insufficient current data")

let familyAll = MemoryPrivacyMetadata(scope: .familyCircle)
let daughterOnly = MemoryPrivacyMetadata(
    scope: .familyCircle,
    familyVisibility: .selectedMembers(["fm_daughter"])
)
let sonOnly = MemoryPrivacyMetadata(
    scope: .familyCircle,
    familyVisibility: .selectedMembers(["fm_son"])
)
let visibleTurns = CareDashboardInputPolicy.eligibleInputTurns(
    from: [
        ConversationTurn(role: "user", text: "全体亲友可见：今天睡得还可以。", timestamp: now, privacyMetadata: familyAll),
        ConversationTurn(role: "user", text: "女儿可见：最近有点孤单。", timestamp: now, privacyMetadata: daughterOnly),
        ConversationTurn(role: "user", text: "儿子可见：最近胸闷。", timestamp: now, privacyMetadata: sonOnly),
        ConversationTurn(role: "user", text: "本机内容不进看板。", timestamp: now, privacyMetadata: MemoryPrivacyMetadata(scope: .localOnly)),
        ConversationTurn(role: "user", text: "时空信箱写给未来的我", timestamp: now, privacyMetadata: familyAll)
    ],
    viewerFamilyMemberID: "fm_daughter"
)
assertCondition(
    visibleTurns.map(\.text) == ["全体亲友可见：今天睡得还可以。", "女儿可见：最近有点孤单。"],
    "care dashboard input policy should include all-family plus selected-member turns"
)

let daughterSnapshot = analyzer.analyze(turns: visibleTurns, now: now)
let daughterReport = CareDashboardShareReportDescriptor.make(snapshot: daughterSnapshot, viewerName: "陈岚")
assertReportDoesNotExposeFullInput(
    daughterReport,
    sourceTexts: [
        "全体亲友可见：今天睡得还可以。",
        "女儿可见：最近有点孤单。",
        "儿子可见：最近胸闷。",
        "本机内容不进看板。",
        "时空信箱写给未来的我"
    ],
    "selected-member share report should not expose raw or unauthorized sentences"
)
assertCondition(!daughterReport.plainText.contains("儿子可见"), "selected-member share report should not include unauthorized member sentinel")
assertCondition(!daughterReport.plainText.contains("本机内容"), "selected-member share report should not include local-only sentinel")

print("CareDashboard verification passed")

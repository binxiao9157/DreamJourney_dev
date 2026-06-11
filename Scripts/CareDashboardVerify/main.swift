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

let empty = analyzer.analyze(turns: [], now: now)
assertCondition(empty.userTurnCount == 0, "empty input should have no user turns")
assertCondition(empty.riskLevel == .insufficientData, "empty input should be data-insufficient instead of stable")
assertCondition(empty.summary.contains("暂无"), "empty summary should explain missing data")
assertCondition(empty.windowStart == nil, "empty snapshot should not have a window start")
assertCondition(empty.windowEnd == nil, "empty snapshot should not have a window end")
assertCondition(empty.windowDayCount == 0, "empty snapshot should count zero observation days")
assertCondition(empty.dataCoverageSummary.contains("近 0 天"), "empty snapshot should summarize zero-day coverage")
assertCondition(empty.dataCoverageSummary.contains("用户发言 0 轮"), "empty snapshot should summarize zero user turns")

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

print("CareDashboard verification passed")

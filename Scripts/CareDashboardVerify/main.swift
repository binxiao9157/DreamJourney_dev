import Foundation

private func assertCondition(_ condition: @autoclosure () -> Bool, _ message: String) {
    guard condition() else {
        fputs("FAIL: \(message)\n", stderr)
        exit(1)
    }
}

let analyzer = CareSignalAnalyzer()
let now = Date(timeIntervalSince1970: 1_800_000_200)

let stable = analyzer.analyze(turns: [
    CareSignalInputTurn(role: "user", text: "今天和孙子聊了外滩的老照片。", timestamp: now),
    CareSignalInputTurn(role: "ai", text: "听起来很温暖。", timestamp: now)
], now: now)
assertCondition(stable.riskLevel == .stable, "warm memory talk should be stable")
assertCondition(stable.userTurnCount == 1, "only user turns should be counted")
assertCondition(stable.suggestions.contains { $0.contains("保持") }, "stable suggestion should encourage keeping contact")

let watch = analyzer.analyze(turns: [
    CareSignalInputTurn(role: "user", text: "最近总是睡不着，有点孤单。", timestamp: now)
], now: now)
assertCondition(watch.riskLevel == .watch, "sleep plus loneliness should be watch")
assertCondition(watch.sleepMentions == 1, "sleep keyword should be counted once")
assertCondition(watch.negativeEmotionMentions == 1, "negative keyword should be counted once")

let attention = analyzer.analyze(turns: [
    CareSignalInputTurn(role: "user", text: "我睡不好，胸闷，也吃不下。", timestamp: now),
    CareSignalInputTurn(role: "user", text: "我睡不好，胸闷，也吃不下。", timestamp: now)
], now: now)
assertCondition(attention.riskLevel == .attention, "multiple signal classes plus repetition should be attention")
assertCondition(attention.repetitionRatio > 0, "repeated user text should increase repetition ratio")
assertCondition(attention.bodyDiscomfortMentions >= 2, "body discomfort keywords should be counted")

let empty = analyzer.analyze(turns: [], now: now)
assertCondition(empty.userTurnCount == 0, "empty input should have no user turns")
assertCondition(empty.riskLevel == .insufficientData, "empty input should be data-insufficient instead of stable")
assertCondition(empty.summary.contains("暂无"), "empty summary should explain missing data")

print("CareDashboard verification passed")

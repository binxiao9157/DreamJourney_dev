import Foundation

private func assertCondition(_ condition: @autoclosure () -> Bool, _ message: String) {
    guard condition() else {
        fputs("FAIL: \(message)\n", stderr)
        exit(1)
    }
}

assertCondition(
    DialogEndIntentPolicy.endKeywords.contains("聊完了"),
    "plain conversation ending should be recognized as an end keyword"
)
assertCondition(
    !DialogEndIntentPolicy.shouldPromptMemoir(for: .keyword("聊完了")),
    "plain conversation ending must not prompt memoir generation"
)
assertCondition(
    !DialogEndIntentPolicy.shouldRecordAsMemoryTurn("聊完了"),
    "plain conversation ending must not be recorded as a memory turn"
)
assertCondition(
    !DialogEndIntentPolicy.shouldPromptMemoir(for: .keyword("下次再聊")),
    "generic goodbye must not prompt memoir generation"
)
assertCondition(
    !DialogEndIntentPolicy.shouldRecordAsMemoryTurn("下次再聊"),
    "generic goodbye must not be recorded as a memory turn"
)
assertCondition(
    DialogEndIntentPolicy.shouldPromptMemoir(for: .keyword("生成回忆录")),
    "explicit memoir request should prompt memoir generation"
)
assertCondition(
    !DialogEndIntentPolicy.shouldRecordAsMemoryTurn("生成回忆录"),
    "explicit memoir command should trigger the flow without polluting memory turns"
)
assertCondition(
    DialogEndIntentPolicy.shouldPromptMemoir(for: .keyword("整理回忆录")),
    "explicit memoir organization request should prompt memoir generation"
)
assertCondition(
    DialogEndIntentPolicy.shouldRecordAsMemoryTurn("1978年我和妻子林桂芳在杭州西湖边开过一家小照相馆。"),
    "substantive family memory should still be recorded"
)
assertCondition(
    DialogEndIntentPolicy.shouldRecordAsMemoryTurn("那家照相馆在1985年结束营业。"),
    "substantive memories containing an end keyword should not be suppressed"
)
assertCondition(
    !DialogEndIntentPolicy.shouldPromptMemoir(for: .manual),
    "manual stop must not prompt memoir generation"
)
assertCondition(
    !DialogEndIntentPolicy.shouldPromptMemoir(for: .silenceTimeout),
    "silence timeout must not prompt memoir generation"
)

print("DialogEndIntent verification passed")

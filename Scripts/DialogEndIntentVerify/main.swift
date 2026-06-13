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
    !DialogEndIntentPolicy.shouldPromptMemoir(for: .keyword("下次再聊")),
    "generic goodbye must not prompt memoir generation"
)
assertCondition(
    DialogEndIntentPolicy.shouldPromptMemoir(for: .keyword("生成回忆录")),
    "explicit memoir request should prompt memoir generation"
)
assertCondition(
    DialogEndIntentPolicy.shouldPromptMemoir(for: .keyword("整理回忆录")),
    "explicit memoir organization request should prompt memoir generation"
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

import Foundation

func assertCondition(_ condition: @autoclosure () -> Bool, _ message: String) {
    if !condition() {
        fputs("FAIL: \(message)\n", stderr)
        exit(1)
    }
}

let policy = ConversationWellbeingLimiter.Policy(
    softUserTurnLimit: 3,
    hardUserTurnLimit: 5,
    softDuration: 60,
    hardDuration: 120
)
let limiter = ConversationWellbeingLimiter(policy: policy)
let start = Date(timeIntervalSince1970: 1_000)

limiter.startSession(at: start)
assertCondition(
    limiter.decision(at: start.addingTimeInterval(30)) == .allow,
    "fresh sessions should allow recording"
)

limiter.recordFinalUserTurn("我想讲讲绍兴老家的事情")
limiter.recordFinalUserTurn("后来我们搬到了杭州")
limiter.recordFinalUserTurn("我还记得西湖边的小照相馆")

let nudgeDecision = limiter.decision(at: start.addingTimeInterval(80))
assertCondition(nudgeDecision.isNudge, "soft threshold should produce a nudge")
assertCondition(
    nudgeDecision.message.contains("休息") || nudgeDecision.message.contains("外面的世界"),
    "nudge copy should guide the user back to real life"
)
assertCondition(
    !nudgeDecision.message.contains("继续聊") && !nudgeDecision.message.contains("再陪你"),
    "nudge copy should not encourage endless roleplay"
)

limiter.recordFinalUserTurn("第四句")
limiter.recordFinalUserTurn("第五句")
let limitDecision = limiter.decision(at: start.addingTimeInterval(121))
assertCondition(limitDecision.isLimited, "hard threshold should limit recording")
assertCondition(
    limitDecision.message.contains("今天先到这里"),
    "limit copy should clearly close the current session"
)

limiter.endSession()
assertCondition(
    limiter.decision(at: start.addingTimeInterval(240)) == .allow,
    "ending a session should reset the limiter"
)

print("ConversationWellbeingLimiter verification passed")

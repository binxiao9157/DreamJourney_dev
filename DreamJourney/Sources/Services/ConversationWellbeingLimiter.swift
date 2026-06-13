import Foundation

final class ConversationWellbeingLimiter {
    struct Policy {
        let softUserTurnLimit: Int
        let hardUserTurnLimit: Int
        let softDuration: TimeInterval
        let hardDuration: TimeInterval
        let inactivityResetInterval: TimeInterval

        init(
            softUserTurnLimit: Int,
            hardUserTurnLimit: Int,
            softDuration: TimeInterval,
            hardDuration: TimeInterval,
            inactivityResetInterval: TimeInterval = 30 * 60
        ) {
            self.softUserTurnLimit = softUserTurnLimit
            self.hardUserTurnLimit = hardUserTurnLimit
            self.softDuration = softDuration
            self.hardDuration = hardDuration
            self.inactivityResetInterval = inactivityResetInterval
        }

        static let `default` = Policy(
            softUserTurnLimit: 8,
            hardUserTurnLimit: 12,
            softDuration: 10 * 60,
            hardDuration: 20 * 60
        )
    }

    enum Decision: Equatable {
        case allow
        case nudge(message: String)
        case limit(message: String)

        var isNudge: Bool {
            if case .nudge = self { return true }
            return false
        }

        var isLimited: Bool {
            if case .limit = self { return true }
            return false
        }

        var message: String {
            switch self {
            case .allow:
                return ""
            case .nudge(let message), .limit(let message):
                return message
            }
        }
    }

    let policy: Policy
    private var sessionStartedAt: Date?
    private var lastActivityAt: Date?
    private var finalUserTurnCount = 0
    private var hasShownSoftNudge = false

    init(policy: Policy = .default) {
        self.policy = policy
    }

    func startSession(at date: Date = Date()) {
        if shouldResetSession(at: date) {
            resetSession(startedAt: date)
            return
        }

        if sessionStartedAt == nil {
            resetSession(startedAt: date)
        } else {
            lastActivityAt = date
        }
    }

    func recordFinalUserTurn(_ text: String, at date: Date = Date()) {
        startSession(at: date)
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        finalUserTurnCount += 1
        lastActivityAt = date
    }

    func decision(at date: Date = Date()) -> Decision {
        if shouldResetSession(at: date) {
            resetSession(startedAt: nil)
            return .allow
        }

        guard let sessionStartedAt else { return .allow }

        let elapsed = date.timeIntervalSince(sessionStartedAt)
        if finalUserTurnCount >= policy.hardUserTurnLimit || elapsed >= policy.hardDuration {
            return .limit(message: Self.limitMessage)
        }

        if !hasShownSoftNudge,
           finalUserTurnCount >= policy.softUserTurnLimit || elapsed >= policy.softDuration {
            return .nudge(message: Self.nudgeMessage)
        }

        return .allow
    }

    func markNudgeShown() {
        hasShownSoftNudge = true
    }

    func endSession() {
        resetSession(startedAt: nil)
    }

    private func shouldResetSession(at date: Date) -> Bool {
        guard let lastActivityAt else { return false }
        return date.timeIntervalSince(lastActivityAt) >= policy.inactivityResetInterval
    }

    private func resetSession(startedAt date: Date?) {
        sessionStartedAt = date
        lastActivityAt = date
        finalUserTurnCount = 0
        hasShownSoftNudge = false
    }

    private static let nudgeMessage = "今天聊得已经比较久了，我们先放慢一点。可以休息一下，喝口水，去看看外面的世界；准备好了再回来。"
    private static let limitMessage = "今天先到这里。刚才的记忆已经留下来了，请先休息一下，去看看外面的世界，晚些时候再继续。"
}

import Foundation

struct EchoDelayedReply: Codable, Equatable {
    let id: String
    let scheduledAt: Date
    let deliverAt: Date
    let minutes: Int
    let userTurnCount: Int
    let trigger: EchoDelayedReplyTrigger
}

enum EchoDelayedReplyTrigger: String, Codable {
    case tenRoundBaseline
    case contentSignal
}

final class EchoDelayedReplyStore {
    static let shared = EchoDelayedReplyStore()

    private let storageKey = "dj.echo.delayedReply"
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func save(_ reply: EchoDelayedReply) -> Bool {
        guard let data = try? JSONEncoder().encode(reply) else {
            return false
        }
        defaults.set(data, forKey: storageKey)
        return true
    }

    func load() -> EchoDelayedReply? {
        guard let data = defaults.data(forKey: storageKey) else {
            return nil
        }
        return try? JSONDecoder().decode(EchoDelayedReply.self, from: data)
    }

    func clear() {
        defaults.removeObject(forKey: storageKey)
    }
}

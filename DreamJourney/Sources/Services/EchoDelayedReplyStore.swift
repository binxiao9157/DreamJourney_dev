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

private struct EchoDelayedReplyEnvelope: Codable {
    let subjectId: String
    let vaultId: String
    let generation: UInt64
    let generationId: UUID
    let authorityEpoch: String
    let reply: EchoDelayedReply

    init(reply: EchoDelayedReply, accountLease: AccountLease) {
        subjectId = accountLease.subjectId
        vaultId = accountLease.vaultId
        generation = accountLease.generation
        generationId = accountLease.generationId
        authorityEpoch = accountLease.authorityEpoch
        self.reply = reply
    }

    func matchesOwnership(_ accountLease: AccountLease) -> Bool {
        subjectId == accountLease.subjectId
            && vaultId == accountLease.vaultId
    }
}

final class EchoDelayedReplyStore {
    static let shared = EchoDelayedReplyStore()

    private let storageKey = "dj.echo.delayedReply"
    private let defaults: UserDefaults
    private let accountLeaseRuntime: AccountLeaseRuntimePort

    init(
        defaults: UserDefaults = .standard,
        accountLeaseRuntime: AccountLeaseRuntimePort = AccountLeaseRuntime.shared
    ) {
        self.defaults = defaults
        self.accountLeaseRuntime = accountLeaseRuntime
    }

    func save(_ reply: EchoDelayedReply) -> Bool {
        guard let accountLease = accountLeaseRuntime.capture(forSubjectId: nil),
              accountLeaseRuntime.validate(accountLease, at: .commit).allowed,
              let data = try? JSONEncoder().encode(
                  EchoDelayedReplyEnvelope(reply: reply, accountLease: accountLease)
              ) else {
            return false
        }
        let accountStorageKey = storageKey(for: accountLease.subjectId)
        defaults.set(data, forKey: accountStorageKey)
        guard accountLeaseRuntime.validate(accountLease, at: .commit).allowed else {
            if defaults.data(forKey: accountStorageKey) == data {
                defaults.removeObject(forKey: accountStorageKey)
            }
            return false
        }
        return true
    }

    func load() -> EchoDelayedReply? {
        guard let accountLease = accountLeaseRuntime.capture(forSubjectId: nil),
              accountLeaseRuntime.validate(accountLease, at: .request).allowed,
              let data = defaults.data(forKey: storageKey(for: accountLease.subjectId)),
              let envelope = try? JSONDecoder().decode(EchoDelayedReplyEnvelope.self, from: data),
              envelope.matchesOwnership(accountLease),
              accountLeaseRuntime.validate(accountLease, at: .runtime).allowed else {
            return nil
        }
        return envelope.reply
    }

    func clear() {
        guard let accountLease = accountLeaseRuntime.capture(forSubjectId: nil),
              accountLeaseRuntime.validate(accountLease, at: .commit).allowed else {
            return
        }
        let accountStorageKey = storageKey(for: accountLease.subjectId)
        let previousData = defaults.data(forKey: accountStorageKey)
        defaults.removeObject(forKey: accountStorageKey)
        defaults.removeObject(forKey: storageKey)
        guard accountLeaseRuntime.validate(accountLease, at: .commit).allowed else {
            if defaults.data(forKey: accountStorageKey) == nil, let previousData {
                defaults.set(previousData, forKey: accountStorageKey)
            }
            return
        }
    }

    private func storageKey(for subjectId: String) -> String {
        "\(storageKey).\(subjectId)"
    }
}

import Foundation

final class NarrativeReaderStateStore {
    static let shared = NarrativeReaderStateStore()

    private let defaults: UserDefaults
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    private let lock = NSLock()

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func load(projectId: String, accountLease: AccountLease) -> NarrativeReadingState {
        lock.lock()
        defer { lock.unlock() }
        guard let data = defaults.data(forKey: key(projectId: projectId, accountLease: accountLease)),
              let value = try? decoder.decode(NarrativeReadingState.self, from: data),
              value.schemaVersion == NarrativeReadingState.schemaVersion else {
            return NarrativeReadingState()
        }
        return value
    }

    func save(_ state: NarrativeReadingState, projectId: String, accountLease: AccountLease) {
        lock.lock()
        defer { lock.unlock() }
        guard let data = try? encoder.encode(state) else { return }
        defaults.set(data, forKey: key(projectId: projectId, accountLease: accountLease))
    }

    func teardownForAccountLifecycle(oldAccountLease: AccountLease?) -> Bool {
        guard let oldAccountLease else { return true }
        let prefix = keyPrefix(accountLease: oldAccountLease)
        lock.lock()
        defer { lock.unlock() }
        defaults.dictionaryRepresentation().keys
            .filter { $0.hasPrefix(prefix) }
            .forEach(defaults.removeObject(forKey:))
        return true
    }

    private func key(projectId: String, accountLease: AccountLease) -> String {
        "\(keyPrefix(accountLease: accountLease))\(projectId)"
    }

    private func keyPrefix(accountLease: AccountLease) -> String {
        "dj.narrative.reader.v1.\(accountLease.subjectId).\(accountLease.generationId.uuidString)."
    }
}

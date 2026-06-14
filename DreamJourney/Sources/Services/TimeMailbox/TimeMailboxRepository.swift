import Foundation

enum TimeMailboxRepositoryError: Error, Equatable {
    case invalidRecipient
    case invalidBody
    case boundaryNotAcknowledged
    case letterNotFound
}

final class TimeMailboxRepository {
    static let shared = TimeMailboxRepository()
    static let defaultMinimumDeliveryDelay: TimeInterval = 5 * 60

    private let defaults: UserDefaults
    private let storageKey: String
    private let minimumDeliveryDelay: TimeInterval
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(
        defaults: UserDefaults = .standard,
        storageKey: String = "dreamjourney.timeMailbox.letters",
        minimumDeliveryDelay: TimeInterval = TimeMailboxRepository.defaultMinimumDeliveryDelay
    ) {
        self.defaults = defaults
        self.storageKey = storageKey
        self.minimumDeliveryDelay = minimumDeliveryDelay
        encoder.dateEncodingStrategy = .iso8601
        decoder.dateDecodingStrategy = .iso8601
    }

    func letters() -> [TimeMailboxLetter] {
        load().sorted { lhs, rhs in
            if lhs.deliverAt == rhs.deliverAt {
                return lhs.createdAt > rhs.createdAt
            }
            return lhs.deliverAt > rhs.deliverAt
        }
    }

    @discardableResult
    func createLetter(
        id: String = UUID().uuidString,
        recipientName: String,
        title: String,
        body: String,
        deliverAt: Date,
        now: Date = Date(),
        boundaryAcknowledged: Bool,
        privacyMetadata: MemoryPrivacyMetadata = MemoryPrivacyMetadata(scope: .localOnly)
    ) throws -> TimeMailboxLetter {
        let cleanRecipient = recipientName.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanBody = body.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !cleanRecipient.isEmpty else { throw TimeMailboxRepositoryError.invalidRecipient }
        guard !cleanBody.isEmpty else { throw TimeMailboxRepositoryError.invalidBody }
        guard boundaryAcknowledged else { throw TimeMailboxRepositoryError.boundaryNotAcknowledged }

        let minimumDeliverAt = now.addingTimeInterval(minimumDeliveryDelay)
        let letter = TimeMailboxLetter(
            id: id,
            recipientName: cleanRecipient,
            title: cleanTitle.isEmpty ? "给\(cleanRecipient)的一封信" : cleanTitle,
            body: cleanBody,
            createdAt: now,
            deliverAt: max(deliverAt, minimumDeliverAt),
            deliveredAt: nil,
            status: .sealed,
            replyText: nil,
            boundaryAcknowledged: true,
            privacyMetadata: privacyMetadata
        )

        var all = load()
        all.insert(letter, at: 0)
        save(all)
        return letter
    }

    @discardableResult
    func refreshDelivery(
        now: Date = Date(),
        evidenceProvider: ((TimeMailboxLetter) -> TimeMailboxEchoEvidence)? = nil
    ) -> [TimeMailboxLetter] {
        var all = load()
        var delivered: [TimeMailboxLetter] = []

        for index in all.indices {
            guard all[index].status == .sealed, all[index].deliverAt <= now else { continue }
            all[index].status = .delivered
            all[index].deliveredAt = now
            let evidence = evidenceProvider?(all[index]) ?? .empty
            all[index].replyText = Self.makeReply(for: all[index], evidence: evidence)
            delivered.append(all[index])
        }

        if !delivered.isEmpty {
            save(all)
        }
        return delivered.sorted { $0.deliverAt > $1.deliverAt }
    }

    func markRead(id: String) throws {
        var all = load()
        guard let index = all.firstIndex(where: { $0.id == id }) else {
            throw TimeMailboxRepositoryError.letterNotFound
        }
        if all[index].status == .delivered {
            all[index].status = .read
        }
        save(all)
    }

    func delete(id: String) throws {
        var all = load()
        guard let index = all.firstIndex(where: { $0.id == id }) else {
            throw TimeMailboxRepositoryError.letterNotFound
        }
        all.remove(at: index)
        save(all)
    }

    private func load() -> [TimeMailboxLetter] {
        guard let data = defaults.data(forKey: storageKey) else { return [] }
        guard let decoded = try? decoder.decode([TimeMailboxLetter].self, from: data) else { return [] }
        let cleaned = decoded.filter { !Self.isLegacySeedLetter($0) }
        if cleaned.count != decoded.count {
            save(cleaned)
        }
        return cleaned
    }

    private func save(_ letters: [TimeMailboxLetter]) {
        guard let data = try? encoder.encode(letters) else { return }
        defaults.set(data, forKey: storageKey)
    }

    private static func makeReply(
        for letter: TimeMailboxLetter,
        evidence: TimeMailboxEchoEvidence
    ) -> String {
        let memoryLine = "你把这份想念认真保存了下来；信件正文仍只留在本机信箱里。"
        let evidenceLine: String
        if evidence.isEmpty {
            evidenceLine = "这次没有找到足够的已授权记忆细节，所以不会替Ta编造具体经历。"
        } else {
            evidenceLine = """
            我能参考到的已授权记忆有：
            \(evidence.lines.prefix(5).map { "· \($0)" }.joined(separator: "\n"))
            """
        }

        return """
        这段回应基于你留下的记忆整理而来，不是逝者真实回复。

        \(memoryLine)

        \(evidenceLine)

        愿这封信先替你收好今天的思念。你可以慢慢地把想说的话写下来，也可以在准备好的时候，把这份记忆带回现实生活里，交给还在身边的人一起珍藏。
        """
    }

    private static func isLegacySeedLetter(_ letter: TimeMailboxLetter) -> Bool {
        letter.id.hasPrefix("roadshow_")
    }
}

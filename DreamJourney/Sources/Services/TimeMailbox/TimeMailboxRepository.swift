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
    private let echoService: TimeMailboxEchoGenerating
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(
        defaults: UserDefaults = .standard,
        storageKey: String = "dreamjourney.timeMailbox.letters",
        minimumDeliveryDelay: TimeInterval = TimeMailboxRepository.defaultMinimumDeliveryDelay,
        echoService: TimeMailboxEchoGenerating = TimeMailboxEchoService.shared
    ) {
        self.defaults = defaults
        self.storageKey = storageKey
        self.minimumDeliveryDelay = minimumDeliveryDelay
        self.echoService = echoService
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
        guard !Self.isGenericKinshipRecipient(cleanRecipient) else {
            throw TimeMailboxRepositoryError.invalidRecipient
        }
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
            let echo = echoService.makeEcho(for: all[index], evidence: evidence)
            all[index].replyText = echo.replyText
            all[index].echoMode = echo.mode
            all[index].echoEvidenceLineCount = echo.evidenceLineCount
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

    @discardableResult
    func mergeRemoteMetadata(_ remoteItems: [TimeMailboxLetterMetadata]) -> Int {
        var all = load()
        var changedCount = 0

        for item in remoteItems {
            guard let sanitized = Self.sanitizedRemoteMetadata(item) else { continue }

            if let index = all.firstIndex(where: { $0.id == sanitized.id }) {
                let existing = all[index]
                let merged = TimeMailboxLetter(
                    id: existing.id,
                    recipientName: sanitized.recipientName,
                    title: sanitized.title,
                    body: existing.body,
                    createdAt: sanitized.createdAt,
                    deliverAt: sanitized.deliverAt,
                    deliveredAt: sanitized.deliveredAt,
                    status: sanitized.status,
                    replyText: existing.replyText,
                    echoMode: existing.echoMode,
                    echoEvidenceLineCount: existing.echoEvidenceLineCount,
                    boundaryAcknowledged: sanitized.boundaryAcknowledged,
                    privacyMetadata: sanitized.privacyMetadata
                )
                if merged != existing {
                    all[index] = merged
                    changedCount += 1
                }
            } else {
                all.append(TimeMailboxLetter(
                    id: sanitized.id,
                    recipientName: sanitized.recipientName,
                    title: sanitized.title,
                    body: "",
                    createdAt: sanitized.createdAt,
                    deliverAt: sanitized.deliverAt,
                    deliveredAt: sanitized.deliveredAt,
                    status: sanitized.status,
                    replyText: nil,
                    boundaryAcknowledged: sanitized.boundaryAcknowledged,
                    privacyMetadata: sanitized.privacyMetadata
                ))
                changedCount += 1
            }
        }

        if changedCount > 0 {
            save(all)
        }
        return changedCount
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

    private static func isLegacySeedLetter(_ letter: TimeMailboxLetter) -> Bool {
        letter.id.hasPrefix("roadshow_")
    }

    private static func isGenericKinshipRecipient(_ recipientName: String) -> Bool {
        genericKinshipNames.contains(recipientName.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    private static func sanitizedRemoteMetadata(_ item: TimeMailboxLetterMetadata) -> TimeMailboxLetterMetadata? {
        let cleanID = item.id.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanRecipient = item.recipientName.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanTitle = item.title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanID.isEmpty,
              !cleanRecipient.isEmpty,
              !isGenericKinshipRecipient(cleanRecipient) else {
            return nil
        }
        return TimeMailboxLetterMetadata(
            id: cleanID,
            recipientName: cleanRecipient,
            title: cleanTitle.isEmpty ? "给\(cleanRecipient)的一封信" : cleanTitle,
            createdAt: item.createdAt,
            deliverAt: item.deliverAt,
            deliveredAt: item.deliveredAt,
            status: item.status,
            boundaryAcknowledged: item.boundaryAcknowledged,
            privacyMetadata: item.privacyMetadata
        )
    }

    private static let genericKinshipNames: Set<String> = [
        "爷爷", "奶奶", "外婆", "外公", "姥姥", "姥爷",
        "爸爸", "妈妈", "父亲", "母亲",
        "老伴", "老公", "老婆", "丈夫", "妻子",
        "哥哥", "姐姐", "弟弟", "妹妹",
        "叔叔", "阿姨", "舅舅", "姑姑",
        "儿子", "女儿", "孙子", "孙女"
    ]
}

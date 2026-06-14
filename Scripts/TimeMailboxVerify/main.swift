import Foundation

private func assertCondition(_ condition: @autoclosure () -> Bool, _ message: String) {
    guard condition() else {
        fputs("FAIL: \(message)\n", stderr)
        exit(1)
    }
}

private let suiteName = "TimeMailboxVerify"
let defaults = UserDefaults(suiteName: suiteName)!
defaults.removePersistentDomain(forName: suiteName)

let repo = TimeMailboxRepository(defaults: defaults, storageKey: "letters", minimumDeliveryDelay: 60)
let now = Date(timeIntervalSince1970: 1_800_000_000)

do {
    assertCondition(
        PrivacyScopePolicy.canUse(scope: .generationAllowed, surface: .timeMailboxEcho),
        "generationAllowed memories should be usable by on-device time mailbox echo"
    )
    assertCondition(
        !PrivacyScopePolicy.canUse(scope: .familyCircle, surface: .timeMailboxEcho),
        "familyCircle memories should not be used by time mailbox echo by default"
    )

    let letter = try repo.createLetter(
        recipientName: "妈妈",
        title: "今天很想你",
        body: "我今天路过老房子，想起你做饭的味道。",
        deliverAt: now.addingTimeInterval(60),
        now: now,
        boundaryAcknowledged: true,
        privacyMetadata: MemoryPrivacyMetadata(scope: .familyCircle)
    )

    assertCondition(letter.status == .sealed, "new letter should start sealed")
    assertCondition(letter.privacyMetadata.scope == .familyCircle, "letter should persist explicit family scope")
    assertCondition(repo.letters().count == 1, "letter should persist")
    assertCondition(repo.refreshDelivery(now: now).isEmpty, "letter should not deliver before deliverAt")

    let delivered = repo.refreshDelivery(now: now.addingTimeInterval(61))
    assertCondition(delivered.count == 1, "one due letter should deliver")
    assertCondition(delivered[0].status == .delivered, "due letter should become delivered")
    assertCondition(delivered[0].replyText?.contains("基于你留下的记忆") == true, "reply must carry memory-boundary wording")
    assertCondition(delivered[0].replyText?.contains("不是逝者真实回复") == true, "reply must avoid resurrection framing")
    assertCondition(delivered[0].replyText?.contains("不会替Ta编造具体经历") == true, "reply without evidence should refuse fabrication")
    assertCondition(delivered[0].replyText?.contains("我今天路过老房子") != true, "reply must not echo the private letter body")

    try repo.markRead(id: letter.id)
    assertCondition(repo.letters().first?.status == .read, "delivered letter should be markable as read")

    try repo.delete(id: letter.id)
    assertCondition(repo.letters().isEmpty, "deleted letter should be removed")

    do {
        _ = try repo.createLetter(
            recipientName: " ",
            title: "无效",
            body: "内容",
            deliverAt: now,
            now: now,
            boundaryAcknowledged: true,
            privacyMetadata: MemoryPrivacyMetadata(scope: .generationAllowed)
        )
        assertCondition(false, "blank recipient should throw")
    } catch TimeMailboxRepositoryError.invalidRecipient {
        assertCondition(true, "blank recipient throws expected error")
    }

    do {
        _ = try repo.createLetter(
            recipientName: "妈妈",
            title: "无效",
            body: "内容",
            deliverAt: now,
            now: now,
            boundaryAcknowledged: false,
            privacyMetadata: MemoryPrivacyMetadata(scope: .localOnly)
        )
        assertCondition(false, "missing boundary acknowledgement should throw")
    } catch TimeMailboxRepositoryError.boundaryNotAcknowledged {
        assertCondition(true, "missing boundary acknowledgement throws expected error")
    }

    let defaultLetter = try repo.createLetter(
        recipientName: "爸爸",
        title: "",
        body: "默认只保存在本机。",
        deliverAt: now,
        now: now,
        boundaryAcknowledged: true
    )
    assertCondition(defaultLetter.privacyMetadata.scope == .localOnly, "default letter scope should be localOnly")
    assertCondition(
        defaultLetter.deliverAt.timeIntervalSince(now) >= 60,
        "repository should clamp immediate mailbox letters to at least one minute later"
    )
    assertCondition(
        repo.refreshDelivery(now: now.addingTimeInterval(1)).isEmpty,
        "clamped mailbox letter should not deliver one second after sealing"
    )
    try repo.delete(id: defaultLetter.id)

    let productionDefaults = UserDefaults(suiteName: "\(suiteName).productionDelay")!
    productionDefaults.removePersistentDomain(forName: "\(suiteName).productionDelay")
    let productionRepo = TimeMailboxRepository(defaults: productionDefaults, storageKey: "letters")
    let productionDefaultLetter = try productionRepo.createLetter(
        recipientName: "妈妈",
        title: "真实投递节奏",
        body: "真实路径不应像即时聊天一样立刻回信。",
        deliverAt: now,
        now: now,
        boundaryAcknowledged: true
    )
    assertCondition(
        productionDefaultLetter.deliverAt.timeIntervalSince(now) >= TimeMailboxRepository.defaultMinimumDeliveryDelay,
        "production repository should clamp immediate mailbox letters to the default five-minute delay"
    )
    assertCondition(
        productionRepo.refreshDelivery(now: now.addingTimeInterval(61)).isEmpty,
        "production mailbox letter should not deliver after the old one-minute roadshow shortcut"
    )
    productionDefaults.removePersistentDomain(forName: "\(suiteName).productionDelay")

    let realSimilarToOldSeed = try repo.createLetter(
        recipientName: "爷爷",
        title: "写给爷爷的一封信",
        body: "1975 年外滩那张合影是我们家的真实记忆，不是演示数据。",
        deliverAt: now.addingTimeInterval(120),
        now: now,
        boundaryAcknowledged: true,
        privacyMetadata: MemoryPrivacyMetadata(scope: .localOnly)
    )
    let reloadedRepo = TimeMailboxRepository(defaults: defaults, storageKey: "letters")
    assertCondition(
        reloadedRepo.letters().contains(where: { $0.id == realSimilarToOldSeed.id }),
        "real mailbox letters should not be deleted only because their content resembles old demo seed"
    )
    try repo.delete(id: realSimilarToOldSeed.id)

    let evidenceLetter = try repo.createLetter(
        recipientName: "妈妈",
        title: "想起西湖边的小照相馆",
        body: "我今天又想起桂花糕和西湖边的小照相馆。",
        deliverAt: now.addingTimeInterval(60),
        now: now,
        boundaryAcknowledged: true,
        privacyMetadata: MemoryPrivacyMetadata(scope: .generationAllowed)
    )
    let evidenceDelivered = repo.refreshDelivery(now: now.addingTimeInterval(61)) { _ in
        TimeMailboxEchoEvidence(
            people: ["妈妈：喜欢做桂花糕"],
            places: ["杭州西湖：一家人常去散步"],
            events: ["西湖边的小照相馆：1978年开过一家小店"],
            facts: ["妈妈做的桂花糕是家里常被提起的味道"]
        )
    }
    assertCondition(evidenceDelivered.count == 1, "evidence letter should deliver")
    assertCondition(evidenceDelivered[0].id == evidenceLetter.id, "delivered evidence letter should match")
    assertCondition(evidenceDelivered[0].replyText?.contains("我能参考到的已授权记忆") == true, "reply should disclose authorized evidence")
    assertCondition(evidenceDelivered[0].replyText?.contains("妈妈做的桂花糕") == true, "reply should include supplied evidence")
    assertCondition(evidenceDelivered[0].replyText?.contains("不是逝者真实回复") == true, "evidence reply must keep boundary wording")
    assertCondition(evidenceDelivered[0].replyText?.contains("我今天又想起桂花糕") != true, "evidence reply must not echo the private letter body")

    let legacyJSON = """
    [{
      "id":"legacy-letter",
      "recipientName":"妈妈",
      "title":"旧信",
      "body":"旧内容",
      "createdAt":"2026-01-01T00:00:00Z",
      "deliverAt":"2026-01-02T00:00:00Z",
      "status":"sealed",
      "boundaryAcknowledged":true
    }]
    """.data(using: .utf8)!
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    let legacyLetters = try decoder.decode([TimeMailboxLetter].self, from: legacyJSON)
    assertCondition(legacyLetters.first?.privacyMetadata.scope == .localOnly, "legacy mailbox letter should migrate to localOnly")
} catch {
    fputs("FAIL: unexpected error \(error)\n", stderr)
    exit(1)
}

print("TimeMailbox verification passed")

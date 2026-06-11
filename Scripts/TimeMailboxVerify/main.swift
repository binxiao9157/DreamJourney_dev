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

let repo = TimeMailboxRepository(defaults: defaults, storageKey: "letters")
let now = Date(timeIntervalSince1970: 1_800_000_000)

do {
    let letter = try repo.createLetter(
        recipientName: "妈妈",
        title: "今天很想你",
        body: "我今天路过老房子，想起你做饭的味道。",
        deliverAt: now.addingTimeInterval(60),
        now: now,
        boundaryAcknowledged: true
    )

    assertCondition(letter.status == .sealed, "new letter should start sealed")
    assertCondition(repo.letters().count == 1, "letter should persist")
    assertCondition(repo.refreshDelivery(now: now).isEmpty, "letter should not deliver before deliverAt")

    let delivered = repo.refreshDelivery(now: now.addingTimeInterval(61))
    assertCondition(delivered.count == 1, "one due letter should deliver")
    assertCondition(delivered[0].status == .delivered, "due letter should become delivered")
    assertCondition(delivered[0].replyText?.contains("基于你留下的记忆") == true, "reply must carry memory-boundary wording")
    assertCondition(delivered[0].replyText?.contains("不是逝者真实回复") == true, "reply must avoid resurrection framing")

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
            boundaryAcknowledged: true
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
            boundaryAcknowledged: false
        )
        assertCondition(false, "missing boundary acknowledgement should throw")
    } catch TimeMailboxRepositoryError.boundaryNotAcknowledged {
        assertCondition(true, "missing boundary acknowledgement throws expected error")
    }
} catch {
    fputs("FAIL: unexpected error \(error)\n", stderr)
    exit(1)
}

print("TimeMailbox verification passed")

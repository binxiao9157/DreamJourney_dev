import Foundation

enum MessageKind: String, CaseIterable {
    case familyInvitation
    case careSignal
    case echoReply
    case systemNotice
    case timeLetter
}

enum MessageState: String {
    case unread
    case read
    case archived
}

struct Lease: Equatable {
    let subjectId: String
    let vaultId: String
    let sessionId: String
    let generation: UInt64
    let generationId: UUID
    let authorityEpoch: String
}

struct Runtime {
    var active: Lease

    func allows(_ lease: Lease) -> Bool {
        active.subjectId == lease.subjectId
            && active.vaultId == lease.vaultId
            && active.generation == lease.generation
            && active.generationId == lease.generationId
            && active.authorityEpoch == lease.authorityEpoch
    }
}

struct Message: Equatable {
    let id: String
    let kind: MessageKind
    var state: MessageState
}

struct MessageSources {
    let familyInvitations: [String]
    let careSignals: [String]
    let echoReplies: [String]
    let systemNotices: [String]
    let timeLetters: [String]

    var completeMessages: [Message] {
        messages(familyInvitations, kind: .familyInvitation)
            + messages(careSignals, kind: .careSignal)
            + messages(echoReplies, kind: .echoReply)
            + messages(systemNotices, kind: .systemNotice)
            + messages(timeLetters, kind: .timeLetter)
    }

    private func messages(_ ids: [String], kind: MessageKind) -> [Message] {
        ids.map { Message(id: $0, kind: kind, state: .unread) }
    }
}

struct RepositoryModel {
    let sourcesBySubject: [String: MessageSources]
    private(set) var states: [String: MessageState] = [:]
    var nextMutationSucceeds = true

    func snapshot(accountLease: Lease, runtime: Runtime) -> [Message]? {
        guard runtime.allows(accountLease),
              let sources = sourcesBySubject[accountLease.subjectId] else {
            return nil
        }
        let messages = sources.completeMessages.map { message -> Message in
            var updated = message
            updated.state = states[stateKey(message.id, lease: accountLease)] ?? message.state
            return updated
        }
        guard runtime.allows(accountLease) else { return nil }
        return messages
    }

    mutating func markRead(messageId: String, accountLease: Lease, runtime: Runtime) -> Bool {
        mutate(messageId: messageId, state: .read, accountLease: accountLease, runtime: runtime)
    }

    mutating func archive(messageId: String, accountLease: Lease, runtime: Runtime) -> Bool {
        mutate(messageId: messageId, state: .archived, accountLease: accountLease, runtime: runtime)
    }

    private mutating func mutate(
        messageId: String,
        state: MessageState,
        accountLease: Lease,
        runtime: Runtime
    ) -> Bool {
        guard runtime.allows(accountLease), nextMutationSucceeds else {
            nextMutationSucceeds = true
            return false
        }
        guard let sourceMessages = sourcesBySubject[accountLease.subjectId]?.completeMessages,
              sourceMessages.contains(where: { $0.id == messageId }) else {
            return false
        }
        let key = stateKey(messageId, lease: accountLease)
        let previous = states[key]
        states[key] = state
        guard runtime.allows(accountLease) else {
            states[key] = previous
            return false
        }
        return true
    }

    private func stateKey(_ messageId: String, lease: Lease) -> String {
        [
            lease.subjectId,
            lease.vaultId,
            String(lease.generation),
            lease.generationId.uuidString,
            lease.authorityEpoch,
            messageId,
        ].joined(separator: ".")
    }
}

struct SnapshotProvider {
    let accountLease: Lease

    func load(repository: RepositoryModel, runtime: Runtime) -> [Message]? {
        guard runtime.allows(accountLease) else { return nil }
        let snapshot = repository.snapshot(accountLease: accountLease, runtime: runtime)
        guard runtime.allows(accountLease) else { return nil }
        return snapshot
    }
}

struct MessagePage {
    let accountLease: Lease
    let snapshotProvider: SnapshotProvider
    private(set) var messages: [Message] = []

    init(accountLease: Lease) {
        self.accountLease = accountLease
        snapshotProvider = SnapshotProvider(accountLease: accountLease)
    }

    mutating func refresh(repository: RepositoryModel, runtime: Runtime) -> Bool {
        guard let snapshot = snapshotProvider.load(repository: repository, runtime: runtime) else {
            messages = []
            return false
        }
        messages = snapshot
        return true
    }

    mutating func markRead(
        messageId: String,
        repository: inout RepositoryModel,
        runtime: Runtime
    ) -> Bool {
        guard repository.markRead(
            messageId: messageId,
            accountLease: accountLease,
            runtime: runtime
        ) else {
            return false
        }
        return refresh(repository: repository, runtime: runtime)
    }

    mutating func archive(
        messageId: String,
        repository: inout RepositoryModel,
        runtime: Runtime
    ) -> Bool {
        guard repository.archive(
            messageId: messageId,
            accountLease: accountLease,
            runtime: runtime
        ) else {
            return false
        }
        return refresh(repository: repository, runtime: runtime)
    }
}

let generationA = UUID()
let leaseA = Lease(
    subjectId: "account-a",
    vaultId: "vault-a",
    sessionId: "session-a-1",
    generation: 1,
    generationId: generationA,
    authorityEpoch: "epoch-1"
)
let leaseASessionRefreshed = Lease(
    subjectId: leaseA.subjectId,
    vaultId: leaseA.vaultId,
    sessionId: "session-a-2",
    generation: leaseA.generation,
    generationId: leaseA.generationId,
    authorityEpoch: leaseA.authorityEpoch
)
let leaseANextGeneration = Lease(
    subjectId: leaseA.subjectId,
    vaultId: leaseA.vaultId,
    sessionId: "session-a-3",
    generation: 2,
    generationId: UUID(),
    authorityEpoch: leaseA.authorityEpoch
)
let leaseASameGenerationNewIdentity = Lease(
    subjectId: leaseA.subjectId,
    vaultId: leaseA.vaultId,
    sessionId: "session-a-4",
    generation: leaseA.generation,
    generationId: UUID(),
    authorityEpoch: leaseA.authorityEpoch
)
let leaseB = Lease(
    subjectId: "account-b",
    vaultId: "vault-b",
    sessionId: "session-b-1",
    generation: 1,
    generationId: UUID(),
    authorityEpoch: "epoch-1"
)

let sourcesA = MessageSources(
    familyInvitations: ["a-family"],
    careSignals: ["a-care"],
    echoReplies: ["a-echo"],
    systemNotices: ["a-system"],
    timeLetters: ["a-time-letter"]
)
let sourcesB = MessageSources(
    familyInvitations: ["b-family"],
    careSignals: ["b-care"],
    echoReplies: ["b-echo"],
    systemNotices: ["b-system"],
    timeLetters: ["b-time-letter"]
)
let expectedAIds = Set(sourcesA.completeMessages.map(\.id))
let expectedBIds = Set(sourcesB.completeMessages.map(\.id))

var runtime = Runtime(active: leaseA)
var repository = RepositoryModel(sourcesBySubject: [
    leaseA.subjectId: sourcesA,
    leaseB.subjectId: sourcesB,
])
var pageA = MessagePage(accountLease: leaseA)

precondition(pageA.refresh(repository: repository, runtime: runtime))
precondition(Set(pageA.messages.map(\.id)) == expectedAIds)
precondition(Set(pageA.messages.map(\.kind)) == Set(MessageKind.allCases))

let beforeFailedRead = pageA.messages
repository.nextMutationSucceeds = false
precondition(!pageA.markRead(messageId: "a-family", repository: &repository, runtime: runtime))
precondition(pageA.messages == beforeFailedRead)

precondition(pageA.markRead(messageId: "a-family", repository: &repository, runtime: runtime))
precondition(pageA.messages.first(where: { $0.id == "a-family" })?.state == .read)
precondition(Set(pageA.messages.map(\.id)) == expectedAIds)

let beforeFailedArchive = pageA.messages
repository.nextMutationSucceeds = false
precondition(!pageA.archive(messageId: "a-family", repository: &repository, runtime: runtime))
precondition(pageA.messages == beforeFailedArchive)

precondition(pageA.archive(messageId: "a-family", repository: &repository, runtime: runtime))
precondition(pageA.messages.first(where: { $0.id == "a-family" })?.state == .archived)
precondition(Set(pageA.messages.map(\.id)) == expectedAIds)

runtime.active = leaseB
precondition(!pageA.refresh(repository: repository, runtime: runtime))
precondition(pageA.messages.isEmpty)
var pageB = MessagePage(accountLease: leaseB)
precondition(pageB.refresh(repository: repository, runtime: runtime))
precondition(Set(pageB.messages.map(\.id)) == expectedBIds)
precondition(Set(pageB.messages.map(\.id)).isDisjoint(with: expectedAIds))

runtime.active = leaseANextGeneration
precondition(!runtime.allows(leaseA))
precondition(!pageA.refresh(repository: repository, runtime: runtime))
precondition(pageA.messages.isEmpty)

runtime.active = leaseASameGenerationNewIdentity
precondition(!runtime.allows(leaseA))
precondition(!pageA.refresh(repository: repository, runtime: runtime))

runtime.active = leaseASessionRefreshed
precondition(runtime.allows(leaseA))
precondition(pageA.refresh(repository: repository, runtime: runtime))
precondition(Set(pageA.messages.map(\.id)) == expectedAIds)
precondition(pageA.messages.first(where: { $0.id == "a-family" })?.state == .archived)

print("In-app message page AccountLease model smoke passed")

import Foundation

// Compile-only carriers keep this smoke focused on InAppMessageCenter.swift.
enum AccountLeaseCheckpoint {
    case request
    case commit
    case ui
    case timer
    case runtime
}

struct AccountLeaseValidationDecision {
    let allowed: Bool
}

struct AccountLease: Equatable {
    let subjectId: String
    let vaultId: String
    let sessionId: String
    let generation: UInt64
    let generationId: UUID
    let authorityEpoch: String
}

protocol AccountLeaseRuntimePort {
    func capture(forSubjectId subjectId: String?) -> AccountLease?
    func validate(
        _ lease: AccountLease,
        at checkpoint: AccountLeaseCheckpoint
    ) -> AccountLeaseValidationDecision
}

final class AccountLeaseRuntime: AccountLeaseRuntimePort {
    static let shared = AccountLeaseRuntime()

    func capture(forSubjectId subjectId: String?) -> AccountLease? { nil }

    func validate(
        _ lease: AccountLease,
        at checkpoint: AccountLeaseCheckpoint
    ) -> AccountLeaseValidationDecision {
        AccountLeaseValidationDecision(allowed: false)
    }
}

struct TimeLetterMailboxReminder: Codable {
    let id: String
    let title: String
    let status: String
    let deliveredAt: String
    let readAt: String?
    let archivedAt: String?
    let sourceArchiveItemId: String
    let ownerUserId: String
    let recipientRole: String
}

// InAppMessageCenter adds the resource-owner conformance used by production.
struct FamilyMember {
    let relationshipOwnerUserId: String
}

private final class MutableLeaseRuntime: AccountLeaseRuntimePort {
    var activeLease: AccountLease?
    var beforeValidation: ((AccountLeaseCheckpoint, Int) -> Void)?
    private var validationCounts: [String: Int] = [:]

    init(activeLease: AccountLease?) {
        self.activeLease = activeLease
    }

    func capture(forSubjectId subjectId: String?) -> AccountLease? {
        guard let activeLease,
              subjectId == nil || subjectId == activeLease.subjectId else {
            return nil
        }
        return activeLease
    }

    func validate(
        _ lease: AccountLease,
        at checkpoint: AccountLeaseCheckpoint
    ) -> AccountLeaseValidationDecision {
        let key = String(describing: checkpoint)
        let count = validationCounts[key, default: 0] + 1
        validationCounts[key] = count
        beforeValidation?(checkpoint, count)
        return AccountLeaseValidationDecision(
            allowed: lease.subjectId == activeLease?.subjectId
                && lease.vaultId == activeLease?.vaultId
                && lease.generation == activeLease?.generation
                && lease.generationId == activeLease?.generationId
                && lease.authorityEpoch == activeLease?.authorityEpoch
        )
    }

    func resetValidationHook() {
        validationCounts = [:]
        beforeValidation = nil
    }
}

private struct FamilyInvitationFixture: FamilyInvitationMessageSource {
    let familyMemberId: String
    let familyMemberName: String
    let familyMemberRelation: String
    let familyMemberPhone: String?
    let familyInvitationStatus: String
    let familyAccessStatus: String
    let familyInvitationError: String?
    let familyLastUpdated: String
    let isAcceptedFamilyMember: Bool
}

private func require(
    _ condition: @autoclosure () -> Bool,
    _ message: String
) {
    guard condition() else { fatalError(message) }
}

private func makeLease(
    subjectId: String,
    vaultId: String,
    sessionId: String? = nil,
    generation: UInt64 = 1,
    generationId: UUID = UUID(),
    authorityEpoch: String = "epoch-a"
) -> AccountLease {
    AccountLease(
        subjectId: subjectId,
        vaultId: vaultId,
        sessionId: sessionId ?? "session-\(subjectId)-\(generation)",
        generation: generation,
        generationId: generationId,
        authorityEpoch: authorityEpoch
    )
}

private func makeNotice(
    id: String = "shared-source-id",
    title: String,
    resourceOwnerId: String? = nil
) -> StaticSystemNoticeMessageSource {
    StaticSystemNoticeMessageSource(
        systemNoticeId: id,
        systemNoticeTitle: title,
        systemNoticeSummary: "summary-\(title)",
        systemNoticeStatus: "published",
        systemNoticeCategory: "account",
        systemNoticeSeverity: "info",
        systemNoticeUpdatedAt: "2026-07-18T00:00:00Z",
        resourceOwnerId: resourceOwnerId
    )
}

private func makeReply(
    id: String = "shared-source-id",
    title: String,
    resourceOwnerId: String? = nil
) -> StaticEchoReplyMessageSource {
    StaticEchoReplyMessageSource(
        echoReplyId: id,
        echoReplyTitle: title,
        echoReplySummary: "summary-\(title)",
        echoReplyStatus: "unread",
        echoReplyDeliveredAt: "2026-07-18T00:00:00Z",
        echoReplyTrigger: "contentSignal",
        resourceOwnerId: resourceOwnerId
    )
}

private func makeDefaults(_ label: String) -> UserDefaults {
    let suiteName = "in-app-message-owner-scope-smoke.\(label).\(UUID().uuidString)"
    guard let defaults = UserDefaults(suiteName: suiteName) else {
        fatalError("failed to create isolated defaults")
    }
    defaults.removePersistentDomain(forName: suiteName)
    return defaults
}

@main
private enum InAppMessageOwnerScopeModelSmoke {
    static func main() throws {
        verifyKeyBindsCompleteIdentity()
        verifySessionRotationPreservesGenerationScope()
        verifyMailboxGenerationScope()
        verifyAccountAndOperationIsolation()
        verifyGenerationAndStaleOperationsFailClosed()
        try verifyLegacyArraysAreQuarantinedWithoutOwnerAssignment()
        verifyOwnerProjectionAndStateBoundaries()
        print("In-app message owner scope model smoke passed")
    }

    private static func verifyKeyBindsCompleteIdentity() {
        let generationId = UUID()
        let lease = makeLease(
            subjectId: "account-a",
            vaultId: "vault-a",
            sessionId: "session-a",
            generation: 7,
            generationId: generationId,
            authorityEpoch: "epoch-a"
        )
        let base = InAppMessageOwnerScope(
            accountLease: lease,
            resourceOwnerId: "resource-a",
            operationId: "operation-a"
        )
        let baseKey = base.storageKey(for: .systemNotice)

        let sessionRotated = InAppMessageOwnerScope(
            accountLease: makeLease(
                subjectId: lease.subjectId,
                vaultId: lease.vaultId,
                sessionId: "session-b",
                generation: lease.generation,
                generationId: lease.generationId,
                authorityEpoch: lease.authorityEpoch
            ),
            resourceOwnerId: base.resourceOwnerId,
            operationId: base.operationId
        )
        let variants: [InAppMessageOwnerScope] = [
            InAppMessageOwnerScope(
                accountLease: makeLease(
                    subjectId: "account-b",
                    vaultId: lease.vaultId,
                    sessionId: lease.sessionId,
                    generation: lease.generation,
                    generationId: lease.generationId,
                    authorityEpoch: lease.authorityEpoch
                ),
                resourceOwnerId: base.resourceOwnerId,
                operationId: base.operationId
            ),
            InAppMessageOwnerScope(
                accountLease: makeLease(
                    subjectId: lease.subjectId,
                    vaultId: "vault-b",
                    sessionId: lease.sessionId,
                    generation: lease.generation,
                    generationId: lease.generationId,
                    authorityEpoch: lease.authorityEpoch
                ),
                resourceOwnerId: base.resourceOwnerId,
                operationId: base.operationId
            ),
            InAppMessageOwnerScope(
                accountLease: makeLease(
                    subjectId: lease.subjectId,
                    vaultId: lease.vaultId,
                    sessionId: lease.sessionId,
                    generation: 8,
                    generationId: lease.generationId,
                    authorityEpoch: lease.authorityEpoch
                ),
                resourceOwnerId: base.resourceOwnerId,
                operationId: base.operationId
            ),
            InAppMessageOwnerScope(
                accountLease: makeLease(
                    subjectId: lease.subjectId,
                    vaultId: lease.vaultId,
                    sessionId: lease.sessionId,
                    generation: lease.generation,
                    generationId: UUID(),
                    authorityEpoch: lease.authorityEpoch
                ),
                resourceOwnerId: base.resourceOwnerId,
                operationId: base.operationId
            ),
            InAppMessageOwnerScope(
                accountLease: makeLease(
                    subjectId: lease.subjectId,
                    vaultId: lease.vaultId,
                    sessionId: lease.sessionId,
                    generation: lease.generation,
                    generationId: lease.generationId,
                    authorityEpoch: "epoch-b"
                ),
                resourceOwnerId: base.resourceOwnerId,
                operationId: base.operationId
            ),
            InAppMessageOwnerScope(
                accountLease: lease,
                resourceOwnerId: "resource-b",
                operationId: base.operationId
            ),
            InAppMessageOwnerScope(
                accountLease: lease,
                resourceOwnerId: base.resourceOwnerId,
                operationId: "operation-b"
            ),
        ]

        require(base.isValid, "complete owner scope should be valid")
        require(
            sessionRotated.storageKey(for: .systemNotice) == baseKey,
            "token refresh session rotation must preserve the account generation storage scope"
        )
        require(
            variants.allSatisfy { $0.storageKey(for: .systemNotice) != baseKey },
            "every AccountLease/resource owner/operation field must bind the storage key"
        )
        require(
            base.storageKey(for: .echoReply) != baseKey,
            "message surfaces must not share scoped keys"
        )
    }

    private static func verifySessionRotationPreservesGenerationScope() {
        let defaults = makeDefaults("session-rotation")
        let generationId = UUID()
        let originalLease = makeLease(
            subjectId: "account-a",
            vaultId: "vault-a",
            sessionId: "session-a",
            generation: 9,
            generationId: generationId
        )
        let refreshedLease = makeLease(
            subjectId: originalLease.subjectId,
            vaultId: originalLease.vaultId,
            sessionId: "session-b",
            generation: originalLease.generation,
            generationId: originalLease.generationId,
            authorityEpoch: originalLease.authorityEpoch
        )
        let runtime = MutableLeaseRuntime(activeLease: originalLease)
        let store = SystemNoticeMessageStore(defaults: defaults, accountLeaseRuntime: runtime)
        let owner = "resource-a"
        let operation = "refresh-a"
        require(
            store.save(
                [makeNotice(title: "survives-refresh")],
                accountLease: originalLease,
                resourceOwnerId: owner,
                operationId: operation
            ),
            "pre-refresh save failed"
        )
        runtime.activeLease = refreshedLease
        require(
            store.sources(
                accountLease: refreshedLease,
                resourceOwnerId: owner,
                operationId: operation
            ).count == 1,
            "same-generation token refresh must preserve message visibility"
        )
    }

    private static func verifyMailboxGenerationScope() {
        let defaults = makeDefaults("mailbox-generation")
        let generationId = UUID()
        let originalLease = makeLease(
            subjectId: "account-a",
            vaultId: "vault-a",
            sessionId: "session-a",
            generation: 11,
            generationId: generationId
        )
        let originalScope = InAppMessageOwnerScope(
            accountLease: originalLease,
            resourceOwnerId: originalLease.subjectId,
            operationId: "time-letter-mailbox"
        )
        let reminder = TimeLetterMailboxReminder(
            id: "letter-a",
            title: "Letter",
            status: "unread",
            deliveredAt: "2026-07-18T00:00:00Z",
            readAt: nil,
            archivedAt: nil,
            sourceArchiveItemId: "archive-a",
            ownerUserId: "account-a",
            recipientRole: "owner"
        )
        let data = try! JSONEncoder().encode(
            InAppMessageSourceEnvelope(sources: [reminder], scope: originalScope)
        )
        defaults.set(data, forKey: originalScope.storageKey(for: .timeLetterMailbox))

        let refreshedSessionScope = InAppMessageOwnerScope(
            accountLease: makeLease(
                subjectId: originalLease.subjectId,
                vaultId: originalLease.vaultId,
                sessionId: "session-b",
                generation: originalLease.generation,
                generationId: originalLease.generationId
            ),
            resourceOwnerId: originalLease.subjectId,
            operationId: "time-letter-mailbox"
        )
        let refreshedData = defaults.data(
            forKey: refreshedSessionScope.storageKey(for: .timeLetterMailbox)
        )
        let refreshedEnvelope = refreshedData.flatMap {
            try? JSONDecoder().decode(
                InAppMessageSourceEnvelope<TimeLetterMailboxReminder>.self,
                from: $0
            )
        }
        require(
            refreshedEnvelope?.matches(refreshedSessionScope) == true,
            "session refresh must preserve the same generation mailbox"
        )

        let nextGenerationScope = InAppMessageOwnerScope(
            accountLease: makeLease(
                subjectId: originalLease.subjectId,
                vaultId: originalLease.vaultId,
                sessionId: "session-c",
                generation: originalLease.generation + 1,
                generationId: UUID()
            ),
            resourceOwnerId: originalLease.subjectId,
            operationId: "time-letter-mailbox"
        )
        require(
            nextGenerationScope.storageKey(for: .timeLetterMailbox)
                != originalScope.storageKey(for: .timeLetterMailbox),
            "same-subject generation rotation must isolate mailbox storage"
        )
        require(
            defaults.data(forKey: nextGenerationScope.storageKey(for: .timeLetterMailbox)) == nil,
            "a new account generation must not mount the previous mailbox"
        )
    }

    private static func verifyAccountAndOperationIsolation() {
        let defaults = makeDefaults("account-isolation")
        let leaseA = makeLease(subjectId: "account-a", vaultId: "vault-a")
        let leaseB = makeLease(subjectId: "account-b", vaultId: "vault-b")
        let runtime = MutableLeaseRuntime(activeLease: leaseA)
        let store = SystemNoticeMessageStore(
            defaults: defaults,
            accountLeaseRuntime: runtime
        )

        require(
            store.save(
                [makeNotice(title: "notice-a")],
                accountLease: leaseA,
                resourceOwnerId: "resource-a",
                operationId: "inbox-refresh"
            ),
            "account A notice save should succeed"
        )
        runtime.activeLease = leaseB
        require(
            store.save(
                [makeNotice(title: "notice-b")],
                accountLease: leaseB,
                resourceOwnerId: "resource-b",
                operationId: "inbox-refresh"
            ),
            "account B may save the same source id in its own scope"
        )
        let noticesB = store.sources(
            accountLease: leaseB,
            resourceOwnerId: "resource-b",
            operationId: "inbox-refresh"
        )
        require(noticesB.count == 1, "account B scoped notice is missing")
        require(noticesB[0].systemNoticeTitle == "notice-b", "account B read leaked account A")
        require(
            InAppMessage.fromSystemNotice(noticesB[0])?.ownerUserId == "resource-b",
            "system notice must project its resource owner"
        )
        require(
            store.sources(
                accountLease: leaseB,
                resourceOwnerId: "resource-b",
                operationId: "different-operation"
            ).isEmpty,
            "operation scopes must not share messages"
        )

        runtime.activeLease = leaseA
        let noticesA = store.sources(
            accountLease: leaseA,
            resourceOwnerId: "resource-a",
            operationId: "inbox-refresh"
        )
        require(noticesA.count == 1, "account A scoped notice is missing")
        require(noticesA[0].systemNoticeTitle == "notice-a", "account B overwrote account A")
        require(
            !store.save(
                [makeNotice(title: "invalid")],
                accountLease: leaseA,
                resourceOwnerId: "",
                operationId: "inbox-refresh"
            ),
            "empty resource owners must fail closed"
        )
        require(
            !store.clear(
                accountLease: leaseA,
                resourceOwnerId: "resource-a",
                operationId: ""
            ),
            "empty operation ids must fail closed"
        )
    }

    private static func verifyGenerationAndStaleOperationsFailClosed() {
        let defaults = makeDefaults("stale-operations")
        let generationId = UUID()
        let leaseA = makeLease(
            subjectId: "account-a",
            vaultId: "vault-a",
            generation: 1,
            generationId: generationId
        )
        let leaseANext = makeLease(
            subjectId: "account-a",
            vaultId: "vault-a",
            generation: 2,
            generationId: UUID()
        )
        let leaseB = makeLease(subjectId: "account-b", vaultId: "vault-b")
        let runtime = MutableLeaseRuntime(activeLease: leaseA)
        let store = SystemNoticeMessageStore(defaults: defaults, accountLeaseRuntime: runtime)
        let owner = "resource-a"
        let operation = "refresh-a"

        require(
            store.save(
                [makeNotice(title: "original")],
                accountLease: leaseA,
                resourceOwnerId: owner,
                operationId: operation
            ),
            "baseline save failed"
        )

        runtime.activeLease = leaseANext
        require(
            store.sources(
                accountLease: leaseA,
                resourceOwnerId: owner,
                operationId: operation
            ).isEmpty,
            "old generation reads must fail closed"
        )
        require(
            !store.save(
                [makeNotice(title: "stale-generation")],
                accountLease: leaseA,
                resourceOwnerId: owner,
                operationId: operation
            ),
            "old generation writes must fail closed"
        )
        require(
            !store.clear(
                accountLease: leaseA,
                resourceOwnerId: owner,
                operationId: operation
            ),
            "old generation clears must fail closed"
        )
        require(
            store.sources(
                accountLease: leaseANext,
                resourceOwnerId: owner,
                operationId: operation
            ).isEmpty,
            "a new generation must not mount the previous generation payload"
        )

        runtime.activeLease = leaseA
        runtime.resetValidationHook()
        runtime.beforeValidation = { checkpoint, count in
            if checkpoint == .runtime && count == 1 {
                runtime.activeLease = leaseB
            }
        }
        require(
            store.sources(
                accountLease: leaseA,
                resourceOwnerId: owner,
                operationId: operation
            ).isEmpty,
            "a read that becomes stale before return must fail closed"
        )

        runtime.activeLease = leaseA
        runtime.resetValidationHook()
        runtime.beforeValidation = { checkpoint, count in
            if checkpoint == .commit && count == 2 {
                runtime.activeLease = leaseB
            }
        }
        require(
            !store.save(
                [makeNotice(title: "stale-write")],
                accountLease: leaseA,
                resourceOwnerId: owner,
                operationId: operation
            ),
            "a write that becomes stale at commit must report failure"
        )
        runtime.activeLease = leaseA
        runtime.resetValidationHook()
        require(
            store.sources(
                accountLease: leaseA,
                resourceOwnerId: owner,
                operationId: operation
            ).first?.systemNoticeTitle == "original",
            "a stale write must roll back its scoped payload"
        )

        runtime.resetValidationHook()
        runtime.beforeValidation = { checkpoint, count in
            if checkpoint == .commit && count == 2 {
                runtime.activeLease = leaseB
            }
        }
        require(
            !store.clear(
                accountLease: leaseA,
                resourceOwnerId: owner,
                operationId: operation
            ),
            "a clear that becomes stale at commit must report failure"
        )
        runtime.activeLease = leaseA
        runtime.resetValidationHook()
        require(
            store.sources(
                accountLease: leaseA,
                resourceOwnerId: owner,
                operationId: operation
            ).first?.systemNoticeTitle == "original",
            "a stale clear must restore the original scoped payload"
        )
    }

    private static func verifyLegacyArraysAreQuarantinedWithoutOwnerAssignment() throws {
        let lease = makeLease(subjectId: "account-a", vaultId: "vault-a")
        let runtime = MutableLeaseRuntime(activeLease: lease)

        let systemDefaults = makeDefaults("legacy-system")
        let legacyNotices = try JSONEncoder().encode([makeNotice(title: "legacy-system")])
        systemDefaults.set(legacyNotices, forKey: "dj.inAppMessage.systemNotice.sources")
        let systemStore = SystemNoticeMessageStore(
            defaults: systemDefaults,
            accountLeaseRuntime: runtime
        )
        require(
            systemStore.sources(
                accountLease: lease,
                resourceOwnerId: "current-resource-owner",
                operationId: "legacy-check"
            ).isEmpty,
            "legacy system arrays must never be assigned to the current account"
        )
        require(
            systemStore.legacyRetirementStatus() == .quarantined,
            "legacy system retirement status must be testable"
        )
        require(
            systemStore.legacyRetirementReceipt()?.ownerEvidence == "unverified",
            "legacy system receipt must record missing owner evidence"
        )
        require(
            systemStore.legacyQuarantinePayload() == legacyNotices,
            "legacy system bytes must be retained only in quarantine"
        )
        require(
            systemDefaults.data(forKey: "dj.inAppMessage.systemNotice.sources") == nil,
            "legacy system key must be retired"
        )

        let echoDefaults = makeDefaults("legacy-echo")
        let legacyReplies = try JSONEncoder().encode([makeReply(title: "legacy-echo")])
        echoDefaults.set(legacyReplies, forKey: "dj.inAppMessage.echoReply.sources")
        let echoStore = EchoReplyMessageStore(defaults: echoDefaults, accountLeaseRuntime: runtime)
        require(
            echoStore.sources(
                accountLease: lease,
                resourceOwnerId: "current-resource-owner",
                operationId: "legacy-check"
            ).isEmpty,
            "legacy echo arrays must never be assigned to the current account"
        )
        require(
            echoStore.legacyRetirementStatus() == .quarantined,
            "legacy echo retirement status must be testable"
        )
        require(
            echoStore.legacyRetirementReceipt()?.ownerEvidence == "unverified",
            "legacy echo receipt must record missing owner evidence"
        )
        require(
            echoStore.legacyQuarantinePayload() == legacyReplies,
            "legacy echo bytes must be retained only in quarantine"
        )
        require(
            echoDefaults.data(forKey: "dj.inAppMessage.echoReply.sources") == nil,
            "legacy echo key must be retired"
        )

        let scopedDefaults = makeDefaults("legacy-scoped-surfaces")
        let localStateKeyA = "dj.inAppMessage.localState.account-a"
        let localStateKeyB = "dj.inAppMessage.localState.account-b"
        let localStatePayloadA = Data("legacy-local-state-a".utf8)
        let localStatePayloadB = Data("legacy-local-state-b".utf8)
        scopedDefaults.set(localStatePayloadA, forKey: localStateKeyA)
        scopedDefaults.set(localStatePayloadB, forKey: localStateKeyB)
        require(
            InAppMessageLegacyRetirementStorage.retireIfNeeded(
                surface: .localState,
                legacyStorageKey: localStateKeyA,
                sourceItemCount: nil,
                defaults: scopedDefaults,
                namespace: "owner-a"
            ),
            "legacy local-state A should be quarantined"
        )
        require(
            InAppMessageLegacyRetirementStorage.retireIfNeeded(
                surface: .localState,
                legacyStorageKey: localStateKeyB,
                sourceItemCount: nil,
                defaults: scopedDefaults,
                namespace: "owner-b"
            ),
            "legacy local-state B should be quarantined independently"
        )
        require(
            InAppMessageLegacyRetirementStorage.quarantinePayload(
                surface: .localState,
                defaults: scopedDefaults,
                namespace: "owner-a"
            ) == localStatePayloadA,
            "local-state A quarantine must preserve only A bytes"
        )
        require(
            InAppMessageLegacyRetirementStorage.quarantinePayload(
                surface: .localState,
                defaults: scopedDefaults,
                namespace: "owner-b"
            ) == localStatePayloadB,
            "local-state B quarantine must preserve only B bytes"
        )

        let mailboxKey = "dj.memoryArchive.timeLetterMailbox.account-a"
        let mailboxPayload = Data("legacy-mailbox-a".utf8)
        scopedDefaults.set(mailboxPayload, forKey: mailboxKey)
        require(
            InAppMessageLegacyRetirementStorage.retireIfNeeded(
                surface: .timeLetterMailbox,
                legacyStorageKey: mailboxKey,
                sourceItemCount: nil,
                defaults: scopedDefaults,
                namespace: "owner-a"
            ),
            "legacy mailbox should be quarantined"
        )
        require(
            InAppMessageLegacyRetirementStorage.quarantinePayload(
                surface: .timeLetterMailbox,
                defaults: scopedDefaults,
                namespace: "owner-a"
            ) == mailboxPayload,
            "mailbox quarantine must retain the original bytes"
        )
    }

    private static func verifyOwnerProjectionAndStateBoundaries() {
        let lease = makeLease(subjectId: "account-a", vaultId: "vault-a")
        let runtime = MutableLeaseRuntime(activeLease: lease)
        let owner = "resource-owner"

        let familySource = OwnerAwareFamilyInvitationMessageSource(
            FamilyInvitationFixture(
                familyMemberId: "message-family-id",
                familyMemberName: "Family",
                familyMemberRelation: "relation",
                familyMemberPhone: nil,
                familyInvitationStatus: "pending",
                familyAccessStatus: "pending",
                familyInvitationError: nil,
                familyLastUpdated: "2026-07-18T00:00:00Z",
                isAcceptedFamilyMember: false
            ),
            resourceOwnerId: owner
        )
        require(
            InAppMessage.fromFamilyInvitation(familySource)?.ownerUserId == owner,
            "family invitation owner must come from resource-owner metadata"
        )

        let directNotice = makeNotice(
            id: "message-system-id",
            title: "direct-system",
            resourceOwnerId: owner
        )
        require(
            InAppMessage.fromSystemNotice(directNotice)?.ownerUserId == owner,
            "owner-aware direct system sources must project their owner"
        )
        require(
            InAppMessage.fromSystemNotice(makeNotice(title: "ownerless")) == nil,
            "ownerless system sources must fail closed"
        )

        let ownerlessCare = StaticCareSignalMessageSource(
            careSignalId: "ownerless-care",
            careSignalTitle: "Care",
            careSignalSummary: "summary",
            careSignalStatus: "failed",
            careSignalSeverity: "attention",
            careSignalUpdatedAt: "2026-07-18T00:00:00Z",
            careSignalOwnerUserId: nil
        )
        require(
            InAppMessage.fromCareSignal(ownerlessCare) == nil,
            "ownerless care signals must fail closed"
        )

        let echoStore = EchoReplyMessageStore(
            defaults: makeDefaults("echo-owner"),
            accountLeaseRuntime: runtime
        )
        require(
            echoStore.saveArrivedReply(
                id: "message-echo-id",
                sourceAnswerID: "answer-message-echo-id",
                deliverAt: Date(timeIntervalSince1970: 1_721_260_800),
                trigger: "contentSignal",
                accountLease: lease,
                resourceOwnerId: owner,
                operationId: "message-echo-id"
            ),
            "explicit arrived-reply save should succeed"
        )
        require(
            echoStore.saveArrivedReply(
                id: "message-echo-id-2",
                sourceAnswerID: "answer-message-echo-id-2",
                deliverAt: Date(timeIntervalSince1970: 1_721_260_801),
                trigger: "contentSignal",
                accountLease: lease,
                resourceOwnerId: owner,
                operationId: "message-echo-id-2"
            ),
            "a second arrived reply should join the same owner inbox"
        )
        let inboxSources = echoStore.inboxSources(
            accountLease: lease,
            resourceOwnerId: owner
        )
        require(inboxSources.count == 2, "owner inbox must aggregate arrived reply operations")
        guard let echoSource = inboxSources.first(where: { $0.echoReplyId == "message-echo-id" }),
              let message = InAppMessage.fromEchoReply(echoSource) else {
            fatalError("owner-aware echo source is missing")
        }
        require(message.ownerUserId == owner, "echo owner must come from the scoped envelope")
        require(message.ownerUserId != message.echoReplySourceId, "message id must not become principal")
        require(
            echoSource.echoReplySourceAnswerID == "answer-message-echo-id",
            "arrived reply must retain the server answer reference within its owner scope"
        )
        require(
            echoStore.removeArrivedReply(
                id: "message-echo-id",
                accountLease: lease,
                resourceOwnerId: owner,
                operationId: "message-echo-id"
            ),
            "arrived reply removal should succeed within the same owner scope"
        )
        require(
            echoStore.inboxSources(accountLease: lease, resourceOwnerId: owner).count == 1,
            "removing one reply must preserve the remaining owner inbox"
        )

        let read = message.markingRead(readAt: "2026-07-18T01:00:00Z")
        let archived = read.markingArchived(archivedAt: "2026-07-18T02:00:00Z")
        require(read.ownerUserId == owner, "read boundary must preserve owner metadata")
        require(archived.ownerUserId == owner, "archive boundary must preserve owner metadata")
    }
}

private extension InAppMessage {
    var echoReplySourceId: String? {
        guard kind == .echoReply else { return nil }
        return id.replacingOccurrences(of: "echo-reply-", with: "")
    }
}

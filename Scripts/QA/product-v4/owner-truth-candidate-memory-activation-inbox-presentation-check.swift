import Foundation

func read(_ path: String) throws -> String {
    try String(contentsOfFile: path, encoding: .utf8)
}

func require(_ condition: @autoclosure () -> Bool, _ message: String) {
    guard condition() else {
        fputs("owner-truth memory activation inbox presentation check failed: \(message)\n", stderr)
        exit(1)
    }
}

func slice(_ source: String, from start: String, to end: String) -> String? {
    guard let startRange = source.range(of: start),
          let endRange = source.range(of: end, range: startRange.upperBound..<source.endIndex) else {
        return nil
    }
    return String(source[startRange.lowerBound..<endRange.lowerBound])
}

let root = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent()
    .deletingLastPathComponent()
    .deletingLastPathComponent()
    .deletingLastPathComponent()
    .path

let archive = try read("\(root)/DreamJourney/Sources/Modules/Archive/MemoryArchiveViewController.swift")

for required in [
    "OwnerTruthInterviewCandidateMemoryActivationInboxViewController",
    "owner-truth-memory-activation-inbox-list",
    "owner-truth-memory-activation-inbox-status",
    "owner-truth-memory-activation-inbox-item",
    "owner-truth-memory-projection-recovery-summary",
] {
    require(archive.contains(required), "formal activation inbox presentation missing: \(required)")
}

guard let archiveEntrySection = slice(
    archive,
    from: "private func updateCandidateReviewQAButton()",
    to: "private func reloadFeatureCards"
) else {
    fatalError("owner-truth memory activation inbox presentation check failed: entry section is missing")
}
require(
    archiveEntrySection.contains("isSelfAutobiographyMode") &&
        archiveEntrySection.contains("isServerPolicyManagedRouteAllowed(.ownerTruthCandidateReview)"),
    "unified pending-memory entry must require self autobiography mode and the formal release route gate"
)
require(
    !archive.contains("candidateMemoryActivationButton") &&
        !archive.contains("ownerTruthCandidateMemoryActivationTapped"),
    "Archive must not expose a second formal-memory activation entry"
)
require(
    !archiveEntrySection.contains("qaSyntheticOverride"),
    "unified pending-memory entry must not use a synthetic release bypass"
)

guard let unifiedInboxSection = slice(
    archive,
    from: "final class OwnerTruthInterviewCandidateConfirmationInboxViewController",
    to: "private final class OwnerTruthCandidateConfirmationInboxCell"
) else {
    fatalError("owner-truth memory activation inbox presentation check failed: unified inbox is missing")
}
for required in [
    "OwnerTruthInterviewCandidateMemoryActivationInboxUseCase",
    "activationInboxUseCase.send(.refresh)",
    "case activationRecovery",
    "待完成写入",
    "OwnerTruthInterviewCandidateMemoryActivationInboxViewController",
] {
    require(unifiedInboxSection.contains(required), "unified recovery presentation missing: \(required)")
}
require(
    archive.contains("func configureRecovery()") &&
        archive.contains("继续写入正式记忆"),
    "unified recovery row must explain that formal-memory activation can be retried"
)

guard let inboxSection = slice(
    archive,
    from: "final class OwnerTruthInterviewCandidateMemoryActivationInboxViewController",
    to: "final class OwnerTruthInterviewCandidateConfirmationInboxViewController"
) else {
    fatalError("owner-truth memory activation inbox presentation check failed: inbox controller is missing")
}
for required in [
    "OwnerTruthInterviewCandidateMemoryActivationInboxUseCase",
    "OwnerTruthInterviewCandidateMemoryProjectionRecoveryInboxUseCase",
    "OwnerTruthInterviewCandidateMemoryActivationUseCase",
    "activationInbox: inbox",
    "item: item",
    "DreamJourneyBackendClient.shared",
    "presentActivationConfirmation(",
    "确认纳入",
    "activationUseCase.send(.activate)",
    "useCase.send(.refresh)",
    "已确认的记忆线索",
    "等待你明确纳入正式记忆",
    "正在整理，完成后将自动可用",
    "projectionRecoveryUseCase.send(.refresh)",
] {
    require(inboxSection.contains(required), "activation inbox controller missing: \(required)")
}
require(
    inboxSection.contains("inbox.isBound(to: accountLease)") &&
        inboxSection.contains("accountLeaseRuntime.validate(accountLease, at: .request).allowed") &&
        inboxSection.contains("releasePolicyAvailable()"),
    "activation must fail closed when the bound inbox, account lease, or release gate is invalid"
)
require(
    !inboxSection.contains("OwnerTruthCandidateReviewQAGate") &&
        !inboxSection.contains("X-DreamJourney-QA-Owner-Truth"),
    "formal activation inbox must not depend on QA-only transport or a QA header"
)
require(
    inboxSection.contains("state.phase == .ready") &&
        inboxSection.contains("itemCount > 0") &&
        inboxSection.contains("projectionRecoverySummaryLabel.isHidden = true") &&
        inboxSection.contains("projectionRecoverySummaryLabel.isHidden = false"),
    "projection recovery must remain a count-only, non-blocking summary that is hidden without items"
)

for forbidden in [
    "item.candidateID",
    "item.reviewBatchID",
    "candidateContent",
    "candidateText",
    "sourceDetails",
    "providerData",
    "receiptId",
    "memoryVersionId",
    "projectionJobId",
    "jobId",
    "String(describing: item)",
] {
    require(!inboxSection.contains(forbidden), "opaque activation inbox must not render or expose: \(forbidden)")
}

print("owner-truth memory activation inbox presentation check passed")

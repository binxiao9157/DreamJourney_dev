import Foundation

func read(_ path: String) throws -> String {
    try String(contentsOfFile: path, encoding: .utf8)
}

func require(_ condition: @autoclosure () -> Bool, _ message: String) {
    guard condition() else {
        fputs("owner-truth projection recovery inbox check failed: \(message)\n", stderr)
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

let contracts = try read("\(root)/DreamJourney/Sources/Domain/OwnerTruth/OwnerTruthContracts.swift")
let client = try read("\(root)/DreamJourney/Sources/Services/DreamJourneyBackendClient.swift")
let archive = try read("\(root)/DreamJourney/Sources/Modules/Archive/MemoryArchiveViewController.swift")

guard let recoveryContract = slice(
    contracts,
    from: "private struct OwnerTruthInterviewCandidateMemoryProjectionRecoveryInboxLeaseBinding",
    to: "/// Read-only confirmation material"
) else {
    fatalError("owner-truth projection recovery inbox check failed: recovery contract block is missing")
}

for required in [
    "owner-truth-interview-memory-projection-recovery-inbox-v1",
    "OwnerTruthInterviewCandidateMemoryProjectionRecoveryInbox",
    "case rebuilding",
    "[\"reviewBatchId\", \"candidateId\", \"state\"]",
    "Set(recoveryKeys).count == recoveryKeys.count",
] {
    require(recoveryContract.contains(required), "projection recovery contract missing: \(required)")
}

for required in [
    "OwnerTruthInterviewCandidateMemoryProjectionRecoveryInboxUseCase",
    "OwnerTruthInterviewCandidateMemoryProjectionRecoveryInboxClient",
    "releasePolicyAvailable()",
    "accountLeaseRuntime.validate(accountLease, at: .request).allowed",
    "accountLeaseRuntime.validate(accountLease, at: .commit).allowed",
] {
    require(contracts.contains(required), "projection recovery reader missing: \(required)")
}

for forbidden in [
    "memoryVersionId",
    "receiptId",
    "projectionJobId",
    "jobId",
    "candidateContent",
    "candidateText",
    "sourceDetails",
] {
    require(!recoveryContract.contains("\"\(forbidden)\""), "contract must not accept value-bearing field: \(forbidden)")
}

guard let clientMethod = slice(
    client,
    from: "func fetchOwnerTruthInterviewCandidateMemoryProjectionRecoveryInbox(",
    to: "/// Reads the future product confirmation projection"
) else {
    fatalError("owner-truth projection recovery inbox check failed: client method is missing")
}

require(
    clientMethod.contains("/interview-memory-projection-recovery-inbox") &&
        clientMethod.contains("authPolicy: .userRequired") &&
        clientMethod.contains("DJFeature.ownerTruthCandidateReview") &&
        !clientMethod.contains("X-DreamJourney-QA-Owner-Truth"),
    "client must use the captured formal gate and user authentication without a QA header"
)

guard let inboxController = slice(
    archive,
    from: "final class OwnerTruthInterviewCandidateMemoryActivationInboxViewController",
    to: "final class OwnerTruthInterviewCandidateConfirmationInboxViewController"
) else {
    fatalError("owner-truth projection recovery inbox check failed: activation inbox controller is missing")
}

for required in [
    "projectionRecoveryUseCase",
    "owner-truth-memory-projection-recovery-summary",
    "正在整理，完成后将自动可用",
    "projectionRecoverySummaryLabel.isHidden = true",
    "projectionRecoverySummaryLabel.isHidden = false",
] {
    require(inboxController.contains(required), "hidden activation page missing projection summary behavior: \(required)")
}

require(
    !inboxController.contains("OwnerTruthCandidateReviewQAGate") &&
        !inboxController.contains("X-DreamJourney-QA-Owner-Truth"),
    "projection recovery must not add a QA-only route"
)

print("owner-truth projection recovery inbox check passed")

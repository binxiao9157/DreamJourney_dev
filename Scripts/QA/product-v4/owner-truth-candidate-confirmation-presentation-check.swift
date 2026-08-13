import Foundation

func read(_ path: String) throws -> String {
    try String(contentsOfFile: path, encoding: .utf8)
}

func require(_ condition: @autoclosure () -> Bool, _ message: String) {
    guard condition() else {
        fputs("owner-truth candidate confirmation presentation check failed: \(message)\n", stderr)
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
let contracts = try read("\(root)/DreamJourney/Sources/Domain/OwnerTruth/OwnerTruthContracts.swift")
let backendClient = try read("\(root)/DreamJourney/Sources/Services/DreamJourneyBackendClient.swift")
let tests = try read("\(root)/DreamJourneyTests/OwnerTruthContractsTests.swift")

guard let naturalInputStart = archive.range(of: "final class OwnerTruthInterviewNaturalInputViewController"),
      let naturalInputEnd = archive.range(
        of: "#if UI_QA_SIMULATOR && targetEnvironment(simulator)",
        range: naturalInputStart.upperBound..<archive.endIndex
      ) else {
    fatalError("owner-truth candidate confirmation presentation check failed: natural-input product surface is missing")
}
let naturalInputSurface = String(archive[naturalInputStart.lowerBound..<naturalInputEnd.lowerBound])

require(
    !naturalInputSurface.contains("candidateConfirmationEntryButton") &&
        !naturalInputSurface.contains("candidateConfirmationEntryTapped") &&
        !naturalInputSurface.contains("owner-truth-interview-pending-confirmation-entry"),
    "natural-input review-pending state must not skip directly into candidate confirmation"
)

for required in [
    "OwnerTruthInterviewCandidateConfirmationInboxViewController",
    "OwnerTruthInterviewCandidateConfirmationViewController",
    "写入所选正式记忆",
    "需要逐条确认",
] {
    require(archive.contains(required), "default-off product confirmation presentation missing: \(required)")
}

require(
    !archive.contains("candidateConfirmationButton") &&
        !archive.contains("ownerTruthCandidateConfirmationTapped"),
    "Archive must expose one unified candidate inbox instead of a duplicate interview confirmation entry"
)

guard let inboxSection = slice(
    archive,
    from: "final class OwnerTruthInterviewCandidateConfirmationInboxViewController",
    to: "final class OwnerTruthInterviewCandidateConfirmationViewController"
) else {
    fatalError("owner-truth candidate confirmation presentation check failed: confirmation inbox controller is missing")
}
require(
    inboxSection.contains("OwnerTruthInterviewCandidateConfirmationInboxUseCase") &&
        inboxSection.contains("requestServerPolicyManagedDecision(for: .ownerTruthCandidateReview)") &&
        inboxSection.contains(".allowed"),
    "product confirmation inbox must use the lease-fenced product contract and revalidate release policy"
)
require(
    !inboxSection.contains("OwnerTruthCandidateReviewQAGate"),
    "product confirmation inbox must not depend on QA-only review gating"
)

guard let detailSection = slice(
    archive,
    from: "final class OwnerTruthInterviewCandidateConfirmationViewController",
    to: "// MARK: -"
) else {
    fatalError("owner-truth candidate confirmation presentation check failed: confirmation detail controller is missing")
}
require(
    detailSection.contains("OwnerTruthInterviewCandidateConfirmationActionUseCase") &&
        detailSection.contains("OwnerTruthInterviewCandidateConfirmationSingleActionUseCase") &&
        detailSection.contains("OwnerTruthInterviewCandidateMemoryActivationUseCase") &&
        detailSection.contains("beginFormalMemoryActivation(") &&
        detailSection.contains("confirmBatch(candidateIDs:"),
    "product confirmation detail must confirm and activate through distinct authority contracts"
)
require(
    detailSection.contains("已丢弃这条记忆。") &&
        detailSection.contains("已写入正式记忆。") &&
        detailSection.contains("部分记忆写入失败；可从待确认记忆重试。"),
    "pending-memory detail must expose discard, activation success, and recoverable failure semantics"
)
require(
    !detailSection.contains("OwnerTruthCandidateReviewQAGate"),
    "product confirmation detail must not reuse QA-only review gating"
)

for required in [
    "struct OwnerTruthInterviewCandidateConfirmationSingleCommand",
    "struct OwnerTruthInterviewCandidateConfirmationSingleResult",
    "protocol OwnerTruthInterviewCandidateConfirmationSingleActionClient",
    "final class OwnerTruthInterviewCandidateConfirmationSingleActionUseCase",
    "object[\"receipt\"] == nil",
    "func confirmOwnerTruthInterviewCandidateSingle(",
    "extension DreamJourneyBackendClient: OwnerTruthInterviewCandidateConfirmationSingleActionClient {}",
] {
    require(
        contracts.contains(required) || backendClient.contains(required),
        "formal single-candidate confirmation contract missing: \(required)"
    )
}

guard let singleClientSection = slice(
    backendClient,
    from: "func confirmOwnerTruthInterviewCandidateSingle(",
    to: "func fetchOwnerTruthInterviewSessionState("
) else {
    fatalError("owner-truth candidate confirmation presentation check failed: single action client method is missing")
}
require(
    singleClientSection.contains("/confirmation/candidates/") &&
        singleClientSection.contains("featureDecision: decision") &&
        !singleClientSection.contains("X-DreamJourney-QA-Owner-Truth"),
    "formal single-candidate action must use the product route with a captured policy decision"
)

for testName in [
    "func testInterviewCandidateConfirmationSingleActionDecodesValueMinimizedResult()",
    "func testInterviewCandidateConfirmationSingleActionUseCaseFailsClosedAndRejectsBatchCandidate()",
    "func testInterviewCandidateConfirmationSingleActionUseCaseReconcilesTerminalDecision()",
] {
    require(tests.contains(testName), "formal single-candidate action test missing: \(testName)")
}

print("owner-truth candidate confirmation presentation check passed")

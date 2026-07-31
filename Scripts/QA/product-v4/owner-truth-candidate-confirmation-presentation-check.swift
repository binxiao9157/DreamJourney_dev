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

for required in [
    "private let candidateConfirmationEntryButton",
    "private let candidateConfirmationPolicyAvailable",
    "configureCandidateConfirmationEntry()",
    "updateCandidateConfirmationEntry(for: state)",
    "@objc private func candidateConfirmationEntryTapped()",
    "owner-truth-interview-pending-confirmation-entry",
] {
    require(
        naturalInputSurface.contains(required),
        "natural-input pending-confirmation entry missing: \(required)"
    )
}
require(
    naturalInputSurface.contains("presentation == .product") &&
        naturalInputSurface.contains("state.continuation?.state == .reviewPending") &&
        naturalInputSurface.contains("candidateConfirmationPolicyAvailable()"),
    "natural-input pending-confirmation entry must remain product-only, review-pending-only, and policy-gated"
)
require(
    naturalInputSurface.contains("OwnerTruthInterviewCandidateConfirmationInboxViewController(") &&
        naturalInputSurface.contains("candidateConfirmationInboxClient") &&
        naturalInputSurface.contains("accountLeaseRuntime: accountLeaseRuntime"),
    "natural-input pending-confirmation entry must reuse the formal lease-fenced confirmation inbox"
)
guard let pendingEntrySection = slice(
    naturalInputSurface,
    from: "private func configureCandidateConfirmationEntry()",
    to: "private func configureBoundaryControls()"
) else {
    fatalError("owner-truth candidate confirmation presentation check failed: natural-input pending entry section is missing")
}
require(
    !pendingEntrySection.contains("OwnerTruthCandidateReviewQAGate"),
    "natural-input product confirmation entry must not use the QA-only review gate"
)

for required in [
    "private let candidateConfirmationButton",
    "configureCandidateConfirmationButton()",
    "updateCandidateConfirmationButton()",
    "@objc private func ownerTruthCandidateConfirmationTapped()",
    "OwnerTruthInterviewCandidateConfirmationInboxViewController",
    "OwnerTruthInterviewCandidateConfirmationViewController",
    "确认所选普通线索",
    "需要逐条确认",
] {
    require(archive.contains(required), "default-off product confirmation presentation missing: \(required)")
}

guard let entrySection = slice(
    archive,
    from: "private func updateCandidateConfirmationButton()",
    to: "private func reloadFeatureCards"
) else {
    fatalError("owner-truth candidate confirmation presentation check failed: archive entry section is missing")
}
require(
    entrySection.contains("FeatureGateService.shared.isRouteAllowed(") &&
        entrySection.contains(".ownerTruthCandidateReview") &&
        entrySection.contains("FeatureFlagService.shared.isEnabled(.ownerTruthCandidateReview)"),
    "product confirmation entry must capture the dedicated route decision before it becomes visible"
)
require(
    entrySection.contains("candidateConfirmationButton.isHidden = !isVisible"),
    "product confirmation entry must remain hidden when its policy is not allowed"
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
        inboxSection.contains("FeatureGateService.shared.requestDecision(for: .ownerTruthCandidateReview).allowed"),
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
        detailSection.contains("confirmBatch(candidateIDs:"),
    "product confirmation detail must keep ordinary and sensitive decisions on their distinct contracts"
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
    "func testNaturalInputProductPendingConfirmationEntryUsesDedicatedPolicyAndInbox()",
    "func testNaturalInputProductPendingConfirmationEntryStaysHiddenWithoutPolicy()",
] {
    require(tests.contains(testName), "formal single-candidate action test missing: \(testName)")
}

print("owner-truth candidate confirmation presentation check passed")

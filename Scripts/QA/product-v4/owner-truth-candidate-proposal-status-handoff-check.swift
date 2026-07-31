import Foundation

func read(_ path: String) throws -> String {
    try String(contentsOfFile: path, encoding: .utf8)
}

func require(_ condition: @autoclosure () -> Bool, _ message: String) {
    guard condition() else {
        fputs("owner-truth candidate proposal status handoff check failed: \(message)\n", stderr)
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

func requireSlice(_ source: String, from start: String, to end: String, _ message: String) -> String {
    guard let result = slice(source, from: start, to: end) else {
        fputs("owner-truth candidate proposal status handoff check failed: \(message)\n", stderr)
        exit(1)
    }
    return result
}

let root = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent()
    .deletingLastPathComponent()
    .deletingLastPathComponent()
    .deletingLastPathComponent()
    .path

let archive = try read("\(root)/DreamJourney/Sources/Modules/Archive/MemoryArchiveViewController.swift")
let contracts = try read("\(root)/DreamJourney/Sources/Domain/OwnerTruth/OwnerTruthContracts.swift")
let echo = try read("\(root)/DreamJourney/Sources/Modules/Echo/EchoViewController.swift")
let tests = try read("\(root)/DreamJourneyTests/OwnerTruthContractsTests.swift")
let releaseRegression = try read("\(root)/Scripts/QA/prd-stitch-ui/run-release-regression.sh")
let featureFlags = try read("\(root)/DreamJourney/Sources/App/FeatureFlagService.swift")
let appDelegate = try read("\(root)/DreamJourney/Sources/AppDelegate.swift")
let reviewReadySmoke = try read(
    "\(root)/Scripts/QA/prd-stitch-ui/run-owner-truth-interview-candidate-proposal-review-ready-smoke.sh"
)

require(
    releaseRegression.contains("owner-truth-candidate-proposal-status-handoff-check.swift"),
    "status handoff guard must be wired into release regression"
)

let naturalInputSurface = requireSlice(
    archive,
    from: "final class OwnerTruthInterviewNaturalInputViewController",
    to: "#if UI_QA_SIMULATOR && targetEnvironment(simulator)",
    "natural-input product controller is missing"
)

for required in [
    "candidateProposalStatusEntryButton",
    "candidateProposalStatusClient",
    "candidateProposalStatusPolicyAvailable",
    "OwnerTruthInterviewCandidateProposalStatusUseCase",
    "refreshCandidateProposalStatus()",
    "candidateProposalStatusState.status?.candidateReviewState == .reviewReady",
    "candidateProposalStatusState.status?.isBound(to: accountLease) == true",
    "candidateProposalConfirmationInboxControllerProvider",
] {
    require(naturalInputSurface.contains(required), "status handoff is missing: \(required)")
}

let statusGate = requireSlice(
    naturalInputSurface,
    from: "private func canOfferCandidateProposalStatus",
    to: "@objc private func reviewBatchAcknowledgementEntryTapped",
    "status handoff visibility gate is missing"
)
for required in [
    "presentation == .product",
    "state.continuation?.state == .reviewPending",
    "state.latestReceipt?.lifecycle == .ended",
    "candidateProposalAdmissionState.phase == .admitted",
    "candidateProposalAdmissionState.receipt != nil",
    "candidateProposalStatusPolicyAvailable()",
    "accountLeaseRuntime.validate(accountLease, at: .ui).allowed",
    "!isCandidateProposalStatusContentUnavailable",
] {
    require(statusGate.contains(required), "status handoff must remain owner-, lease-, and policy-fenced: \(required)")
}

let statusAction = requireSlice(
    naturalInputSurface,
    from: "@objc private func candidateProposalStatusEntryTapped()",
    to: "private func acknowledgeCurrentReviewBatch()",
    "status handoff action is missing"
)
for required in [
    "candidateProposalStatusState.phase == .ready",
    "candidateReviewState == .reviewReady",
    "reviewBatchID == reviewBatchID",
    "isBound(to: accountLease) == true",
    "candidateProposalConfirmationInboxControllerProvider(accountLease, reviewBatchID)",
] {
    require(statusAction.contains(required), "status handoff must require review-ready exact-batch state: \(required)")
}
require(
    !statusAction.contains("OwnerTruthInterviewCandidateConfirmationViewController(") &&
        !statusAction.contains("confirmBatch(") &&
        !statusAction.contains("confirmSingle("),
    "status handoff must enter the existing inbox only and never submit a confirmation"
)

let admissionAction = requireSlice(
    naturalInputSurface,
    from: "@objc private func candidateProposalAdmissionEntryTapped()",
    to: "@objc private func candidateProposalStatusEntryTapped()",
    "candidate proposal admission action is missing"
)
require(
    !admissionAction.contains("candidateProposalConfirmationInboxControllerProvider") &&
        !admissionAction.contains("OwnerTruthInterviewCandidateConfirmationInboxViewController"),
    "admission itself must not skip into candidate confirmation"
)

let focusedInbox = requireSlice(
    archive,
    from: "final class OwnerTruthInterviewCandidateConfirmationInboxViewController",
    to: "final class OwnerTruthInterviewCandidateConfirmationViewController",
    "candidate confirmation inbox controller is missing"
)
for required in [
    "focusedReviewBatchID",
    "visibleItems",
    "$0.reviewBatchID == focusedReviewBatchID && $0.readiness == .reviewReady",
    "title = focusedReviewBatchID == nil ? \"待确认记忆\" : \"本次待确认记忆\"",
] {
    require(focusedInbox.contains(required), "focused confirmation inbox is missing: \(required)")
}
for required in [
    "focusedReviewBatchID: focusedReviewBatchID",
    "OwnerTruthInterviewCandidateConfirmationInboxUseCase",
    "本次待确认内容已失效，无法继续确认。",
    "待确认内容已更新，请重新载入。",
    "case .contextChanged:",
] {
    require(focusedInbox.contains(required), "focused confirmation inbox must fail closed: \(required)")
}
require(
    !focusedInbox.contains("OwnerTruthCandidateReviewQAGate"),
    "focused confirmation inbox must remain on the product policy path"
)

let confirmationDetail = requireSlice(
    archive,
    from: "final class OwnerTruthInterviewCandidateConfirmationViewController",
    to: "extension OwnerTruthInterviewCandidateConfirmationViewController: UITableViewDataSource, UITableViewDelegate",
    "candidate confirmation detail controller is missing"
)
for required in [
    "refreshAfterCandidateAction",
    "invalidateActionConfiguration",
    "canManuallyRefresh",
    "isCandidateInteractionAllowed",
    "isCandidateActionInFlight",
    "actionConfigurationGeneration",
    "beginCandidateActionSubmission",
    "submitBatchConfirmation",
    "submitSingleConfirmation",
    "requiresCandidateConfirmationReload",
    "guard self.actionConfigurationGeneration == configurationGeneration else { return }",
    "guard !isCandidateActionInFlight else { return false }",
    "本次待确认内容已失效，无法继续确认。",
    "待确认内容已更新，请重新载入。",
    "readUseCase.send(.refresh)",
    "case .unavailable:",
    "case .failed:",
] {
    require(
        confirmationDetail.contains(required),
        "candidate confirmation detail must clear stale actions safely: \(required)"
    )
}

for required in [
    "OwnerTruthInterviewCandidateProposalStatusUseCase",
    "OwnerTruthInterviewCandidateConfirmationUseCase",
    "OwnerTruthInterviewCandidateConfirmationActionUseCase",
    "OwnerTruthInterviewCandidateConfirmationSingleActionUseCase",
    "candidateReviewState",
    "effectExecutionState == .disabled",
    "var isTerminallyUnavailable",
    "case contentUnavailable",
    "case contextChanged",
    "ownerTruthCandidateSourceInactive",
    "status.isTerminallyUnavailable",
] {
    require(contracts.contains(required), "typed value-minimized status contract is missing: \(required)")
}

for testName in [
    "func testNaturalInputProductStartsCandidateProposalOnlyAfterAcknowledgement()",
    "func testNaturalInputProductOpensFocusedConfirmationInboxOnlyWhenProposalReviewIsReady()",
    "func testFocusedCandidateConfirmationInboxFiltersOtherReviewBatches()",
    "func testFocusedCandidateConfirmationInboxRendersMissingBatchAsTerminalUnavailable()",
    "func testFocusedCandidateConfirmationInboxKeepsManualRefreshForContextChange()",
    "func testInterviewCandidateProposalStatusUseCaseFailsClosedForInvalidatedInactiveStatus()",
    "func testInterviewCandidateProposalStatusUseCasePrioritizesStaleLeaseOverFailureMapping()",
    "func testInterviewCandidateConfirmationUseCaseFailsClosedForTerminalReadFailuresAndSourceInactiveConflict()",
    "func testInterviewCandidateConfirmationBatchActionFailsClosedWhenSourceBecomesInactive()",
    "func testInterviewCandidateConfirmationSingleActionFailsClosedWhenSourceBecomesInactive()",
    "func testCandidateConfirmationDetailClearsTerminalContentAndOnlyAllowsRefreshForContextChange()",
    "func testCandidateConfirmationDetailLocksRefreshAndFailsClosedAfterBatchResponseMismatch()",
    "func testCandidateConfirmationDetailFailsClosedAfterSingleReconciliationFailure()",
] {
    require(tests.contains(testName), "status handoff test is missing: \(testName)")
}

for required in [
    "candidateProposalStatusPolicyAvailable: { true }",
    "candidateProposalStatusPhase",
    "candidateProposalReviewState",
    "candidateProposalStatusEntryVisible",
    "runUIQAOwnerTruthInterviewCandidateProposalReviewReadySmoke",
    "OwnerTruthInterviewCandidateProposalReviewReadyUIQAScenario",
    "candidateProposalConfirmationInboxPresented",
    "candidateProposalFocusedReviewBatchMatches",
    "candidateProposalOtherReviewBatchHidden",
    "candidateProposalConfirmationActionTriggered",
] {
    require(echo.contains(required), "product UIQA smoke must exercise status handoff: \(required)")
}

require(
    archive.contains("final class CandidateConfirmationInboxFixture") &&
        archive.contains("OwnerTruthInterviewCandidateProposalReviewReadyUIQAScenario"),
    "review-ready UIQA must keep its content-free fixture inside the Archive module"
)

for required in [
    "candidateProposalReviewState: .reviewReady",
    "candidateProposalStatusEntryTitle == \"查看待确认内容\"",
    "focusedInboxVisibleItemCount == 1",
    "reviewReadyScenario?.confirmationInboxReadCount == 1",
    "confirmationDetailPresented: false",
] {
    require(
        echo.contains(required),
        "review-ready UIQA must stay scoped to one read-only confirmation inbox: \(required)"
    )
}

require(
    featureFlags.contains(
        "case ownerTruthInterviewCandidateProposalReviewReadySmoke = \"DJRunOwnerTruthInterviewCandidateProposalReviewReadySmoke\""
    ) && appDelegate.contains("case .ownerTruthInterviewCandidateProposalReviewReadySmoke:"),
    "review-ready UIQA launch scenario must remain explicitly simulator-routable"
)

for required in [
    "SMOKE_VARIANT=review-ready",
    "LAUNCH_SCENARIO=DJRunOwnerTruthInterviewCandidateProposalReviewReadySmoke",
    "RESULT_FILE_NAME=owner-truth-interview-candidate-proposal-review-ready-smoke-result.json",
] {
    require(
        reviewReadySmoke.contains(required),
        "review-ready UIQA wrapper must retain its isolated launch contract: \(required)"
    )
}

print("owner-truth candidate proposal status handoff check passed")

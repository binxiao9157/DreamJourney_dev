import Foundation

func read(_ path: String) throws -> String {
    try String(contentsOfFile: path, encoding: .utf8)
}

func require(_ condition: @autoclosure () -> Bool, _ message: String) {
    guard condition() else {
        fputs("owner-truth candidate proposal admission check failed: \(message)\n", stderr)
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
        fputs("owner-truth candidate proposal admission check failed: \(message)\n", stderr)
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

let contracts = try read("\(root)/DreamJourney/Sources/Domain/OwnerTruth/OwnerTruthContracts.swift")
let client = try read("\(root)/DreamJourney/Sources/Services/DreamJourneyBackendClient.swift")
let archive = try read("\(root)/DreamJourney/Sources/Modules/Archive/MemoryArchiveViewController.swift")
let echo = try read("\(root)/DreamJourney/Sources/Modules/Echo/EchoViewController.swift")
let tests = try read("\(root)/DreamJourneyTests/OwnerTruthContractsTests.swift")
let releaseRegression = try read("\(root)/Scripts/QA/prd-stitch-ui/run-release-regression.sh")

let admissionBlock = requireSlice(
    contracts,
    from: "// MARK: - Formal candidate proposal admission",
    to: "private enum OwnerTruthInterviewReviewBatchContract",
    "formal candidate proposal admission contract block is missing"
)

require(
    releaseRegression.contains("owner-truth-candidate-proposal-admission-check.swift"),
    "formal candidate proposal admission guard must be wired into release regression"
)

for required in [
    "OwnerTruthInterviewCandidateProposalAdmissionCommand",
    "OwnerTruthInterviewCandidateProposalAdmissionReceipt",
    "OwnerTruthInterviewCandidateProposalAdmissionClient",
    "OwnerTruthInterviewCandidateProposalAdmissionUseCase",
    "owner-truth-interview-candidate-proposal-admission-response-v1",
    "expectedReviewBatchVersion",
    "candidateExtraction",
    "ownerMessageCount",
    "notCreated",
    "notApplicable",
    "releasePolicyAvailable()",
    "accountLeaseRuntime.validate(accountLease, at: .request).allowed",
    "accountLeaseRuntime.validate(accountLease, at: .commit).allowed",
] {
    require(admissionBlock.contains(required), "formal candidate proposal admission contract missing: \(required)")
}

for forbidden in [
    "sourceId",
    "admissionId",
    "effectOperationId",
    "candidateId",
    "memoryId",
    "memoryVersionId",
    "sourceText",
    "transcript",
    "provider",
] {
    require(!admissionBlock.contains("\"\(forbidden)\""), "admission receipt must not retain value-bearing field: \(forbidden)")
}

let routeClassifier = requireSlice(
    client,
    from: "func featureForRequest(",
    to: "if normalizedPath == \"/archive/image-analysis\"",
    "backend feature-route classifier is missing"
)
let admissionRoute = requireSlice(
    routeClassifier,
    from: "if method == .post,\n           normalizedPath.contains(\"/interview-review-batches/\"),\n           normalizedPath.hasSuffix(\"/candidate-proposal/admit\")",
    to: "if method == .get,\n           normalizedPath.contains(\"/interview-review-batches/\"),\n           normalizedPath.hasSuffix(\"/confirmation\")",
    "candidate proposal admission route classifier is missing"
)
require(admissionRoute.contains("return .ownerTruthCandidateReview"), "admission route must use ownerTruthCandidateReview")
require(!admissionRoute.contains("echoTextInput"), "admission route must not reuse echoTextInput")

let admissionClient = requireSlice(
    client,
    from: "func admitOwnerTruthInterviewCandidateProposal(",
    to: "private enum OwnerTruthInterviewNaturalInputTransport",
    "formal candidate proposal admission client is missing"
)
for required in [
    "requestFeatureDecision(for: .ownerTruthCandidateReview)",
    "/candidate-proposal/admit",
    "method: .post",
    "authPolicy: .userRequired",
    "featureDecision: decision",
    "OwnerTruthInterviewCandidateProposalAdmissionReceipt(",
] {
    require(admissionClient.contains(required), "formal admission client is missing: \(required)")
}
require(
    client.contains("FeatureGateService.shared.requestServerPolicyManagedClosedPilotDecision(for: feature)"),
    "formal admission policy helper must remain server-policy managed"
)
require(!admissionClient.contains("echoTextInput"), "formal admission client must not borrow the natural-input policy")
require(!admissionClient.contains("X-DreamJourney-QA-Owner-Truth"), "formal admission client must not send a QA header")

let naturalInputSurface = requireSlice(
    archive,
    from: "final class OwnerTruthInterviewNaturalInputViewController",
    to: "#if UI_QA_SIMULATOR && targetEnvironment(simulator)",
    "natural-input product controller is missing"
)
for required in [
    "candidateProposalAdmissionEntryButton",
    "candidateProposalAdmissionPolicyAvailable",
    "OwnerTruthInterviewCandidateProposalAdmissionUseCase",
    "开始整理",
    "startCandidateProposalAdmission()",
    "reviewBatchAcknowledgementState.phase == .acknowledged",
    "reviewBatchAcknowledgementState.receipt != nil",
] {
    require(naturalInputSurface.contains(required), "candidate proposal product flow missing: \(required)")
}

let admissionVisibility = requireSlice(
    naturalInputSurface,
    from: "private func canOfferCandidateProposalAdmission",
    to: "@objc private func reviewBatchAcknowledgementEntryTapped",
    "candidate proposal admission visibility gate is missing"
)
for required in [
    "presentation == .product",
    "state.continuation?.state == .reviewPending",
    "state.latestReceipt?.lifecycle == .ended",
    "reviewBatchAcknowledgementState.phase == .acknowledged",
    "candidateProposalAdmissionPolicyAvailable()",
] {
    require(admissionVisibility.contains(required), "admission visibility must stay post-acknowledgement and policy-gated: \(required)")
}

let admissionAction = requireSlice(
    naturalInputSurface,
    from: "@objc private func candidateProposalAdmissionEntryTapped()",
    to: "private func acknowledgeCurrentReviewBatch()",
    "candidate proposal admission action is missing"
)
require(admissionAction.contains("UIAlertController("), "admission must require explicit Owner confirmation")
require(admissionAction.contains("不会直接保存为正式记忆"), "admission copy must not promise a completed Memory")
require(!admissionAction.contains("OwnerTruthInterviewCandidateConfirmationInboxViewController"), "admission must not jump directly into candidate confirmation")

require(
    !naturalInputSurface.contains("candidateConfirmationEntryButton") &&
        !naturalInputSurface.contains("owner-truth-interview-pending-confirmation-entry"),
    "natural-input flow must not expose a direct Candidate confirmation entry"
)

for required in [
    "testInterviewCandidateProposalAdmissionUsesAcknowledgedReceiptAndSeparatePolicy",
    "testInterviewCandidateProposalAdmissionReceiptRejectsCandidatePayload",
    "testNaturalInputProductStartsCandidateProposalOnlyAfterAcknowledgement",
] {
    require(tests.contains(required), "required admission test is missing: \(required)")
}

for required in [
    "candidateProposalAdmissionEntryVisible",
    "candidateProposalAdmissionPhase",
    "candidateProposalAdmissionRendered",
    "startCandidateProposalAdmissionForUIQA()",
] {
    require(echo.contains(required), "product surface smoke must exercise admission: \(required)")
}

print("owner-truth candidate proposal admission check passed")

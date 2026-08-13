import Foundation

func read(_ path: String) throws -> String {
    try String(contentsOfFile: path, encoding: .utf8)
}

func require(_ condition: @autoclosure () -> Bool, _ message: String) {
    guard condition() else {
        fputs("owner-truth pending review batch acknowledgement check failed: \(message)\n", stderr)
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
        fputs("owner-truth pending review batch acknowledgement check failed: \(message)\n", stderr)
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
let tests = try read("\(root)/DreamJourneyTests/OwnerTruthContractsTests.swift")

let contractBlock = requireSlice(
    contracts,
    from: "// MARK: - Formal pending review-batch acknowledgement",
    to: "private enum OwnerTruthInterviewReviewBatchContract",
    "formal pending review-batch acknowledgement contract block is missing"
)

for required in [
    "OwnerTruthInterviewPendingReviewBatchInboxItem",
    "OwnerTruthInterviewPendingReviewBatchInbox",
    "OwnerTruthInterviewReviewBatchAcknowledgementCommand",
    "OwnerTruthInterviewReviewBatchAcknowledgementReceipt",
    "OwnerTruthInterviewPendingReviewBatchInboxClient",
    "OwnerTruthInterviewReviewBatchAcknowledgementClient",
    "OwnerTruthInterviewReviewBatchAcknowledgementUseCase",
    "owner-truth-interview-pending-review-batch-inbox-v1",
    "owner-truth-interview-review-batch-acknowledgement-response-v1",
    "let allowedKeys: Set<String>",
    "Set(object.keys) == allowedKeys",
    "candidateProposal.keys) == [\"status\"]",
    "memoryActivation.keys) == [\"status\"]",
    "== \"notStarted\"",
    "== \"notApplicable\"",
] {
    require(contractBlock.contains(required), "value-minimized pending batch contract missing: \(required)")
}

for forbidden in [
    "candidateText",
    "candidateContent",
    "sourceText",
    "memoryContent",
    "transcript",
] {
    require(!contractBlock.contains("\"\(forbidden)\""), "pending acknowledgement contract accepts value-bearing field: \(forbidden)")
}

let acknowledgementUseCase = requireSlice(
    contracts,
    from: "final class OwnerTruthInterviewReviewBatchAcknowledgementUseCase",
    to: "private enum OwnerTruthInterviewReviewBatchContract",
    "acknowledgement use case is missing"
)
for required in [
    "releasePolicyAvailable()",
    "accountLeaseRuntime.validate(accountLease, at: .request).allowed",
    "accountLeaseRuntime.validate(accountLease, at: .commit).allowed",
    "$0.threadID == threadID && $0.sessionID == sessionID",
    "matches.count == 1",
    "receipt.matches(command)",
] {
    require(acknowledgementUseCase.contains(required), "acknowledgement use case must remain policy-, lease-, and session-fenced: \(required)")
}

let routeClassifier = requireSlice(
    client,
    from: "func featureForRequest(",
    to: "if normalizedPath == \"/archive/image-analysis\"",
    "backend feature-route classifier is missing"
)
for required in [
    "method == .get",
    "pathComponents[3] == \"interview-review-batches\"",
    "pathComponents[4] == \"pending\"",
    "method == .post",
    "pathComponents[5] == \"acknowledgement\"",
    "return .echoTextInput",
] {
    require(routeClassifier.contains(required), "pending/acknowledgement route must classify as echoTextInput: \(required)")
}
let pendingAcknowledgementRoutes = requireSlice(
    routeClassifier,
    from: "if method == .get,\n           pathComponents.count == 5",
    to: "normalizedPath.hasSuffix(\"/interview-candidate-confirmations\")",
    "pending/acknowledgement route classification block is missing"
)
require(
    pendingAcknowledgementRoutes.components(separatedBy: "return .echoTextInput").count == 3,
    "only GET pending and POST acknowledgement may classify interview-review-batches as echoTextInput"
)

let pendingClientMethod = requireSlice(
    client,
    from: "func fetchOwnerTruthInterviewPendingReviewBatchInbox(",
    to: "func acknowledgeOwnerTruthInterviewReviewBatch(",
    "pending review inbox client method is missing"
)
let acknowledgementClientMethod = requireSlice(
    client,
    from: "func acknowledgeOwnerTruthInterviewReviewBatch(",
    to: "private enum OwnerTruthInterviewNaturalInputTransport",
    "review batch acknowledgement client method is missing"
)

for (method, requiredMethod, requiredPath) in [
    (pendingClientMethod, "method: .get", "/interview-review-batches/pending"),
    (acknowledgementClientMethod, "method: .post", "/acknowledgement"),
] {
    require(method.contains(requiredMethod), "formal route uses the wrong HTTP method: \(requiredPath)")
    require(method.contains(requiredPath), "formal route is missing: \(requiredPath)")
    require(method.contains("authPolicy: .userRequired"), "formal route must require authenticated owner access: \(requiredPath)")
    require(method.contains("featureDecision: featureDecision"), "formal route must forward captured release policy: \(requiredPath)")
    require(method.contains("let transport = ownerTruthInterviewNaturalInputTransport()"), "formal route must reuse the shared formal/QA transport: \(requiredPath)")
    require(method.contains("case .releasePolicy(let capturedDecision):") && method.contains("featureDecision = capturedDecision"), "formal route must preserve a captured product policy: \(requiredPath)")
    require(method.contains("case .qa:") && method.contains("X-DreamJourney-QA-Owner-Truth"), "formal route must retain the isolated QA lane: \(requiredPath)")
}

let interviewController = requireSlice(
    archive,
    from: "final class OwnerTruthInterviewNaturalInputViewController",
    to: "#if UI_QA_SIMULATOR && targetEnvironment(simulator)",
    "natural-input product controller is missing"
)

for required in [
    "private let reviewBatchAcknowledgementEntryButton",
    "reviewBatchAcknowledgementPolicyAvailable",
    "OwnerTruthInterviewReviewBatchAcknowledgementUseCase",
    "\"确认进入整理\"",
    "UIAlertController(",
    "useCase.send(.acknowledge)",
] {
    require(interviewController.contains(required), "product acknowledgement UI is missing: \(required)")
}

let acknowledgementVisibility = requireSlice(
    interviewController,
    from: "private func canOfferReviewBatchAcknowledgement",
    to: "@objc private func reviewBatchAcknowledgementEntryTapped",
    "acknowledgement entry visibility gate is missing"
)
for required in [
    "presentation == .product",
    "state.phase == .ready",
    "state.continuation?.state == .reviewPending",
    "state.latestReceipt?.lifecycle == .ended",
    "reviewBatchAcknowledgementPolicyAvailable()",
] {
    require(acknowledgementVisibility.contains(required), "acknowledgement entry must require product, pending state, session receipt, and policy: \(required)")
}

let acknowledgementTap = requireSlice(
    interviewController,
    from: "@objc private func reviewBatchAcknowledgementEntryTapped",
    to: "private func configureBoundaryControls",
    "acknowledgement entry action is missing"
)
for required in [
    "canOfferReviewBatchAcknowledgement(for: renderedState)",
    "UIAlertController(",
    "确认进入整理",
    "acknowledgeCurrentReviewBatch()",
] {
    require(acknowledgementTap.contains(required), "acknowledgement action must re-check the current thread/session and require a second confirmation: \(required)")
}

require(
    !acknowledgementTap.contains("OwnerTruthInterviewCandidateConfirmationInboxViewController") &&
        !acknowledgementTap.contains("candidateConfirmationEntryTapped"),
    "pending batch acknowledgement must not jump directly into candidate confirmation"
)

let acknowledgementExecution = requireSlice(
    interviewController,
    from: "private func acknowledgeCurrentReviewBatch()",
    to: "private func renderReviewBatchAcknowledgement",
    "acknowledgement execution is missing"
)
for required in [
    "renderedState.latestReceipt",
    "receipt.threadID",
    "receipt.sessionID",
    "OwnerTruthInterviewReviewBatchAcknowledgementUseCase(",
    "accountLeaseRuntime: accountLeaseRuntime",
    "releasePolicyAvailable: reviewBatchAcknowledgementPolicyAvailable",
    "useCase.send(.acknowledge)",
] {
    require(acknowledgementExecution.contains(required), "acknowledgement execution must bind the current session and policy: \(required)")
}

require(
    !archive.contains("private func updateCandidateConfirmationButton()") &&
        archive.contains("OwnerTruthInterviewCandidateConfirmationInboxViewController"),
    "candidate confirmation must remain available to interview flows without a duplicate Archive entry point"
)

for testMention in [
    "PendingReviewBatchInbox",
    "ReviewBatchAcknowledgement",
    "testInterviewReviewBatchAcknowledgement",
] {
    require(tests.contains(testMention), "OwnerTruthContractsTests coverage mention is missing: \(testMention)")
}

print("owner-truth pending review batch acknowledgement check passed")

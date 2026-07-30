import Foundation

func read(_ path: String) throws -> String {
    try String(contentsOfFile: path, encoding: .utf8)
}

func require(_ condition: @autoclosure () -> Bool, _ message: String) {
    guard condition() else {
        fputs("owner-truth candidate confirmation default-off check failed: \(message)\n", stderr)
        exit(1)
    }
}

let root = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent()
    .deletingLastPathComponent()
    .deletingLastPathComponent()
    .deletingLastPathComponent()
    .path
let featureFlags = try read("\(root)/DreamJourney/Sources/App/FeatureFlagService.swift")
let backendClient = try read("\(root)/DreamJourney/Sources/Services/DreamJourneyBackendClient.swift")
let contracts = try read("\(root)/DreamJourney/Sources/Domain/OwnerTruth/OwnerTruthContracts.swift")
let tests = try read("\(root)/DreamJourneyTests/OwnerTruthContractsTests.swift")

require(featureFlags.contains("case ownerTruthCandidateReview"), "feature must be modeled explicitly")
require(
    featureFlags.contains(".ownerTruthCandidateReview,") &&
        featureFlags.contains("private static let nonPersistentFeatures"),
    "feature must remain launch-scoped rather than persisted"
)

let defaultsRange = featureFlags.range(of: "private static let defaultEnabled: Set<DJFeature> = [")
let nonPersistentRange = featureFlags.range(of: "private static let nonPersistentFeatures")
require(defaultsRange != nil && nonPersistentRange != nil, "feature flag sections must remain identifiable")
if let defaultsRange, let nonPersistentRange {
    let defaults = String(featureFlags[defaultsRange.lowerBound..<nonPersistentRange.lowerBound])
    require(!defaults.contains("ownerTruthCandidateReview"), "candidate confirmation must not be release-default")
}

require(
    backendClient.contains("normalizedPath.hasSuffix(\"/confirmation\")") &&
        backendClient.contains("return .ownerTruthCandidateReview"),
    "confirmation route must map to its dedicated feature"
)
require(
    backendClient.contains("normalizedPath.hasSuffix(\"/interview-candidate-confirmations\")") &&
        backendClient.contains("return .ownerTruthCandidateReview"),
    "confirmation inbox route must map to its dedicated feature"
)
require(
    backendClient.contains("normalizedPath.hasSuffix(\"/confirmation/batch-accept\")") &&
        backendClient.contains("method == .post"),
    "confirmation batch action route must map to its dedicated feature"
)
guard let riskClassStart = backendClient.range(of: "private func riskClass(for feature: DJFeature)"),
      let riskClassEnd = backendClient.range(
        of: "private func archiveMediaFeature",
        range: riskClassStart.upperBound..<backendClient.endIndex
      ) else {
    fatalError("owner-truth candidate confirmation default-off check failed: feature risk class is missing")
}
let riskClass = String(backendClient[riskClassStart.lowerBound..<riskClassEnd.lowerBound])
require(
    riskClass.contains(".ownerTruthCandidateReview") &&
        riskClass.contains(".profileSettings") &&
        riskClass.contains("return .ownerTextCore"),
    "confirmation route must keep owner-text policy handling"
)

guard let methodStart = backendClient.range(of: "func fetchOwnerTruthInterviewCandidateConfirmation("),
      let methodEnd = backendClient.range(
        of: "func fetchOwnerTruthInterviewSessionState(",
        range: methodStart.upperBound..<backendClient.endIndex
      ) else {
    fatalError("owner-truth candidate confirmation default-off check failed: typed client method is missing")
}
let typedMethod = String(backendClient[methodStart.lowerBound..<methodEnd.lowerBound])
require(
    typedMethod.contains("FeatureGateService.shared.requestDecision(for: .ownerTruthCandidateReview)"),
    "typed confirmation client must capture the dedicated release-policy decision"
)
require(
    typedMethod.contains("/confirmation\"") && typedMethod.contains("featureDecision: decision"),
    "typed confirmation client must call the confirmation route with its captured decision"
)
require(
    typedMethod.contains("OwnerTruthInterviewCandidateConfirmation("),
    "typed confirmation client must parse the confirmation-only contract"
)
require(
    !typedMethod.contains("X-DreamJourney-QA-Owner-Truth"),
    "typed confirmation client must never carry the QA review header"
)

guard let inboxMethodStart = backendClient.range(of: "func fetchOwnerTruthInterviewCandidateConfirmationInbox("),
      let inboxMethodEnd = backendClient.range(
        of: "func fetchOwnerTruthInterviewCandidateConfirmation(",
        range: inboxMethodStart.upperBound..<backendClient.endIndex
      ) else {
    fatalError("owner-truth candidate confirmation default-off check failed: typed confirmation inbox client is missing")
}
let inboxMethod = String(backendClient[inboxMethodStart.lowerBound..<inboxMethodEnd.lowerBound])
require(
    inboxMethod.contains("FeatureGateService.shared.requestDecision(for: .ownerTruthCandidateReview)"),
    "typed confirmation inbox client must capture the dedicated release-policy decision"
)
require(
    inboxMethod.contains("/interview-candidate-confirmations\"") &&
        inboxMethod.contains("featureDecision: decision"),
    "typed confirmation inbox client must call discovery with its captured decision"
)
require(
    inboxMethod.contains("OwnerTruthInterviewCandidateConfirmationInbox(") &&
        !inboxMethod.contains("X-DreamJourney-QA-Owner-Truth") &&
        !inboxMethod.contains("/candidate-review"),
    "typed confirmation inbox client must parse only the content-free formal contract"
)

for required in [
    "struct OwnerTruthInterviewCandidateConfirmationInboxItem",
    "struct OwnerTruthInterviewCandidateConfirmationInbox",
    "protocol OwnerTruthInterviewCandidateConfirmationInboxClient",
    "final class OwnerTruthInterviewCandidateConfirmationInboxUseCase",
    "confirmation inbox item misses a required content-free field",
    "accountLeaseRuntime.validate(accountLease, at: .request).allowed",
    "accountLeaseRuntime.validate(accountLease, at: .commit).allowed",
    "a future UI must explicitly select an opaque `reviewBatchID`",
] {
    require(contracts.contains(required), "formal confirmation inbox contract missing: \(required)")
}

require(
    backendClient.contains("extension DreamJourneyBackendClient: OwnerTruthInterviewCandidateConfirmationInboxClient {}"),
    "concrete backend client must conform to the confirmation inbox port"
)
for testName in [
    "func testInterviewCandidateConfirmationInboxDecodesContentFreeBatchHandles()",
    "func testInterviewCandidateConfirmationInboxRejectsCandidateContentField()",
    "func testInterviewCandidateConfirmationInboxUseCaseFailsClosedWithoutReleasePolicy()",
    "func testInterviewCandidateConfirmationInboxUseCaseBindsReadAndRejectsStaleAccountCompletion()",
] {
    require(tests.contains(testName), "formal confirmation inbox test missing: \(testName)")
}

guard let actionStart = backendClient.range(of: "func confirmOwnerTruthInterviewCandidateBatch("),
      let actionEnd = backendClient.range(
        of: "func fetchOwnerTruthInterviewSessionState(",
        range: actionStart.upperBound..<backendClient.endIndex
      ) else {
    fatalError("owner-truth candidate confirmation default-off check failed: typed confirmation action is missing")
}
let actionMethod = String(backendClient[actionStart.lowerBound..<actionEnd.lowerBound])
require(
    actionMethod.contains("FeatureGateService.shared.requestDecision(for: .ownerTruthCandidateReview)"),
    "typed confirmation action must capture the dedicated release-policy decision"
)
require(
    actionMethod.contains("/confirmation/batch-accept\"") && actionMethod.contains("featureDecision: decision"),
    "typed confirmation action must call the formal route with its captured decision"
)
require(
    actionMethod.contains("OwnerTruthInterviewCandidateConfirmationBatchResult("),
    "typed confirmation action must parse the value-minimized formal result"
)
require(
    !actionMethod.contains("X-DreamJourney-QA-Owner-Truth") &&
        !actionMethod.contains("/candidate-review/batch-accept"),
    "typed confirmation action must never reuse QA headers or QA routes"
)

guard let actionUseCaseStart = contracts.range(of: "final class OwnerTruthInterviewCandidateConfirmationActionUseCase"),
      let actionUseCaseEnd = contracts.range(
        of: "// MARK: - Default-off interview session state read",
        range: actionUseCaseStart.upperBound..<contracts.endIndex
      ) else {
    fatalError("owner-truth candidate confirmation default-off check failed: typed confirmation action use case is missing")
}
let actionUseCase = String(contracts[actionUseCaseStart.lowerBound..<actionUseCaseEnd.lowerBound])
require(
    actionUseCase.contains("confirmationReader: OwnerTruthInterviewCandidateConfirmationClient") &&
        contracts.contains("case reconciling"),
    "formal confirmation action must enter an explicit reconciliation state"
)
require(
    actionUseCase.contains("receiveReconciliation(") &&
        actionUseCase.contains("remainingCandidateIDs.isDisjoint(with: expectedCandidateIDs)") &&
        actionUseCase.contains("confirmation.isBound(to: accountLease)") &&
        actionUseCase.contains("reconciledConfirmation.hasSameAuthorityComposition(as: confirmation)"),
    "formal confirmation action must bind its projection to the AccountLease and reconcile the same authority composition"
)
require(
    !actionUseCase.contains("X-DreamJourney-QA-Owner-Truth") &&
        !actionUseCase.contains("/candidate-review/batch-accept"),
    "formal confirmation action use case must not depend on QA review transport"
)

print("owner-truth candidate confirmation default-off check passed")

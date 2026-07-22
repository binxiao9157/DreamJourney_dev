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
    backendClient.contains("normalizedPath.hasSuffix(\"/confirmation/batch-accept\")") &&
        backendClient.contains("method == .post"),
    "confirmation batch action route must map to its dedicated feature"
)
require(
    backendClient.contains(".ownerTruthCandidateReview, .profileSettings"),
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

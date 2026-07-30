import Foundation

func read(_ path: String) throws -> String {
    try String(contentsOfFile: path, encoding: .utf8)
}

func require(_ condition: @autoclosure () -> Bool, _ message: String) {
    guard condition() else {
        fputs("owner-truth candidate memory activation inbox check failed: \(message)\n", stderr)
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
let backendClient = try read("\(root)/DreamJourney/Sources/Services/DreamJourneyBackendClient.swift")
let tests = try read("\(root)/DreamJourneyTests/OwnerTruthContractsTests.swift")

for required in [
    "struct OwnerTruthInterviewCandidateMemoryActivationInboxItem",
    "struct OwnerTruthInterviewCandidateMemoryActivationInbox",
    "protocol OwnerTruthInterviewCandidateMemoryActivationInboxClient",
    "final class OwnerTruthInterviewCandidateMemoryActivationInboxUseCase",
    "owner-truth-interview-candidate-memory-activation-inbox-v1",
    "activation inbox item must contain only reviewBatchId and candidateId",
    "activation inbox repeats a review batch Candidate handle",
] {
    require(contracts.contains(required), "typed activation inbox contract missing: \(required)")
}

guard let itemContract = slice(
    contracts,
    from: "struct OwnerTruthInterviewCandidateMemoryActivationInboxItem",
    to: "struct OwnerTruthInterviewCandidateMemoryActivationInbox"
) else {
    fatalError("owner-truth candidate memory activation inbox check failed: item contract is missing")
}
require(
    itemContract.contains("let allowedKeys: Set<String> = [\"reviewBatchId\", \"candidateId\"]"),
    "activation inbox item must allow only opaque review/candidate handles"
)

guard let inboxUseCase = slice(
    contracts,
    from: "final class OwnerTruthInterviewCandidateMemoryActivationInboxUseCase",
    to: "// MARK: - Default-off product confirmation read"
) else {
    fatalError("owner-truth candidate memory activation inbox check failed: read use case is missing")
}
require(
    inboxUseCase.contains("releasePolicyAvailable()") &&
        inboxUseCase.contains("accountLeaseRuntime.validate(accountLease, at: .request).allowed") &&
        inboxUseCase.contains("accountLeaseRuntime.validate(accountLease, at: .commit).allowed") &&
        inboxUseCase.contains("inbox.bound(to: accountLease)"),
    "activation inbox reader must be policy-gated and AccountLease-fenced"
)

guard let activationUseCase = slice(
    contracts,
    from: "final class OwnerTruthInterviewCandidateMemoryActivationUseCase",
    to: "// MARK: - Default-off interview session state read"
) else {
    fatalError("owner-truth candidate memory activation inbox check failed: activation use case is missing")
}
require(
    activationUseCase.contains("case activationInbox(OwnerTruthInterviewCandidateMemoryActivationInbox)") &&
        activationUseCase.contains("inbox.isBound(to: accountLease)") &&
        activationUseCase.contains("inbox.items.contains"),
    "recovery activation must accept only an AccountLease-bound inbox handle"
)

guard let clientMethod = slice(
    backendClient,
    from: "func fetchOwnerTruthInterviewCandidateMemoryActivationInbox(",
    to: "/// Reads the future product confirmation projection"
) else {
    fatalError("owner-truth candidate memory activation inbox check failed: typed backend client method is missing")
}
require(
    clientMethod.contains("FeatureGateService.shared.requestDecision(for: .ownerTruthCandidateReview)") &&
        clientMethod.contains("/interview-memory-activation-inbox") &&
        clientMethod.contains("authPolicy: .userRequired") &&
        clientMethod.contains("featureDecision: decision"),
    "activation inbox client must use the formal route, user authentication, and captured policy"
)
require(
    clientMethod.contains("OwnerTruthInterviewCandidateMemoryActivationInbox(") &&
        !clientMethod.contains("X-DreamJourney-QA-Owner-Truth") &&
        !clientMethod.contains("/candidate-review"),
    "activation inbox client must parse only the formal content-free contract"
)
require(
    backendClient.contains("normalizedPath.hasSuffix(\"/interview-memory-activation-inbox\")") &&
        backendClient.contains("extension DreamJourneyBackendClient: OwnerTruthInterviewCandidateMemoryActivationInboxClient {}"),
    "activation inbox route must be feature-gated and satisfy its typed client port"
)

for testName in [
    "func testInterviewCandidateMemoryActivationInboxDecodesOnlyOpaqueHandles()",
    "func testInterviewCandidateMemoryActivationInboxBindsAndPermitsOnlyBoundRecoveryActivation()",
] {
    require(tests.contains(testName), "activation inbox contract test missing: \(testName)")
}

print("owner-truth candidate memory activation inbox check passed")

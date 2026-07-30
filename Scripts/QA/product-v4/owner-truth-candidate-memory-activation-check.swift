import Foundation

func read(_ path: String) throws -> String {
    try String(contentsOfFile: path, encoding: .utf8)
}

func require(_ condition: @autoclosure () -> Bool, _ message: String) {
    guard condition() else {
        fputs("owner-truth candidate memory activation check failed: \(message)\n", stderr)
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
    "struct OwnerTruthInterviewCandidateMemoryActivationCommand",
    "struct OwnerTruthInterviewCandidateMemoryActivationResult",
    "enum OwnerTruthInterviewCandidateMemoryActivationEligibility",
    "protocol OwnerTruthInterviewCandidateMemoryActivationClient",
    "final class OwnerTruthInterviewCandidateMemoryActivationUseCase",
    "memory activation requires a command id",
    "let allowedKeys: Set<String>",
    "memoryVersionCreated",
    "projectionRebuildRequested",
] {
    require(contracts.contains(required), "typed activation contract missing: \(required)")
}

guard let activationUseCase = slice(
    contracts,
    from: "final class OwnerTruthInterviewCandidateMemoryActivationUseCase",
    to: "// MARK: - Default-off interview session state read"
) else {
    fatalError("owner-truth candidate memory activation check failed: activation use case is missing")
}
require(
    activationUseCase.contains("releasePolicyAvailable()") &&
        activationUseCase.contains("accountLeaseRuntime.validate(accountLease, at: .request).allowed") &&
        activationUseCase.contains("accountLeaseRuntime.validate(accountLease, at: .commit).allowed"),
    "activation use case must be release-policy and AccountLease fenced"
)
require(
    activationUseCase.contains("eligibility.eligibleCandidateIDs.contains(candidateID)") &&
        activationUseCase.contains("confirmation.batchCandidates.contains") &&
        activationUseCase.contains("confirmation.singleCandidates.contains"),
    "activation use case must require a fresh formal confirmation eligibility"
)
require(
    activationUseCase.contains("private var commandID: String?") &&
        activationUseCase.contains("let stableCommandID = commandID ?? commandIDFactory()"),
    "activation retries must preserve the original command id"
)

guard let clientMethod = slice(
    backendClient,
    from: "func activateOwnerTruthInterviewCandidateMemory(",
    to: "func fetchOwnerTruthInterviewSessionState("
) else {
    fatalError("owner-truth candidate memory activation check failed: backend client method is missing")
}
require(
    clientMethod.contains("FeatureGateService.shared.requestDecision(for: .ownerTruthCandidateReview)") &&
        clientMethod.contains("/confirmation/candidates/") &&
        clientMethod.contains("/memory-activation") &&
        clientMethod.contains("featureDecision: decision"),
    "activation client must use the formal default-off route and captured policy decision"
)
require(
    clientMethod.contains("OwnerTruthInterviewCandidateMemoryActivationResult(") &&
        !clientMethod.contains("X-DreamJourney-QA-Owner-Truth") &&
        !clientMethod.contains("/candidate-review"),
    "activation client must parse the formal value-minimized response and never use QA transport"
)
require(
    backendClient.contains("normalizedPath.hasSuffix(\"/memory-activation\")") &&
        backendClient.contains("return .ownerTruthCandidateReview") &&
        backendClient.contains("extension DreamJourneyBackendClient: OwnerTruthInterviewCandidateMemoryActivationClient {}"),
    "activation route must be feature-gated and satisfy its typed client port"
)

for testName in [
    "func testInterviewCandidateMemoryActivationDecodesValueMinimizedResult()",
    "func testInterviewCandidateMemoryActivationUseCaseFailsClosedForPolicyAndEligibility()",
    "func testInterviewCandidateMemoryActivationUseCaseRetriesWithStableCommandID()",
] {
    require(tests.contains(testName), "activation contract test missing: \(testName)")
}

print("owner-truth candidate memory activation check passed")

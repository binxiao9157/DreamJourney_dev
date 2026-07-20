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
    backendClient.contains(".ownerTruthCandidateReview, .profileSettings"),
    "confirmation route must keep owner-text policy handling"
)

print("owner-truth candidate confirmation default-off check passed")

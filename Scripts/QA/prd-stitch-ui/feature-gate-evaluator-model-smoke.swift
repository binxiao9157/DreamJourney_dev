import Foundation

@main
enum FeatureGateEvaluatorModelSmoke {
    static func main() {
        let evaluator = FeatureGateEvaluator()
        let expiresAt = Date(timeIntervalSince1970: 2_000_000_000)
        let allowedPolicy = FeatureGatePolicySnapshot(
            accessMode: .useCachedPolicy,
            policyVersion: "release-policy-v1",
            policyRevision: 12,
            emergencyRevision: 2,
            expiresAt: expiresAt,
            featureEnabled: true,
            releaseVisible: true,
            reason: "closedPilotOwnerCore"
        )

        let route = evaluator.capture(
            feature: .profileSettings,
            risk: .ownerTextCore,
            purpose: .route,
            localEnabled: true,
            qaSyntheticOverride: false,
            accountGeneration: "session-a",
            policy: allowedPolicy
        )
        require(route.allowed, "an allowed route must capture an immutable allow decision")
        require(route.policyRevision == 12, "captured decision must retain policy revision")
        require(route.expiresAt == expiresAt, "captured decision must retain expiry")

        let command = evaluator.revalidateForRequest(
            captured: route,
            localEnabled: true,
            accountGeneration: "session-a",
            currentPolicy: allowedPolicy,
            now: Date(timeIntervalSince1970: 1_900_000_000)
        )
        require(command.allowed, "the same account and policy must allow the request")
        require(command.capturedPolicyRevision == route.policyRevision, "request metadata must retain the route revision")
        let evidence = FeatureDecisionEvidenceSummary(decision: command)
        require(evidence.decisionId == route.decisionId, "QA evidence must retain the captured decision id")
        require(evidence.policyVersion == "release-policy-v1", "QA evidence must expose policy version")
        require(evidence.reason == "capturedPolicyRevalidated", "QA evidence must expose the effect-time reason")

        let switchedAccount = evaluator.revalidateForRequest(
            captured: route,
            localEnabled: true,
            accountGeneration: "session-b",
            currentPolicy: allowedPolicy,
            now: Date(timeIntervalSince1970: 1_900_000_000)
        )
        require(!switchedAccount.allowed, "an account switch must invalidate a captured route decision")
        require(switchedAccount.reason == "accountGenerationChanged", "account switch must be explainable")

        let revokedPolicy = FeatureGatePolicySnapshot(
            accessMode: .useCachedPolicy,
            policyVersion: "release-policy-v1",
            policyRevision: 13,
            emergencyRevision: 3,
            expiresAt: expiresAt,
            featureEnabled: false,
            releaseVisible: false,
            reason: "emergencyRevoked"
        )
        let revoked = evaluator.revalidateForRequest(
            captured: route,
            localEnabled: true,
            accountGeneration: "session-a",
            currentPolicy: revokedPolicy,
            now: Date(timeIntervalSince1970: 1_900_000_000)
        )
        require(!revoked.allowed, "effect-time emergency revoke must deny an old captured allow")
        require(revoked.reason == "emergencyRevoked", "emergency revoke reason must survive revalidation")

        let hiddenPolicy = FeatureGatePolicySnapshot(
            accessMode: .useCachedPolicy,
            policyVersion: "release-policy-v1",
            policyRevision: 12,
            emergencyRevision: 2,
            expiresAt: expiresAt,
            featureEnabled: false,
            releaseVisible: false,
            reason: "notApprovedForClosedPilot"
        )
        let qaRoute = evaluator.capture(
            feature: .voiceCloneShell,
            risk: .providerEffect,
            purpose: .route,
            localEnabled: false,
            qaSyntheticOverride: true,
            accountGeneration: "session-a",
            policy: hiddenPolicy
        )
        require(qaRoute.allowed, "QA may open a synthetic route")
        require(qaRoute.reason == "qaSyntheticRouteOnly", "QA route must be explicitly marked synthetic")
        let qaRequest = evaluator.revalidateForRequest(
            captured: qaRoute,
            localEnabled: false,
            accountGeneration: "session-a",
            currentPolicy: hiddenPolicy,
            now: Date(timeIntervalSince1970: 1_900_000_000)
        )
        require(!qaRequest.allowed, "QA route override must never authorize a real provider request")

        let missingPolicy = FeatureGatePolicySnapshot.unavailable(
            accessMode: .deny,
            reason: "missingPolicyCache"
        )
        let missingFutureRoute = evaluator.capture(
            feature: .timeLetters,
            risk: .futureBeta,
            purpose: .route,
            localEnabled: true,
            qaSyntheticOverride: false,
            accountGeneration: "session-a",
            policy: missingPolicy
        )
        require(!missingFutureRoute.allowed, "future features must fail closed without policy")

        let readOnlyCore = evaluator.capture(
            feature: .profileSettings,
            risk: .ownerTextCore,
            purpose: .route,
            localEnabled: true,
            qaSyntheticOverride: false,
            accountGeneration: "session-a",
            policy: .unavailable(accessMode: .readOnly, reason: "expiredPolicyCache")
        )
        require(readOnlyCore.allowed, "owner core may remain visible in read-only mode")
        let readOnlyCommand = evaluator.revalidateForRequest(
            captured: readOnlyCore,
            localEnabled: true,
            accountGeneration: "session-a",
            currentPolicy: .unavailable(accessMode: .readOnly, reason: "expiredPolicyCache"),
            now: Date(timeIntervalSince1970: 1_900_000_000)
        )
        require(!readOnlyCommand.allowed, "read-only fallback must not authorize a write request")

        let changedVersion = FeatureGatePolicySnapshot(
            accessMode: .useCachedPolicy,
            policyVersion: "release-policy-v2",
            policyRevision: 14,
            emergencyRevision: 3,
            expiresAt: expiresAt,
            featureEnabled: true,
            releaseVisible: true,
            reason: "closedPilotOwnerCore"
        )
        let changedVersionRequest = evaluator.revalidateForRequest(
            captured: route,
            localEnabled: true,
            accountGeneration: "session-a",
            currentPolicy: changedVersion,
            now: Date(timeIntervalSince1970: 1_900_000_000)
        )
        require(!changedVersionRequest.allowed, "a changed policy version must invalidate a captured route")
        require(changedVersionRequest.reason == "policyVersionChanged", "policy version changes must be explainable")

        let expiredCapture = evaluator.revalidateForRequest(
            captured: route,
            localEnabled: true,
            accountGeneration: "session-a",
            currentPolicy: allowedPolicy,
            now: expiresAt.addingTimeInterval(1)
        )
        require(!expiredCapture.allowed, "an expired captured route must not authorize a request")
        require(expiredCapture.reason == "capturedPolicyExpired", "captured policy expiry must be explainable")

        print("Feature gate evaluator model smoke passed")
    }

    private static func require(_ condition: @autoclosure () -> Bool, _ message: String) {
        guard condition() else {
            fputs("Feature gate evaluator model smoke failed: \(message)\n", stderr)
            exit(1)
        }
    }
}

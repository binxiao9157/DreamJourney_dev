import Foundation

@main
enum PublicReleaseScopeModelSmoke {
    static func main() throws {
        guard let outputPath = CommandLine.arguments.dropFirst().first else {
            fatalError("output path is required")
        }

        let evaluator = FeatureGateEvaluator()
        let now = Date(timeIntervalSince1970: 1_900_000_000)
        let expiresAt = now.addingTimeInterval(600)
        let ownerCore: [DJFeature] = [
            .echoTextInput,
            .profileSettings,
            .legalCenter,
            .accountDeletion,
        ]
        let hidden: [DJFeature] = [
            .echoImageInput,
            .timeLetters,
            .personaSettings,
            .archiveAudioUpload,
            .archiveVideoUpload,
            .archiveRemoteFetch,
            .archiveLocalAnalysis,
            .familyManagement,
            .familySpace,
            .accountPasswordChange,
            .careDashboard,
            .careDoctorContact,
            .voiceCloneShell,
            .digitalHumanLivePanel,
        ]
        let freshOwnerPolicy = FeatureGatePolicySnapshot(
            accessMode: .useCachedPolicy,
            policyVersion: "release-policy-v1",
            policyRevision: 1,
            emergencyRevision: 0,
            expiresAt: expiresAt,
            featureEnabled: true,
            releaseVisible: true,
            reason: "closedPilotOwnerCore"
        )
        let hiddenPolicy = FeatureGatePolicySnapshot(
            accessMode: .useCachedPolicy,
            policyVersion: "release-policy-v1",
            policyRevision: 1,
            emergencyRevision: 0,
            expiresAt: expiresAt,
            featureEnabled: false,
            releaseVisible: false,
            reason: "notApprovedForClosedPilot"
        )

        var ownerRouteAllowedCount = 0
        var ownerCommandAllowedCount = 0
        for feature in ownerCore {
            let route = evaluator.capture(
                feature: feature,
                risk: .ownerTextCore,
                purpose: .route,
                localEnabled: true,
                qaSyntheticOverride: false,
                accountGeneration: "owner-generation",
                policy: freshOwnerPolicy
            )
            if route.allowed { ownerRouteAllowedCount += 1 }
            let command = evaluator.revalidateForRequest(
                captured: route,
                localEnabled: true,
                accountGeneration: "owner-generation",
                currentPolicy: freshOwnerPolicy,
                now: now
            )
            if command.allowed { ownerCommandAllowedCount += 1 }
        }

        let hiddenRouteAllowedCount = hidden.filter { feature in
            evaluator.capture(
                feature: feature,
                risk: feature == .voiceCloneShell || feature == .digitalHumanLivePanel ? .providerEffect : .futureBeta,
                purpose: .route,
                localEnabled: false,
                qaSyntheticOverride: false,
                accountGeneration: "owner-generation",
                policy: hiddenPolicy
            ).allowed
        }.count

        let missingFutureAllowed = evaluator.capture(
            feature: .timeLetters,
            risk: .futureBeta,
            purpose: .route,
            localEnabled: true,
            qaSyntheticOverride: false,
            accountGeneration: "owner-generation",
            policy: .unavailable(accessMode: .deny, reason: "missingPolicyCache")
        ).allowed
        let expiredProviderAllowed = evaluator.capture(
            feature: .digitalHumanLivePanel,
            risk: .providerEffect,
            purpose: .route,
            localEnabled: true,
            qaSyntheticOverride: false,
            accountGeneration: "owner-generation",
            policy: .unavailable(accessMode: .deny, reason: "expiredPolicyCache")
        ).allowed
        let readOnlyCoreRoute = evaluator.capture(
            feature: .profileSettings,
            risk: .ownerTextCore,
            purpose: .route,
            localEnabled: true,
            qaSyntheticOverride: false,
            accountGeneration: "owner-generation",
            policy: .unavailable(accessMode: .readOnly, reason: "expiredPolicyCache")
        )
        let readOnlyCoreCommand = evaluator.revalidateForRequest(
            captured: readOnlyCoreRoute,
            localEnabled: true,
            accountGeneration: "owner-generation",
            currentPolicy: .unavailable(accessMode: .readOnly, reason: "expiredPolicyCache"),
            now: now
        )
        let emergencyRevokedAllowed = evaluator.capture(
            feature: .voiceCloneShell,
            risk: .providerEffect,
            purpose: .route,
            localEnabled: true,
            qaSyntheticOverride: false,
            accountGeneration: "owner-generation",
            policy: FeatureGatePolicySnapshot(
                accessMode: .useCachedPolicy,
                policyVersion: "release-policy-v1",
                policyRevision: 2,
                emergencyRevision: 1,
                expiresAt: expiresAt,
                featureEnabled: false,
                releaseVisible: false,
                reason: "emergencyRevoked"
            )
        ).allowed
        let qaRoute = evaluator.capture(
            feature: .voiceCloneShell,
            risk: .providerEffect,
            purpose: .route,
            localEnabled: false,
            qaSyntheticOverride: true,
            accountGeneration: "owner-generation",
            policy: hiddenPolicy
        )
        let qaCommand = evaluator.revalidateForRequest(
            captured: qaRoute,
            localEnabled: false,
            accountGeneration: "owner-generation",
            currentPolicy: hiddenPolicy,
            now: now
        )

        require(ownerRouteAllowedCount == ownerCore.count, "owner core routes must remain available")
        require(ownerCommandAllowedCount == ownerCore.count, "owner core commands must remain available")
        require(hiddenRouteAllowedCount == 0, "hidden routes must remain unavailable")
        require(!missingFutureAllowed, "offline future routes must deny")
        require(!expiredProviderAllowed, "expired provider routes must deny")
        require(readOnlyCoreRoute.allowed && !readOnlyCoreCommand.allowed, "expired owner core must be route-only read-only")
        require(!emergencyRevokedAllowed, "emergency-revoked routes must deny")
        require(qaRoute.allowed && !qaCommand.allowed, "QA may open only a synthetic route")

        let result: [String: Any] = [
            "schemaVersion": 1,
            "policy": [
                "policyVersion": "release-policy-v1",
                "policyRevision": 1,
                "offlineFutureDenied": !missingFutureAllowed,
                "expiredProviderDenied": !expiredProviderAllowed,
                "expiredOwnerCoreReadOnly": readOnlyCoreRoute.allowed && !readOnlyCoreCommand.allowed,
                "emergencyRevokedDenied": !emergencyRevokedAllowed,
            ],
            "features": [
                "ownerCore": ownerCore.map(\.rawValue).sorted(),
                "hidden": hidden.map(\.rawValue).sorted(),
            ],
            "routes": [
                "ownerCoreAllowedCount": ownerRouteAllowedCount,
                "ownerCoreCommandAllowedCount": ownerCommandAllowedCount,
                "hiddenAllowedCount": hiddenRouteAllowedCount,
                "qaRouteAllowed": qaRoute.allowed,
                "qaCommandAllowed": qaCommand.allowed,
            ],
        ]
        let data = try JSONSerialization.data(withJSONObject: result, options: [.prettyPrinted, .sortedKeys])
        let outputURL = URL(fileURLWithPath: outputPath)
        try FileManager.default.createDirectory(at: outputURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try data.write(to: outputURL, options: .atomic)
        print("Public Release Scope model smoke passed")
    }

    private static func require(_ condition: @autoclosure () -> Bool, _ message: String) {
        guard condition() else { fatalError(message) }
    }
}

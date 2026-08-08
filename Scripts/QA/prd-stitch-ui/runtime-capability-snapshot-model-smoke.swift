import Foundation

@main
enum RuntimeCapabilitySnapshotModelSmoke {
    static func main() {
        let completeJSON: [String: Any] = [
            "schemaVersion": 1,
            "capability": "voiceCloneShell",
            "implemented": true,
            "enabled": true,
            "providerReady": true,
            "releaseVisible": false,
            "externalVerified": false,
            "provider": "volcengine",
            "fallbackMode": "providerProxy",
            "reason": "externalEvidenceMissing",
            "evidenceTimestamp": NSNull(),
            "providerKind": "voiceCloneAndSynthesis",
            "operation": "trainQuerySynthesizeDelete",
            "dataClass": "authorizedAdultVoiceSample",
            "region": "providerManaged",
            "retentionPolicyVersion": "voiceProfileRetention-v1",
            "configurationStatus": "valid",
            "evidenceStatus": "notVerified",
        ]

        guard let complete = RuntimeCapabilitySnapshot(json: completeJSON) else {
            fputs("Runtime capability snapshot model smoke failed: complete schema did not decode\n", stderr)
            exit(1)
        }
        require(complete.contractComplete, "new schema should be complete")
        require(complete.isRuntimeContractUsable, "complete internal capability contract should remain usable")
        require(complete.isProviderEffectAllowed, "ready provider should allow provider effects")
        require(complete.isProviderOperational, "configured provider should be operational")
        require(!complete.isPubliclyAvailable, "provider ready must not imply release/external ready")
        require(complete.readiness == .externalVerificationMissing, "missing G3/G4 evidence should be explicit")
        require(complete.providerMetadataComplete, "provider metadata should decode from a complete runtime contract")
        require(complete.providerKind == "voiceCloneAndSynthesis", "provider kind should remain typed")
        require(complete.controlState == .legacy, "older schema-v1 payloads should remain legacy-compatible")

        let controlledReadyJSON = completeJSON.merging([
            "controlState": "ready",
            "readinessEpoch": "rce-fixture-ready",
            "readinessObservedAt": "2099-01-01T00:00:00Z",
            "readinessExpiresAt": "2099-01-01T00:05:00Z",
        ]) { _, new in new }
        guard let controlledReady = RuntimeCapabilitySnapshot(json: controlledReadyJSON) else {
            fatalError("controlled ready runtime snapshot failed to decode")
        }
        require(controlledReady.controlContractComplete, "controlled snapshot must include a complete epoch contract")
        require(controlledReady.isReadinessEpochUsable(at: Date(timeIntervalSince1970: 4_070_908_860)), "fresh readiness epoch should be usable")
        require(controlledReady.isProviderEffectAllowed, "fresh controlled provider should allow effects")

        let controlledBlockedJSON = completeJSON.merging([
            "providerReady": false,
            "reason": "runtimeCapabilityBacklogExceeded",
            "controlState": "blocked",
            "readinessEpoch": NSNull(),
            "readinessObservedAt": "2099-01-01T00:00:00Z",
            "readinessExpiresAt": "2099-01-01T00:05:00Z",
        ]) { _, new in new }
        let controlledBlocked = RuntimeCapabilitySnapshot(json: controlledBlockedJSON)
        require(controlledBlocked?.isRuntimeContractUsable == false, "blocked control state must fail closed")
        require(controlledBlocked?.isProviderEffectAllowed == false, "blocked state must reject provider effects")
        RuntimeCapabilitySnapshotStore.shared.replace(with: [
            RuntimeCapabilityID.ownerTruthMediaStorage.rawValue: controlledReady,
        ])
        require(
            RuntimeCapabilitySnapshotStore.shared.snapshot(for: .ownerTruthMediaStorage)?.readinessEpoch == "rce-fixture-ready",
            "ready epoch should enter the snapshot cache"
        )
        if let controlledBlocked {
            RuntimeCapabilitySnapshotStore.shared.replace(with: [
                RuntimeCapabilityID.ownerTruthMediaStorage.rawValue: controlledBlocked,
            ])
        }
        require(
            RuntimeCapabilitySnapshotStore.shared.snapshot(for: .ownerTruthMediaStorage)?.readinessEpoch == nil,
            "a blocked replacement must not retain the previous ready epoch"
        )
        RuntimeCapabilitySnapshotStore.shared.invalidate()

        let malformedControlledJSON = completeJSON.merging([
            "controlState": "ready",
            "readinessEpoch": NSNull(),
            "readinessObservedAt": "2099-01-01T00:00:00Z",
            "readinessExpiresAt": "2099-01-01T00:05:00Z",
        ]) { _, new in new }
        require(RuntimeCapabilitySnapshot(json: malformedControlledJSON) == nil, "ready state without epoch must fail decoding")

        let legacy = RuntimeCapabilitySnapshot.conservativeLegacy(
            capability: "voiceCloneShell",
            implemented: true,
            enabled: true,
            providerReady: true,
            provider: "legacy"
        )
        require(!legacy.contractComplete, "legacy aliases must remain incomplete")
        require(!legacy.isRuntimeContractUsable, "legacy aliases must not unlock runtime effects")
        require(!legacy.isProviderEffectAllowed, "legacy aliases must not unlock provider effects")
        require(!legacy.isProviderOperational, "legacy providerReady alias must not unlock provider effects")
        require(!legacy.isPubliclyAvailable, "legacy aliases must fail closed")
        require(legacy.readiness == .unknown, "legacy aliases should render unknown")
        require(!legacy.providerMetadataComplete, "legacy aliases should not invent provider metadata")

        let staleJSON: [String: Any] = [
            "schemaVersion": 1,
            "capability": "fixture",
            "implemented": true,
            "enabled": true,
            "providerReady": true,
            "releaseVisible": true,
            "externalVerified": false,
            "provider": "fixture",
            "fallbackMode": "none",
            "reason": "externalEvidenceStale",
            "evidenceTimestamp": "2026-01-01T00:00:00Z",
        ]
        let stale = RuntimeCapabilitySnapshot(json: staleJSON)
        require(stale?.readiness == .externalEvidenceStale, "stale external evidence should remain distinct")
        require(stale?.isRuntimeContractUsable == false, "stale evidence must fail closed for runtime actions")
        require(stale?.isProviderEffectAllowed == false, "stale evidence must fail closed for provider effects")

        let unavailableJSON: [String: Any] = [
            "schemaVersion": 1,
            "capability": "fixture",
            "implemented": true,
            "enabled": true,
            "providerReady": false,
            "releaseVisible": false,
            "externalVerified": false,
            "provider": "fixture",
            "fallbackMode": "none",
            "reason": "providerUnavailable",
        ]
        let unavailable = RuntimeCapabilitySnapshot(json: unavailableJSON)
        require(unavailable?.isRuntimeContractUsable == true, "provider state should remain separately diagnosable")
        require(unavailable?.isProviderEffectAllowed == false, "unready provider must not receive effects")

        print("Runtime capability snapshot model smoke passed")
    }
}

private func require(_ condition: @autoclosure () -> Bool, _ message: String) {
    if !condition() {
        fputs("Runtime capability snapshot model smoke failed: \(message)\n", stderr)
        exit(1)
    }
}

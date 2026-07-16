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
        ]

        guard let complete = RuntimeCapabilitySnapshot(json: completeJSON) else {
            fputs("Runtime capability snapshot model smoke failed: complete schema did not decode\n", stderr)
            exit(1)
        }
        require(complete.contractComplete, "new schema should be complete")
        require(complete.isProviderOperational, "configured provider should be operational")
        require(!complete.isPubliclyAvailable, "provider ready must not imply release/external ready")
        require(complete.readiness == .externalVerificationMissing, "missing G3/G4 evidence should be explicit")

        let legacy = RuntimeCapabilitySnapshot.conservativeLegacy(
            capability: "voiceCloneShell",
            implemented: true,
            enabled: true,
            providerReady: true,
            provider: "legacy"
        )
        require(!legacy.contractComplete, "legacy aliases must remain incomplete")
        require(!legacy.isProviderOperational, "legacy providerReady alias must not unlock provider effects")
        require(!legacy.isPubliclyAvailable, "legacy aliases must fail closed")
        require(legacy.readiness == .unknown, "legacy aliases should render unknown")

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

        print("Runtime capability snapshot model smoke passed")
    }
}

private func require(_ condition: @autoclosure () -> Bool, _ message: String) {
    if !condition() {
        fputs("Runtime capability snapshot model smoke failed: \(message)\n", stderr)
        exit(1)
    }
}

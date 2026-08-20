import Foundation

@main
enum OwnerTruthMediaRuntimeCapabilitySmoke {
    static func main() {
        let storage = snapshot(
            capability: RuntimeCapabilityID.ownerTruthMediaStorage.rawValue,
            releaseVisible: true,
            enabled: true,
            providerReady: true,
            externalVerified: true,
            provider: "cos"
        )
        let processing = snapshot(
            capability: RuntimeCapabilityID.ownerTruthMediaProcessing.rawValue,
            releaseVisible: true,
            enabled: true,
            providerReady: true,
            externalVerified: true,
            provider: "builtInDocumentProcessor"
        )
        let ready = OwnerTruthMediaRuntimeCapability(
            json: runtimeJSON,
            snapshots: [
                storage.capability: storage,
                processing.capability: processing,
            ]
        )
        require(ready.contractComplete, "complete server contract must decode")
        require(ready.canOpenCapture, "server-approved capture should be usable")
        require(ready.canReceiveProcessingUpdates, "server-approved processing should be usable")
        require(ready.supports(kind: "document"), "document capture must remain listed")

        let releaseHiddenStorage = snapshot(
            capability: RuntimeCapabilityID.ownerTruthMediaStorage.rawValue,
            releaseVisible: false,
            enabled: true,
            providerReady: true,
            externalVerified: true,
            provider: "cos"
        )
        let hidden = OwnerTruthMediaRuntimeCapability(
            json: runtimeJSON,
            snapshots: [
                releaseHiddenStorage.capability: releaseHiddenStorage,
                processing.capability: processing,
            ]
        )
        require(!hidden.canOpenCapture, "release-hidden capture must fail closed")

        let unverifiedStorage = snapshot(
            capability: RuntimeCapabilityID.ownerTruthMediaStorage.rawValue,
            releaseVisible: true,
            enabled: true,
            providerReady: true,
            externalVerified: false,
            provider: "cos"
        )
        let internalOnly = OwnerTruthMediaRuntimeCapability(
            json: runtimeJSON,
            snapshots: [
                unverifiedStorage.capability: unverifiedStorage,
                processing.capability: processing,
            ]
        )
        require(!internalOnly.canOpenCapture, "ordinary users require external verification")
        require(
            internalOnly.canOpenCaptureWithInternalEntitlement,
            "an independent internal entitlement may use an operational provider"
        )

        let filesystemStorage = snapshot(
            capability: RuntimeCapabilityID.ownerTruthMediaStorage.rawValue,
            releaseVisible: true,
            enabled: true,
            providerReady: true,
            externalVerified: true,
            provider: "filesystem"
        )
        let filesystem = OwnerTruthMediaRuntimeCapability(
            json: runtimeJSON,
            snapshots: [
                filesystemStorage.capability: filesystemStorage,
                processing.capability: processing,
            ]
        )
        require(!filesystem.canOpenCapture, "filesystem must never be a public media provider")
        require(
            filesystem.canOpenCaptureWithInternalEntitlement,
            "filesystem remains available only behind an internal entitlement"
        )

        let unavailableStorage = snapshot(
            capability: RuntimeCapabilityID.ownerTruthMediaStorage.rawValue,
            releaseVisible: true,
            enabled: false,
            providerReady: false,
            externalVerified: false,
            provider: "cos"
        )
        let unavailable = OwnerTruthMediaRuntimeCapability(
            json: runtimeJSON,
            snapshots: [
                unavailableStorage.capability: unavailableStorage,
                processing.capability: processing,
            ]
        )
        require(!unavailable.canOpenCapture, "incomplete provider config must fail closed")

        print("Owner Truth media runtime capability smoke passed")
    }

    private static let runtimeJSON: [String: Any] = [
        "captureCapability": "ownerTruthMediaStorage",
        "processingCapability": "ownerTruthMediaProcessing",
        "uploadIntentEndpointTemplate": "/v2/vaults/{vaultId}/source-objects/upload-intents",
        "contentEndpointTemplate": "/v2/vaults/{vaultId}/source-objects/upload-intents/{intentId}/content",
        "supportedMediaKinds": ["document", "image", "audio", "video"],
        "contractVersion": 1,
    ]

    private static func snapshot(
        capability: String,
        releaseVisible: Bool,
        enabled: Bool,
        providerReady: Bool,
        externalVerified: Bool,
        provider: String
    ) -> RuntimeCapabilitySnapshot {
        guard let decoded = RuntimeCapabilitySnapshot(json: [
            "schemaVersion": 1,
            "capability": capability,
            "implemented": true,
            "enabled": enabled,
            "providerReady": providerReady,
            "releaseVisible": releaseVisible,
            "externalVerified": externalVerified,
            "provider": provider,
            "fallbackMode": "captureDisabled",
            "reason": enabled
                ? (externalVerified ? "ready" : "externalEvidenceMissing")
                : "providerConfigurationIncomplete",
            "providerKind": "privateObjectStorage",
            "operation": "writeReadDeleteWithSafetyScan",
            "dataClass": "ownerPrivateMedia",
            "region": "fixture",
            "retentionPolicyVersion": "ownerTruthMediaRetention-v1",
            "configurationStatus": enabled ? "valid" : "incomplete",
            "evidenceStatus": externalVerified ? "externallyVerified" : "notVerified",
        ]) else {
            fatalError("fixture runtime snapshot failed to decode")
        }
        return decoded
    }
}

private func require(_ condition: @autoclosure () -> Bool, _ message: String) {
    guard condition() else {
        fputs("Owner Truth media runtime capability smoke failed: \(message)\n", stderr)
        exit(1)
    }
}

import Foundation

/// Typed, server-authored admission state for the V4 private media routes.
/// It is deliberately separate from the older archive metadata-sync contract:
/// this model only permits the authenticated Owner Truth capture route when
/// the server's capability snapshot and release decision both allow it.
struct OwnerTruthMediaRuntimeCapability: Equatable {
    static let contractVersion = 1
    static let captureCapabilityID = RuntimeCapabilityID.ownerTruthMediaStorage.rawValue
    static let processingCapabilityID = RuntimeCapabilityID.ownerTruthMediaProcessing.rawValue
    static let uploadIntentEndpointTemplate = "/v2/vaults/{vaultId}/source-objects/upload-intents"
    static let contentEndpointTemplate = "/v2/vaults/{vaultId}/source-objects/upload-intents/{intentId}/content"

    let captureCapabilityID: String
    let processingCapabilityID: String
    let uploadIntentEndpointTemplate: String
    let contentEndpointTemplate: String
    let supportedMediaKinds: [String]
    let contractVersion: Int
    let captureSnapshot: RuntimeCapabilitySnapshot
    let processingSnapshot: RuntimeCapabilitySnapshot
    let contractComplete: Bool

    /// A client cannot self-enable this path: both the provider and the
    /// server-issued cohort decision must be ready in the same response.
    var canOpenCapture: Bool {
        contractComplete
            && captureSnapshot.isProviderEffectAllowed
            && captureSnapshot.releaseVisible
    }

    var canReceiveProcessingUpdates: Bool {
        contractComplete
            && processingSnapshot.isProviderEffectAllowed
            && processingSnapshot.releaseVisible
    }

    var diagnosticSummary: String {
        [
            "capture=\(captureSnapshot.diagnosticSummary)",
            "processing=\(processingSnapshot.diagnosticSummary)",
            "captureRoute=\(uploadIntentEndpointTemplate)",
            "processingAvailable=\(canReceiveProcessingUpdates)",
            "contractComplete=\(contractComplete)",
        ].joined(separator: " ")
    }

    init(
        json: [String: Any]?,
        snapshots: [String: RuntimeCapabilitySnapshot]
    ) {
        let parsedCaptureCapabilityID = json?["captureCapability"] as? String
        let parsedProcessingCapabilityID = json?["processingCapability"] as? String
        let parsedUploadIntentEndpoint = json?["uploadIntentEndpointTemplate"] as? String
        let parsedContentEndpoint = json?["contentEndpointTemplate"] as? String
        let parsedMediaKinds = json?["supportedMediaKinds"] as? [String]
        let parsedContractVersion = Self.intValue(json?["contractVersion"])

        captureCapabilityID = parsedCaptureCapabilityID ?? Self.captureCapabilityID
        processingCapabilityID = parsedProcessingCapabilityID ?? Self.processingCapabilityID
        uploadIntentEndpointTemplate = parsedUploadIntentEndpoint ?? Self.uploadIntentEndpointTemplate
        contentEndpointTemplate = parsedContentEndpoint ?? Self.contentEndpointTemplate
        supportedMediaKinds = parsedMediaKinds ?? []
        contractVersion = parsedContractVersion ?? 0

        captureSnapshot = snapshots[captureCapabilityID]
            ?? RuntimeCapabilitySnapshot.conservativeLegacy(
                capability: captureCapabilityID,
                implemented: true,
                enabled: false,
                providerReady: false,
                provider: "unknown",
                fallbackMode: "captureDisabled"
            )
        processingSnapshot = snapshots[processingCapabilityID]
            ?? RuntimeCapabilitySnapshot.conservativeLegacy(
                capability: processingCapabilityID,
                implemented: true,
                enabled: false,
                providerReady: false,
                provider: "unknown",
                fallbackMode: "processingPending"
            )
        contractComplete = parsedCaptureCapabilityID == Self.captureCapabilityID
            && parsedProcessingCapabilityID == Self.processingCapabilityID
            && parsedUploadIntentEndpoint == Self.uploadIntentEndpointTemplate
            && parsedContentEndpoint == Self.contentEndpointTemplate
            && parsedMediaKinds?.isEmpty == false
            && parsedContractVersion == Self.contractVersion
            && captureSnapshot.capability == Self.captureCapabilityID
            && processingSnapshot.capability == Self.processingCapabilityID
    }

    func supports(kind: String) -> Bool {
        supportedMediaKinds.contains(kind)
    }

    private static func intValue(_ value: Any?) -> Int? {
        if let value = value as? Int { return value }
        if let value = value as? NSNumber { return value.intValue }
        if let value = value as? String { return Int(value) }
        return nil
    }
}

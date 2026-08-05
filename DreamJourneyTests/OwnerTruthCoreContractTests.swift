import XCTest

@testable import DreamJourneyCore

final class OwnerTruthCoreContractTests: XCTestCase {
    func testTextSourceCaptureCommandRemainsPureDomainContract() throws {
        let command = try OwnerTruthTextSourceCaptureCommand(
            commandID: UUID(uuidString: "00000000-0000-0000-0000-000000000401")!,
            expectedAuthorityEpoch: 3,
            text: "  我记得那天傍晚一起散步。  ",
            purpose: "memoryCapture",
            clientCreatedAt: Date(timeIntervalSince1970: 1_775_000_000)
        )

        XCTAssertEqual(command.backendPayload["content"] as? String, "我记得那天傍晚一起散步。")
        XCTAssertEqual(command.backendPayload["expectedAuthorityEpoch"] as? Int, 3)
        XCTAssertEqual(command.backendPayload["purpose"] as? String, "memoryCapture")
    }

    func testMediaUploadIntentCommandKeepsOwnerAndStorageAuthorityOnServer() throws {
        let body = Data("A private document".utf8)
        let command = try OwnerTruthMediaUploadIntentCommand(
            commandID: UUID(uuidString: "00000000-0000-0000-0000-000000000403")!,
            expectedAuthorityEpoch: 3,
            mediaKind: .document,
            fileName: "memory.txt",
            contentType: "text/plain",
            content: body,
            purpose: "memoryCapture",
            clientCreatedAt: Date(timeIntervalSince1970: 1_775_000_000)
        )

        XCTAssertEqual(Set(command.backendPayload.keys), [
            "commandId",
            "expectedAuthorityEpoch",
            "mediaKind",
            "fileName",
            "contentType",
            "fileSizeBytes",
            "contentSha256",
            "purpose",
            "clientCreatedAt",
        ])
        XCTAssertEqual(command.backendPayload["fileSizeBytes"] as? Int, body.count)
        XCTAssertNil(command.backendPayload["ownerSubjectId"])
        XCTAssertNil(command.backendPayload["vaultId"])
        XCTAssertNil(command.backendPayload["storageKey"])
        XCTAssertNil(command.backendPayload["objectURL"])
    }

    func testMediaUploadIntentReceiptRetainsOneTimeTokenWithoutPrivateStorageFields() throws {
        let vaultID = try XCTUnwrap(OwnerTruthVaultID("vault-media-a"))
        let response: [String: Any] = [
            "schemaVersion": OwnerTruthMediaUploadIntentReceipt.schemaVersion,
            "status": "created",
            "vaultId": vaultID.rawValue,
            "sourceObject": mediaSourceObjectJSON(),
            "uploadIntent": [
                "uploadIntentId": "00000000-0000-0000-0000-000000000405",
                "state": "pending",
                "expiresAt": "2026-08-03T12:15:00Z",
                "transport": "authenticatedDirectUpload",
                "uploadMethod": "PUT",
                "uploadTokenHeader": "X-DreamJourney-Upload-Token",
                "requiresClientUpload": true,
                "uploadToken": "one-time-upload-token-that-is-long-enough",
            ],
        ]

        let receipt = try OwnerTruthMediaUploadIntentReceipt(
            backendJSONObject: response,
            expectedVaultID: vaultID
        )

        XCTAssertEqual(receipt.outcome, .created)
        XCTAssertEqual(receipt.uploadIntent.state, .pending)
        XCTAssertNotNil(receipt.uploadIntent.uploadToken)

        var unsafe = response
        unsafe["storageKey"] = "must-not-cross-client-boundary"
        XCTAssertThrowsError(
            try OwnerTruthMediaUploadIntentReceipt(
                backendJSONObject: unsafe,
                expectedVaultID: vaultID
            )
        )
    }

    func testMediaSourceObjectResponseParsesProcessingStateAndRejectsPrivateFields() throws {
        let vaultID = try XCTUnwrap(OwnerTruthVaultID("vault-media-a"))
        let sourceObjectID = OwnerTruthRecordID(
            rawValue: UUID(uuidString: "00000000-0000-0000-0000-000000000404")!
        )
        var sourceObject = mediaSourceObjectJSON()
        sourceObject["state"] = "processed"
        sourceObject["processingStatus"] = "succeeded"
        sourceObject["derivedSourceId"] = "00000000-0000-0000-0000-000000000406"
        let response: [String: Any] = [
            "schemaVersion": OwnerTruthMediaSourceObjectResponse.schemaVersion,
            "vaultId": vaultID.rawValue,
            "sourceObject": sourceObject,
        ]

        let receipt = try OwnerTruthMediaSourceObjectResponse(
            backendJSONObject: response,
            expectedVaultID: vaultID,
            expectedSourceObjectID: sourceObjectID
        )

        XCTAssertEqual(receipt.sourceObject.state, .processed)
        XCTAssertEqual(receipt.sourceObject.processingStatus, .succeeded)
        XCTAssertNotNil(receipt.sourceObject.derivedSourceID)

        sourceObject["storageKey"] = "private/object/key"
        var unsafe = response
        unsafe["sourceObject"] = sourceObject
        XCTAssertThrowsError(
            try OwnerTruthMediaSourceObjectResponse(
                backendJSONObject: unsafe,
                expectedVaultID: vaultID,
                expectedSourceObjectID: sourceObjectID
            )
        )
    }

    func testMediaDeletionReceiptRemainsValueMinimizedAndRequiresRevokedAccess() throws {
        let vaultID = try XCTUnwrap(OwnerTruthVaultID("vault-media-a"))
        let sourceObjectID = OwnerTruthRecordID(
            rawValue: UUID(uuidString: "00000000-0000-0000-0000-000000000404")!
        )
        let command = try OwnerTruthMediaDeletionCommand(
            commandID: UUID(uuidString: "00000000-0000-0000-0000-000000000407")!,
            expectedAuthorityEpoch: 3,
            clientRequestedAt: Date(timeIntervalSince1970: 1_775_000_100)
        )
        XCTAssertEqual(Set(command.backendPayload.keys), [
            "commandId", "expectedAuthorityEpoch", "clientRequestedAt",
        ])
        XCTAssertNil(command.backendPayload["storageKey"])
        XCTAssertNil(command.backendPayload["provider"])

        var sourceObject = mediaSourceObjectJSON()
        sourceObject["state"] = "deleted"
        sourceObject["processingStatus"] = "blocked"
        let response: [String: Any] = [
            "schemaVersion": OwnerTruthMediaDeletionReceipt.schemaVersion,
            "status": OwnerTruthMediaDeletionOutcome.deletionRequested.rawValue,
            "vaultId": vaultID.rawValue,
            "sourceObject": sourceObject,
            "deletion": [
                "accessState": OwnerTruthMediaAccessState.accessRevoked.rawValue,
                "deletionStatus": OwnerTruthMediaDeletionStatus.pending.rawValue,
                "retryable": true,
                "failureCode": NSNull(),
                "updatedAt": "2026-08-05T12:00:00Z",
            ],
        ]

        let receipt = try OwnerTruthMediaDeletionReceipt(
            backendJSONObject: response,
            expectedVaultID: vaultID,
            expectedSourceObjectID: sourceObjectID
        )
        XCTAssertEqual(receipt.accessState, .accessRevoked)
        XCTAssertEqual(receipt.deletionStatus, .pending)
        XCTAssertTrue(receipt.retryable)

        var unsafe = response
        unsafe["providerReceipt"] = "must-not-cross-client-boundary"
        XCTAssertThrowsError(
            try OwnerTruthMediaDeletionReceipt(
                backendJSONObject: unsafe,
                expectedVaultID: vaultID,
                expectedSourceObjectID: sourceObjectID
            )
        )
    }

    func testCompatibilityRuntimeAcceptsAnInjectedCoreClient() {
        let runtime = OwnerTruthKBLiteCompatibilityProjectionRuntime(
            client: CoreKBLiteCompatibilityClient(),
            qaGateEnabled: { false }
        )

        XCTAssertEqual(runtime.viewState, .idle)
    }

    func testAccountLeaseKeepsVaultAndAuthorityTogether() {
        let lease = AccountLease(
            subjectId: "owner-a",
            vaultId: "vault-a",
            sessionId: "session-a",
            generation: 4,
            generationId: UUID(uuidString: "00000000-0000-0000-0000-000000000402")!,
            authorityEpoch: "authority-a"
        )

        XCTAssertEqual(lease.subjectId, "owner-a")
        XCTAssertEqual(lease.vaultId, "vault-a")
        XCTAssertEqual(lease.authorityEpoch, "authority-a")
    }

    private func mediaSourceObjectJSON() -> [String: Any] {
        [
            "sourceObjectId": "00000000-0000-0000-0000-000000000404",
            "mediaKind": "document",
            "state": "uploadPending",
            "contentType": "text/plain",
            "magicMime": NSNull(),
            "fileName": "memory.txt",
            "fileSizeBytes": 18,
            "contentSha256": String(repeating: "a", count: 64),
            "safetyStatus": "pending",
            "safetyProvider": NSNull(),
            "processingStatus": "notQueued",
            "processingGeneration": 0,
            "externalProcessingAllowed": false,
            "retryable": false,
            "failureCode": NSNull(),
            "derivedSourceId": NSNull(),
            "updatedAt": "2026-08-03T12:00:00Z",
        ]
    }
}

private final class CoreKBLiteCompatibilityClient: OwnerTruthKBLiteCompatibilityClient {
    func fetchOwnerTruthKBLiteCompatibilityReadEnvelope(
        vaultID: OwnerTruthVaultID,
        expectedOwnerSubjectID: String,
        completion: @escaping (Result<OwnerTruthKBLiteCompatibilityReadEnvelope, Error>) -> Void
    ) {
        completion(.failure(CoreKBLiteCompatibilityClientError.unused))
    }
}

private enum CoreKBLiteCompatibilityClientError: Error {
    case unused
}

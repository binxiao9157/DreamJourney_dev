import XCTest
#if canImport(DreamJourney)
@testable import DreamJourney
#elseif canImport(DreamJourneyCore)
@testable import DreamJourneyCore
#endif

final class PublicationManagementAccessTests: XCTestCase {
    func testReadUseCaseLoadsRedactedPublicationAndGrantSummaries() throws {
        let runtime = makeRuntime(subjectID: "owner-a", vaultID: "vault-a", generation: 4)
        let lease = try XCTUnwrap(runtime.capture(forSubjectId: "owner-a"))
        let client = PublicationManagementReaderClientStub()
        client.publicationsResult = .success(try makePublicationList(vaultID: "vault-a"))
        client.grantsResult = .success(try makeGrantList(vaultID: "vault-a"))
        let useCase = PublicationManagementReadUseCase(client: client, accountLeaseRuntime: runtime)

        let expectation = expectation(description: "management snapshot")
        useCase.load(accountLease: lease) { result in
            guard case let .success(snapshot) = result else {
                XCTFail("Expected a publication management snapshot")
                expectation.fulfill()
                return
            }
            XCTAssertEqual(snapshot.vaultID, "vault-a")
            XCTAssertEqual(snapshot.publications.count, 1)
            XCTAssertEqual(snapshot.publications.first?.previewTitle, "院子里的雨声")
            XCTAssertEqual(snapshot.publications.first?.publicationState, "confirmed")
            XCTAssertEqual(snapshot.grants.count, 1)
            XCTAssertEqual(snapshot.grants.first?.state, "active")
            XCTAssertEqual(snapshot.grants.first?.useRemaining, 2)
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1)

        XCTAssertEqual(client.publicationsRequestCount, 1)
        XCTAssertEqual(client.grantsRequestCount, 1)
        XCTAssertEqual(client.lastPublicationVaultID, "vault-a")
        XCTAssertEqual(client.lastGrantVaultID, "vault-a")
    }

    func testReadUseCaseRejectsCrossVaultPublicationBeforeGrantRead() throws {
        let runtime = makeRuntime(subjectID: "owner-a", vaultID: "vault-a", generation: 4)
        let lease = try XCTUnwrap(runtime.capture(forSubjectId: "owner-a"))
        let client = PublicationManagementReaderClientStub()
        client.publicationsResult = .success(try makePublicationList(vaultID: "vault-b"))
        let useCase = PublicationManagementReadUseCase(client: client, accountLeaseRuntime: runtime)

        let expectation = expectation(description: "cross vault publication rejected")
        useCase.load(accountLease: lease) { result in
            guard case let .failure(error) = result else {
                XCTFail("Expected cross-vault response rejection")
                expectation.fulfill()
                return
            }
            XCTAssertEqual(error as? PublicationManagementAccessError, .responseScopeMismatch)
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1)

        XCTAssertEqual(client.publicationsRequestCount, 1)
        XCTAssertEqual(client.grantsRequestCount, 0)
    }

    func testReadUseCaseRejectsAccountChangeBeforeGrantResultCanCommit() throws {
        let runtime = makeRuntime(subjectID: "owner-a", vaultID: "vault-a", generation: 4)
        let lease = try XCTUnwrap(runtime.capture(forSubjectId: "owner-a"))
        let client = PublicationManagementReaderClientStub()
        client.publicationsResult = .success(try makePublicationList(vaultID: "vault-a"))
        client.grantsResult = .success(try makeGrantList(vaultID: "vault-a"))
        client.beforeGrantCompletion = {
            runtime.publish(session: self.makeSession(subjectID: "owner-b", vaultID: "vault-b", generation: 5))
        }
        let useCase = PublicationManagementReadUseCase(client: client, accountLeaseRuntime: runtime)

        let expectation = expectation(description: "account change rejected")
        useCase.load(accountLease: lease) { result in
            guard case let .failure(error) = result else {
                XCTFail("Expected stale account lease rejection")
                expectation.fulfill()
                return
            }
            XCTAssertEqual(error as? PublicationManagementAccessError, .accountLeaseInvalid)
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1)

        XCTAssertEqual(client.publicationsRequestCount, 1)
        XCTAssertEqual(client.grantsRequestCount, 1)
    }

    func testParserRejectsMissingRequiredGrantBoundaryFields() {
        XCTAssertNil(PublicationManagementGrant(json: [
            "grantId": "grant-a",
            "publicationId": "publication-a",
            "publicationVersionId": "version-a",
            "state": "active",
            "expiresAt": "not-a-date",
            "useRemaining": -1,
        ]))
    }

    func testProductionGateIsFailClosedWithoutQAArgument() {
        XCTAssertFalse(PublicationManagementM2QAGate.isEnabled)
    }

    private func makeRuntime(subjectID: String, vaultID: String, generation: UInt64) -> AccountLeaseRuntime {
        let runtime = AccountLeaseRuntime(authorityEpoch: "epoch-v1")
        runtime.publish(session: makeSession(subjectID: subjectID, vaultID: vaultID, generation: generation))
        return runtime
    }

    private func makePublicationList(vaultID: String) throws -> PublicationManagementPublicationList {
        try XCTUnwrap(PublicationManagementPublicationList(json: [
            "schemaVersion": PublicationManagementPublicationList.schemaVersion,
            "vaultId": vaultID,
            "publications": [[
                "publicationId": "publication-a",
                "publicationVersionId": "version-a",
                "publicationState": "confirmed",
                "projectionState": "active",
                "preview": [
                    "title": "院子里的雨声",
                    "body": "这是经过确认的公开预览。",
                ],
                "requiresSecondConfirmation": false,
                "thirdPartyReviewRequired": false,
                "aiDisclosureRequired": true,
            ]],
        ]))
    }

    private func makeGrantList(vaultID: String) throws -> PublicationManagementGrantList {
        try XCTUnwrap(PublicationManagementGrantList(json: [
            "schemaVersion": PublicationManagementGrantList.schemaVersion,
            "vaultId": vaultID,
            "grants": [[
                "grantId": "grant-a",
                "publicationId": "publication-a",
                "publicationVersionId": "version-a",
                "state": "active",
                "expiresAt": ISO8601DateFormatter().string(from: Date().addingTimeInterval(3600)),
                "useRemaining": 2,
            ]],
        ]))
    }

    private func makeSession(subjectID: String, vaultID: String, generation: UInt64) -> AccountSession {
        AccountSession(
            subjectId: subjectID,
            vaultId: vaultID,
            sessionId: "session-\(generation)",
            tokenFamilyId: "family-\(generation)",
            sessionVersion: Int(generation),
            generation: generation,
            generationId: UUID(),
            state: .active,
            activatedAt: Date()
        )
    }
}

final class PublicationLifecycleAccessTests: XCTestCase {
    func testWithdrawReusesInMemoryCommandAfterAmbiguousFailure() throws {
        let runtime = makeRuntime(subjectID: "owner-a", vaultID: "vault-a", generation: 4)
        let lease = try XCTUnwrap(runtime.capture(forSubjectId: "owner-a"))
        let publication = try makeWithdrawablePublication()
        let client = PublicationLifecycleClientStub()
        client.results = [
            .failure(PublicationLifecycleAccessError.unavailable),
            .success(makeWithdrawalReceipt(for: publication)),
        ]
        let useCase = PublicationLifecycleUseCase(
            client: client,
            accountLeaseRuntime: runtime,
            isQAGateEnabled: { true }
        )

        let first = expectation(description: "ambiguous failure")
        useCase.withdraw(publication: publication, accountLease: lease) { result in
            guard case .failure = result else {
                XCTFail("Expected first withdrawal to fail")
                first.fulfill()
                return
            }
            first.fulfill()
        }
        wait(for: [first], timeout: 1)

        let second = expectation(description: "retry receipt")
        useCase.withdraw(publication: publication, accountLease: lease) { result in
            guard case let .success(receipt) = result else {
                XCTFail("Expected idempotent retry receipt")
                second.fulfill()
                return
            }
            XCTAssertEqual(receipt.publicationID, publication.publicationID.lowercased())
            XCTAssertEqual(receipt.publicationState, "withdrawn")
            second.fulfill()
        }
        wait(for: [second], timeout: 1)

        XCTAssertEqual(client.commandIDs.count, 2)
        XCTAssertEqual(client.commandIDs.first, client.commandIDs.last)
    }

    func testWithdrawFailsClosedWithoutLifecycleQAGate() throws {
        let runtime = makeRuntime(subjectID: "owner-a", vaultID: "vault-a", generation: 4)
        let lease = try XCTUnwrap(runtime.capture(forSubjectId: "owner-a"))
        let client = PublicationLifecycleClientStub()
        let useCase = PublicationLifecycleUseCase(
            client: client,
            accountLeaseRuntime: runtime,
            isQAGateEnabled: { false }
        )

        let expectation = expectation(description: "disabled")
        useCase.withdraw(publication: try makeWithdrawablePublication(), accountLease: lease) { result in
            guard case let .failure(error) = result else {
                XCTFail("Expected default-off lifecycle gate")
                expectation.fulfill()
                return
            }
            XCTAssertEqual(error as? PublicationLifecycleAccessError, .disabled)
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1)
        XCTAssertTrue(client.commandIDs.isEmpty)
    }

    private func makeRuntime(subjectID: String, vaultID: String, generation: UInt64) -> AccountLeaseRuntime {
        let runtime = AccountLeaseRuntime(authorityEpoch: "epoch-v1")
        runtime.publish(session: AccountSession(
            subjectId: subjectID,
            vaultId: vaultID,
            sessionId: "session-\(generation)",
            tokenFamilyId: "family-\(generation)",
            sessionVersion: Int(generation),
            generation: generation,
            generationId: UUID(),
            state: .active,
            activatedAt: Date()
        ))
        return runtime
    }

    private func makeWithdrawablePublication() throws -> PublicationManagementPublication {
        let publicationID = UUID().uuidString.lowercased()
        let versionID = UUID().uuidString.lowercased()
        return try XCTUnwrap(PublicationManagementPublication(json: [
            "publicationId": publicationID,
            "publicationVersionId": versionID,
            "lifecycleAuthorityEpoch": 0,
            "publicationState": "confirmed",
            "projectionState": "active",
            "preview": [
                "title": "院子里的雨声",
                "body": "这是已确认的公开预览。",
            ],
            "requiresSecondConfirmation": false,
            "thirdPartyReviewRequired": false,
            "aiDisclosureRequired": true,
        ]))
    }

    private func makeWithdrawalReceipt(
        for publication: PublicationManagementPublication
    ) -> PublicationLifecycleReceipt {
        try! XCTUnwrap(PublicationLifecycleReceipt(json: [
            "schemaVersion": PublicationLifecycleReceipt.schemaVersion,
            "vaultId": "vault-a",
            "publicationId": publication.publicationID,
            "publicationVersionId": publication.publicationVersionID ?? UUID().uuidString.lowercased(),
            "outcome": "withdrawn",
            "publicationState": "withdrawn",
            "projectionState": "withdrawn",
            "conflictHold": false,
            "revokedGrantCount": 1,
            "revokedVisitorSessionCount": 1,
            "receipt": [
                "receiptId": UUID().uuidString.lowercased(),
                "reasonCode": "ownerWithdrawal",
                "accessDenyState": "completed",
                "publicIndexCleanupState": "pending",
                "runtimeCleanupState": "notApplicable",
            ],
        ]))
    }
}

private final class PublicationManagementReaderClientStub: PublicationManagementReaderClient {
    var publicationsResult: Result<PublicationManagementPublicationList, Error>?
    var grantsResult: Result<PublicationManagementGrantList, Error>?
    var beforeGrantCompletion: (() -> Void)?
    private(set) var publicationsRequestCount = 0
    private(set) var grantsRequestCount = 0
    private(set) var lastPublicationVaultID: String?
    private(set) var lastGrantVaultID: String?

    func fetchOwnerPublications(
        vaultID: String,
        accountLease: AccountLease,
        completion: @escaping (Result<PublicationManagementPublicationList, Error>) -> Void
    ) {
        publicationsRequestCount += 1
        lastPublicationVaultID = vaultID
        completion(publicationsResult ?? .failure(PublicationManagementAccessError.unavailable))
    }

    func fetchOwnerGrants(
        vaultID: String,
        accountLease: AccountLease,
        completion: @escaping (Result<PublicationManagementGrantList, Error>) -> Void
    ) {
        grantsRequestCount += 1
        lastGrantVaultID = vaultID
        beforeGrantCompletion?()
        completion(grantsResult ?? .failure(PublicationManagementAccessError.unavailable))
    }
}

private final class PublicationLifecycleClientStub: PublicationLifecycleClient {
    var results: [Result<PublicationLifecycleReceipt, Error>] = []
    private(set) var commandIDs: [UUID] = []

    func executePublicationLifecycle(
        action: PublicationLifecycleAction,
        vaultID: String,
        publicationID: String,
        command: PublicationLifecycleCommand,
        accountLease: AccountLease,
        completion: @escaping (Result<PublicationLifecycleReceipt, Error>) -> Void
    ) {
        commandIDs.append(command.commandID)
        completion(results.isEmpty ? .failure(PublicationLifecycleAccessError.unavailable) : results.removeFirst())
    }
}

import XCTest
#if canImport(DreamJourney)
@testable import DreamJourney
#elseif canImport(DreamJourneyCore)
@testable import DreamJourneyCore
#endif

final class PublicationVisitorAccessTests: XCTestCase {
    func testCoordinatorClearsScopeAndProjectionAfterAccountLeaseChanges() throws {
        let runtime = makeRuntime(subjectID: "visitor-a", vaultID: "vault-a", generation: 3)
        let scope = try makeScope(runtime: runtime)
        let coordinator = PublicationVisitorSessionCoordinator(accountLeaseRuntime: runtime)

        XCTAssertTrue(coordinator.activate(scope))
        XCTAssertTrue(coordinator.accept(makeProjection(scope: scope), for: scope))
        XCTAssertEqual(coordinator.currentProjection()?.publicationVersionID, scope.publicationVersionID)

        runtime.publish(session: makeSession(subjectID: "visitor-b", vaultID: "vault-b", generation: 4))

        XCTAssertNil(coordinator.currentScope())
        let snapshot = coordinator.snapshot()
        XCTAssertFalse(snapshot.isActive)
        XCTAssertNil(snapshot.visitorSessionID)
        XCTAssertNil(snapshot.publicationID)
        XCTAssertNil(snapshot.publicationVersionID)
        XCTAssertEqual(snapshot.invalidationReason, .accountLeaseInvalid)
    }

    func testProjectionMismatchInvalidatesSessionInsteadOfRetainingCachedContent() throws {
        let runtime = makeRuntime(subjectID: "visitor-a", vaultID: "vault-a", generation: 3)
        let scope = try makeScope(runtime: runtime)
        let coordinator = PublicationVisitorSessionCoordinator(accountLeaseRuntime: runtime)
        XCTAssertTrue(coordinator.activate(scope))

        var invalidJSON = projectionJSON(scope: scope)
        invalidJSON["publicationVersionId"] = "publication-version-mismatch"
        let mismatchedProjection = try XCTUnwrap(PublicationVisitorProjection(json: invalidJSON))

        XCTAssertFalse(coordinator.accept(mismatchedProjection, for: scope))
        XCTAssertFalse(coordinator.snapshot().isActive)
        XCTAssertEqual(coordinator.snapshot().invalidationReason, .responseScopeMismatch)
        XCTAssertNil(coordinator.currentProjection())
    }

    func testReadUseCaseAcceptsOnlyProjectionBoundToActiveScope() throws {
        let runtime = makeRuntime(subjectID: "visitor-a", vaultID: "vault-a", generation: 3)
        let scope = try makeScope(runtime: runtime)
        let projection = makeProjection(scope: scope)
        let client = PublicationVisitorReaderClientStub()
        client.projectionResult = .success(projection)
        let coordinator = PublicationVisitorSessionCoordinator(accountLeaseRuntime: runtime)
        XCTAssertTrue(coordinator.activate(scope))
        let useCase = PublicationVisitorReadUseCase(client: client, sessionCoordinator: coordinator)

        let expectation = expectation(description: "projection")
        useCase.loadProjection { result in
            guard case let .success(loadedProjection) = result else {
                XCTFail("Expected a bound projection")
                expectation.fulfill()
                return
            }
            XCTAssertEqual(loadedProjection, projection)
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1)

        XCTAssertEqual(client.projectionRequestCount, 1)
        XCTAssertEqual(coordinator.currentProjection(), projection)
    }

    func testReadUseCaseRejectsInvalidQuestionBeforeClientRequest() throws {
        let runtime = makeRuntime(subjectID: "visitor-a", vaultID: "vault-a", generation: 3)
        let scope = try makeScope(runtime: runtime)
        let client = PublicationVisitorReaderClientStub()
        let coordinator = PublicationVisitorSessionCoordinator(accountLeaseRuntime: runtime)
        XCTAssertTrue(coordinator.activate(scope))
        let useCase = PublicationVisitorReadUseCase(client: client, sessionCoordinator: coordinator)

        let expectation = expectation(description: "invalid question")
        useCase.answer("   ") { result in
            guard case let .failure(error) = result else {
                XCTFail("Expected an invalid question error")
                expectation.fulfill()
                return
            }
            XCTAssertEqual(error as? PublicationVisitorAccessError, .invalidQuestion)
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1)

        XCTAssertEqual(client.answerRequestCount, 0)
    }

    func testWithdrawnPublicationInvalidatesInMemoryVisitorContent() throws {
        let runtime = makeRuntime(subjectID: "visitor-a", vaultID: "vault-a", generation: 3)
        let scope = try makeScope(runtime: runtime)
        let coordinator = PublicationVisitorSessionCoordinator(accountLeaseRuntime: runtime)
        XCTAssertTrue(coordinator.activate(scope))
        XCTAssertTrue(coordinator.accept(makeProjection(scope: scope), for: scope))

        let client = PublicationVisitorReaderClientStub()
        client.projectionResult = .failure(DreamJourneyBackendClient.ClientError.backendError(
            statusCode: 409,
            context: .init(code: "publicationVisitorAccessUnavailable", detail: "publication unavailable")
        ))
        let useCase = PublicationVisitorReadUseCase(client: client, sessionCoordinator: coordinator)

        let expectation = expectation(description: "withdrawn visitor content invalidated")
        useCase.loadProjection { result in
            guard case let .failure(error) = result else {
                XCTFail("Expected lifecycle access denial")
                expectation.fulfill()
                return
            }
            XCTAssertEqual(error as? PublicationVisitorAccessError, .accessRevoked)
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1)

        XCTAssertFalse(coordinator.snapshot().isActive)
        XCTAssertNil(coordinator.currentProjection())
        XCTAssertEqual(coordinator.snapshot().invalidationReason, .accessRevoked)
    }

    func testProductionGateIsFailClosedWithoutQAArgument() {
        #if DEBUG || UI_QA_SIMULATOR
        XCTAssertFalse(PublicationVisitorM2QAGate.isEnabled)
        #else
        XCTAssertFalse(PublicationVisitorM2QAGate.isEnabled)
        #endif
    }

    private func makeRuntime(subjectID: String, vaultID: String, generation: UInt64) -> AccountLeaseRuntime {
        let runtime = AccountLeaseRuntime(authorityEpoch: "epoch-v1")
        runtime.publish(session: makeSession(subjectID: subjectID, vaultID: vaultID, generation: generation))
        return runtime
    }

    private func makeScope(runtime: AccountLeaseRuntime) throws -> PublicationVisitorSessionScope {
        let lease = try XCTUnwrap(runtime.capture(forSubjectId: "visitor-a"))
        return try XCTUnwrap(PublicationVisitorSessionScope(
            visitorSessionID: "visitor-session-1",
            publicationID: "publication-1",
            publicationVersionID: "publication-version-1",
            expiresAt: Date().addingTimeInterval(300),
            sessionCredential: String(repeating: "c", count: 32),
            accountLease: lease
        ))
    }

    private func makeProjection(scope: PublicationVisitorSessionScope) -> PublicationVisitorProjection {
        try! XCTUnwrap(PublicationVisitorProjection(json: projectionJSON(scope: scope)))
    }

    private func projectionJSON(scope: PublicationVisitorSessionScope) -> [String: Any] {
        [
            "schemaVersion": PublicationVisitorProjection.schemaVersion,
            "visitorSessionId": scope.visitorSessionID,
            "publicationId": scope.publicationID,
            "publicationVersionId": scope.publicationVersionID,
            "expiresAt": ISO8601DateFormatter().string(from: scope.expiresAt),
            "title": "公开回忆",
            "body": "这是经本人确认、仅供受邀访问者阅读的公开副本。",
            "aiDisclosure": "回答仅基于已批准的公开副本。",
            "source": [
                "kind": "publicationVersion",
                "projectionHash": String(repeating: "a", count: 64),
                "publicCitationHash": String(repeating: "b", count: 64),
            ],
            "answerBoundary": [
                "identityDisclosureRequired": true,
                "privateContextAllowed": false,
                "providerCallAllowed": false,
                "unknownFallbackRequired": true,
            ],
        ]
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

private final class PublicationVisitorReaderClientStub: PublicationVisitorReaderClient {
    var projectionResult: Result<PublicationVisitorProjection, Error>?
    var answerResult: Result<PublicationVisitorAnswerResponse, Error>?
    private(set) var projectionRequestCount = 0
    private(set) var answerRequestCount = 0

    func fetchProjection(
        scope: PublicationVisitorSessionScope,
        completion: @escaping (Result<PublicationVisitorProjection, Error>) -> Void
    ) {
        projectionRequestCount += 1
        completion(projectionResult ?? .failure(PublicationVisitorAccessError.sessionUnavailable))
    }

    func answer(
        scope: PublicationVisitorSessionScope,
        question: String,
        completion: @escaping (Result<PublicationVisitorAnswerResponse, Error>) -> Void
    ) {
        answerRequestCount += 1
        completion(answerResult ?? .failure(PublicationVisitorAccessError.sessionUnavailable))
    }
}

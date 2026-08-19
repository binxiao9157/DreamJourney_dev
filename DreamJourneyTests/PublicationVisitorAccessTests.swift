import XCTest
#if canImport(DreamJourney)
@testable import DreamJourney
#elseif canImport(DreamJourneyCore)
@testable import DreamJourneyCore
#endif

final class PublicationVisitorAccessTests: XCTestCase {
    func testFamilyVisitorV4RoutingAllowsPrivateContextOnlyForSelf() {
        let decision = EchoV4IdentityRoutingPolicy.evaluate(
            viewerSubjectID: "owner-a",
            targetOwnerSubjectID: "owner-a",
            isSelfAssistant: true,
            relationshipAccepted: false,
            visitorSessionOwnerSubjectID: nil,
            visitorSessionActive: false
        )

        XCTAssertEqual(decision.route, .ownerPrivate)
        XCTAssertTrue(decision.privateContextAllowed)
        XCTAssertFalse(decision.legacyFallbackAllowed)
    }

    func testFamilyVisitorV4RoutingUsesMatchingVisitorSessionOnly() {
        let publicDecision = EchoV4IdentityRoutingPolicy.evaluate(
            viewerSubjectID: "visitor-b",
            targetOwnerSubjectID: "owner-a",
            isSelfAssistant: false,
            relationshipAccepted: true,
            visitorSessionOwnerSubjectID: "owner-a",
            visitorSessionActive: true
        )
        let mismatchedDecision = EchoV4IdentityRoutingPolicy.evaluate(
            viewerSubjectID: "visitor-b",
            targetOwnerSubjectID: "owner-a",
            isSelfAssistant: false,
            relationshipAccepted: true,
            visitorSessionOwnerSubjectID: "owner-c",
            visitorSessionActive: true
        )

        XCTAssertEqual(publicDecision.route, .visitorPublic)
        XCTAssertFalse(publicDecision.privateContextAllowed)
        XCTAssertFalse(publicDecision.legacyFallbackAllowed)
        XCTAssertEqual(mismatchedDecision.route, .familyContribution)
        XCTAssertEqual(mismatchedDecision.reason, "visitorSessionOwnerMismatch")
    }

    func testVisitorAdmissionBindsSessionToGrantOwner() throws {
        let admission = try makeAdmission(grantID: UUID().uuidString.lowercased())

        XCTAssertEqual(admission.ownerSubjectID, "owner-a")
        let runtime = makeRuntime(subjectID: "visitor-a", vaultID: "vault-a", generation: 3)
        let lease = try XCTUnwrap(runtime.capture(forSubjectId: "visitor-a"))
        let scope = try XCTUnwrap(admission.sessionScope(
            sessionCredential: String(repeating: "c", count: 64),
            accountLease: lease
        ))
        XCTAssertEqual(scope.ownerSubjectID, "owner-a")
    }

    func testM2PolicyBindingsSeparateOwnerGrantManagementFromVisitorAccess() {
        XCTAssertEqual(DJFeature.publicationManagementM2.backendReleasePolicyFeature, "publication")
        XCTAssertEqual(DJFeature.publicationManagementM2.backendReleasePolicyAudience, "owner")
        XCTAssertEqual(DJFeature.publicationGrantManagementM2.backendReleasePolicyFeature, "visitorAccess")
        XCTAssertEqual(DJFeature.publicationGrantManagementM2.backendReleasePolicyAudience, "owner")
        XCTAssertEqual(DJFeature.publicationVisitorM2.backendReleasePolicyFeature, "visitorAccess")
        XCTAssertEqual(DJFeature.publicationVisitorM2.backendReleasePolicyAudience, "visitor")
    }

    func testReleasePolicyCacheScopeSeparatesOwnerAndVisitorAudience() {
        let store = ReleasePolicyStore(userDefaults: UserDefaults(suiteName: UUID().uuidString)!)
        let owner = ReleasePolicyCacheScope(
            accountUserId: "account-a",
            appBuild: "100",
            audience: "owner"
        )
        let visitor = ReleasePolicyCacheScope(
            accountUserId: "account-a",
            appBuild: "100",
            audience: "visitor"
        )

        XCTAssertNotEqual(owner, visitor)
        XCTAssertNotEqual(store.storageKey(for: owner), store.storageKey(for: visitor))
    }

    func testFormalRoutesUseIndependentOwnerGrantAndVisitorPolicyFeatures() {
        let service = FeatureGateService.shared
        XCTAssertEqual(
            service.featureForRequest(
                path: "/v2/vaults/vault-a/publications",
                method: .get,
                payload: nil
            ),
            .publicationManagementM2
        )
        XCTAssertEqual(
            service.featureForRequest(
                path: "/v2/vaults/vault-a/publication-grants",
                method: .get,
                payload: nil
            ),
            .publicationGrantManagementM2
        )
        XCTAssertEqual(
            service.featureForRequest(
                path: "/v2/publication-invitations",
                method: .get,
                payload: nil
            ),
            .publicationVisitorM2
        )
        XCTAssertEqual(
            service.featureForRequest(
                path: "/v2/publication-grants/grant-a/sessions",
                method: .post,
                payload: nil
            ),
            .publicationVisitorM2
        )
        XCTAssertEqual(
            service.featureForRequest(
                path: "/v2/publication-sessions/session-a/projection",
                method: .post,
                payload: nil
            ),
            .publicationVisitorM2
        )
    }

    func testVisitorDeepLinkRequiresOneStrictGrantAndCredentialPair() throws {
        let grantID = UUID().uuidString.lowercased()
        let credential = String(repeating: "g", count: 32)
        let valid = try XCTUnwrap(URL(string:
            "dreamjourney://publication/visitor?grantId=\(grantID)&grantCredential=\(credential)"
        ))
        let duplicate = try XCTUnwrap(URL(string:
            "dreamjourney://publication/visitor?grantId=\(grantID)&grantId=\(grantID)&grantCredential=\(credential)"
        ))
        let unrelated = try XCTUnwrap(URL(string:
            "dreamjourney://echo/visitor?grantId=\(grantID)&grantCredential=\(credential)"
        ))

        XCTAssertEqual(PublicationVisitorInvitation(deepLinkURL: valid)?.grantID, grantID)
        XCTAssertNil(PublicationVisitorInvitation(deepLinkURL: duplicate))
        XCTAssertNil(PublicationVisitorInvitation(deepLinkURL: unrelated))
    }

    func testRegisteredInvitationAdmissionPayloadDoesNotContainShareCredential() throws {
        let grantID = UUID().uuidString.lowercased()
        let invitation = try XCTUnwrap(PublicationVisitorInvitation(registeredGrantID: grantID))
        let payload = invitation.requestPayload(
            sessionCredential: String(repeating: "s", count: 64),
            usesQAContract: false
        )

        XCTAssertEqual(invitation.grantID, grantID)
        XCTAssertNil(payload["grantCredential"])
        XCTAssertNotNil(payload["commandId"])
        XCTAssertEqual(payload["sessionCredential"] as? String, String(repeating: "s", count: 64))
    }

    func testVisitorInvitationListAcceptsOnlyMinimalPublicMetadata() throws {
        let grantID = UUID().uuidString.lowercased()
        let publicationID = UUID().uuidString.lowercased()
        let versionID = UUID().uuidString.lowercased()
        let contract = try XCTUnwrap(PublicationVisitorInvitationList(json: [
            "schemaVersion": PublicationVisitorInvitationList.schemaVersion,
            "invitations": [[
                "grantId": grantID,
                "publicationId": publicationID,
                "publicationVersionId": versionID,
                "title": "一起散步的下午",
                "state": "active",
                "expiresAt": ISO8601DateFormatter().string(from: Date().addingTimeInterval(300)),
            ]],
        ]))

        XCTAssertEqual(contract.invitations.count, 1)
        XCTAssertEqual(contract.invitations[0].grantID, grantID)
        XCTAssertEqual(contract.invitations[0].title, "一起散步的下午")
        XCTAssertNotNil(contract.invitations[0].invitation)

        XCTAssertNil(PublicationVisitorInvitationList(json: [
            "schemaVersion": PublicationVisitorInvitationList.schemaVersion,
            "invitations": [[
                "grantId": grantID,
                "publicationId": publicationID,
                "publicationVersionId": versionID,
                "title": "一起散步的下午",
                "state": "active",
                "expiresAt": ISO8601DateFormatter().string(from: Date().addingTimeInterval(300)),
                "grantCredential": String(repeating: "g", count: 32),
            ]],
        ]))
    }

    func testProductAdmissionV2DoesNotRequireInternalUseBalance() throws {
        let admission = try XCTUnwrap(PublicationVisitorAdmission(json: [
            "schemaVersion": PublicationVisitorAdmission.productSchemaVersion,
            "grantId": UUID().uuidString.lowercased(),
            "visitorSessionId": UUID().uuidString.lowercased(),
            "publicationId": UUID().uuidString.lowercased(),
            "publicationVersionId": UUID().uuidString.lowercased(),
            "expiresAt": ISO8601DateFormatter().string(from: Date().addingTimeInterval(300)),
        ]))

        XCTAssertNil(admission.ownerSubjectID)
        XCTAssertNil(admission.useRemaining)
    }

    func testProductAdmissionRejectsPrivateOwnerIdentifier() {
        XCTAssertNil(PublicationVisitorAdmission(json: [
            "schemaVersion": PublicationVisitorAdmission.productSchemaVersion,
            "grantId": UUID().uuidString.lowercased(),
            "visitorSessionId": UUID().uuidString.lowercased(),
            "ownerSubjectId": "private-owner-id",
            "publicationId": UUID().uuidString.lowercased(),
            "publicationVersionId": UUID().uuidString.lowercased(),
            "expiresAt": ISO8601DateFormatter().string(from: Date().addingTimeInterval(300)),
        ]))
    }

    func testExpiredScopeIsClearedBeforeItCanBeRead() throws {
        let runtime = makeRuntime(subjectID: "visitor-a", vaultID: "vault-a", generation: 3)
        let lease = try XCTUnwrap(runtime.capture(forSubjectId: "visitor-a"))
        let now = Date()
        let scope = try XCTUnwrap(PublicationVisitorSessionScope(
            visitorSessionID: "visitor-session-1",
            ownerSubjectID: "owner-a",
            publicationID: "publication-1",
            publicationVersionID: "publication-version-1",
            expiresAt: now.addingTimeInterval(1),
            sessionCredential: String(repeating: "c", count: 32),
            accountLease: lease,
            now: now
        ))
        let coordinator = PublicationVisitorSessionCoordinator(accountLeaseRuntime: runtime)
        XCTAssertTrue(coordinator.activate(scope, at: now))

        XCTAssertNil(coordinator.currentScope(at: now.addingTimeInterval(2)))
        XCTAssertEqual(coordinator.snapshot().invalidationReason, .expired)
    }

    func testAccountSwitchDropsPendingAdmissionCallbackAndCredentialScope() throws {
        let accountRuntime = makeRuntime(subjectID: "visitor-a", vaultID: "vault-a", generation: 3)
        let lease = try XCTUnwrap(accountRuntime.capture(forSubjectId: "visitor-a"))
        let client = PublicationVisitorAdmissionClientStub()
        let coordinator = PublicationVisitorSessionCoordinator(accountLeaseRuntime: accountRuntime)
        let runtime = PublicationVisitorRuntime(
            client: client,
            sessionCoordinator: coordinator,
            accountLeaseRuntime: accountRuntime,
            routeAllowed: { true }
        )
        let invitation = try XCTUnwrap(PublicationVisitorInvitation(
            grantID: UUID().uuidString,
            grantCredential: String(repeating: "g", count: 32)
        ))
        runtime.stage(invitation)

        let expectation = expectation(description: "stale admission rejected")
        runtime.open(accountLease: lease) { result in
            guard case let .failure(error) = result else {
                XCTFail("Expected stale admission to fail")
                expectation.fulfill()
                return
            }
            XCTAssertEqual(error as? PublicationVisitorAccessError, .accountLeaseInvalid)
            expectation.fulfill()
        }
        accountRuntime.publish(session: makeSession(
            subjectID: "visitor-b",
            vaultID: "vault-b",
            generation: 4
        ))
        runtime.clear(reason: .accountLeaseInvalid)
        client.complete(with: .success(try makeAdmission(grantID: invitation.grantID)))
        wait(for: [expectation], timeout: 1)

        XCTAssertFalse(runtime.snapshot().hasPendingInvitation)
        XCTAssertFalse(runtime.snapshot().session.isActive)
        XCTAssertEqual(runtime.snapshot().session.invalidationReason, .accountLeaseInvalid)
    }

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
            ownerSubjectID: "owner-a",
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

    private func makeAdmission(grantID: String) throws -> PublicationVisitorAdmission {
        try XCTUnwrap(PublicationVisitorAdmission(json: [
            "schemaVersion": PublicationVisitorAdmission.schemaVersion,
            "grantId": grantID,
            "visitorSessionId": "visitor-session-1",
            "ownerSubjectId": "owner-a",
            "publicationId": "publication-1",
            "publicationVersionId": "publication-version-1",
            "expiresAt": ISO8601DateFormatter().string(from: Date().addingTimeInterval(300)),
            "useRemaining": 1,
        ]))
    }
}

private final class PublicationVisitorAdmissionClientStub: PublicationVisitorAdmissionClient {
    private var completion: ((Result<PublicationVisitorAdmission, Error>) -> Void)?

    func admitVisitor(
        invitation: PublicationVisitorInvitation,
        sessionCredential: String,
        accountLease: AccountLease,
        completion: @escaping (Result<PublicationVisitorAdmission, Error>) -> Void
    ) {
        self.completion = completion
    }

    func complete(with result: Result<PublicationVisitorAdmission, Error>) {
        completion?(result)
        completion = nil
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

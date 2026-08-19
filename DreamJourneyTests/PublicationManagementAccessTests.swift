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
            XCTAssertEqual(snapshot.grants.first?.recipientDisplayLabel, "手机号尾号 8000")
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
            "schemaVersion": PublicationManagementGrantList.legacySchemaVersion,
            "vaultId": vaultID,
            "grants": [[
                "grantId": "grant-a",
                "publicationId": "publication-a",
                "publicationVersionId": "version-a",
                "recipientDisplayLabel": "手机号尾号 8000",
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

final class PublicationGrantManagementAccessTests: XCTestCase {
    func testFormalIssuePayloadUsesRegisteredRecipientAndNoProductBalance() throws {
        let recipient = try XCTUnwrap(PublicationGrantRecipient(input: "138 0013 8000"))
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let command = try XCTUnwrap(PublicationGrantIssueCommand(
            commandID: UUID(uuidString: "aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa")!,
            publicationID: "61111111-1111-4111-8111-111111111111",
            publicationVersionID: "62222222-2222-4222-8222-222222222222",
            recipient: recipient,
            expiresAt: now.addingTimeInterval(3600),
            now: now
        ))

        let payload = command.requestPayload(usesQAContract: false)

        XCTAssertEqual(recipient.displayLabel, "手机号尾号 8000")
        XCTAssertEqual((payload["recipient"] as? [String: String])?["type"], "phone")
        XCTAssertEqual((payload["recipient"] as? [String: String])?["value"], "13800138000")
        XCTAssertNil(payload["useLimit"])
        XCTAssertNil(payload["granteeUserId"])
    }

    func testV2GrantListHidesSafetyCounterAndUsesMaskedRecipient() throws {
        let list = try XCTUnwrap(PublicationManagementGrantList(json: [
            "schemaVersion": PublicationManagementGrantList.schemaVersion,
            "vaultId": "vault-a",
            "grants": [[
                "grantId": "64444444-4444-4444-8444-444444444444",
                "publicationId": "61111111-1111-4111-8111-111111111111",
                "publicationVersionId": "62222222-2222-4222-8222-222222222222",
                "recipientDisplayLabel": "账户 · a1b2c3",
                "state": "active",
                "expiresAt": ISO8601DateFormatter().string(from: Date().addingTimeInterval(3600)),
            ]],
        ]))

        XCTAssertEqual(list.grants.first?.recipientDisplayLabel, "账户 · a1b2c3")
        XCTAssertNil(list.grants.first?.useRemaining)
        XCTAssertEqual(list.grants.first?.isUsable, true)
    }

    func testIssueUseCaseReturnsRegisteredInvitationReceiptWithoutShareCredential() throws {
        let runtime = makeRuntime(subjectID: "owner-a", vaultID: "vault-a", generation: 1)
        let lease = try XCTUnwrap(runtime.capture(forSubjectId: "owner-a"))
        let client = PublicationGrantManagementClientStub()
        let publication = try makePublication()
        let recipient = try XCTUnwrap(PublicationGrantRecipient(input: "13800138000"))
        let expiresAt = Date().addingTimeInterval(3600)
        client.issueResult = .success(try makeIssueReceipt(
            vaultID: "vault-a",
            publication: publication,
            recipient: recipient,
            expiresAt: expiresAt
        ))
        let useCase = PublicationGrantManagementUseCase(
            client: client,
            accountLeaseRuntime: runtime,
            isEnabled: { true }
        )

        let expectation = expectation(description: "issue grant")
        useCase.issue(
            publication: publication,
            recipient: recipient,
            expiresAt: expiresAt,
            accountLease: lease
        ) { result in
            guard case let .success(receipt) = result else {
                XCTFail("Expected a registered-account invitation receipt")
                expectation.fulfill()
                return
            }
            XCTAssertEqual(receipt.recipientDisplayLabel, "手机号尾号 8000")
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1)
        XCTAssertEqual(client.issueCallCount, 1)
    }

    func testIssueUseCaseRejectsAccountSwitchBeforeCommit() throws {
        let runtime = makeRuntime(subjectID: "owner-a", vaultID: "vault-a", generation: 1)
        let lease = try XCTUnwrap(runtime.capture(forSubjectId: "owner-a"))
        let client = PublicationGrantManagementClientStub()
        let publication = try makePublication()
        let recipient = try XCTUnwrap(PublicationGrantRecipient(input: "13800138000"))
        let expiresAt = Date().addingTimeInterval(3600)
        client.issueResult = .success(try makeIssueReceipt(
            vaultID: "vault-a",
            publication: publication,
            recipient: recipient,
            expiresAt: expiresAt
        ))
        client.beforeIssueCompletion = {
            runtime.publish(session: self.makeSession(
                subjectID: "owner-b",
                vaultID: "vault-b",
                generation: 2
            ))
        }
        let useCase = PublicationGrantManagementUseCase(
            client: client,
            accountLeaseRuntime: runtime,
            isEnabled: { true }
        )

        let expectation = expectation(description: "stale lease")
        useCase.issue(
            publication: publication,
            recipient: recipient,
            expiresAt: expiresAt,
            accountLease: lease
        ) { result in
            guard case let .failure(error) = result else {
                XCTFail("Expected account lease failure")
                expectation.fulfill()
                return
            }
            XCTAssertEqual(error as? PublicationManagementAccessError, .accountLeaseInvalid)
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1)
    }

    private func makePublication() throws -> PublicationManagementPublication {
        try XCTUnwrap(PublicationManagementPublication(json: [
            "publicationId": "61111111-1111-4111-8111-111111111111",
            "publicationVersionId": "62222222-2222-4222-8222-222222222222",
            "publicationState": "confirmed",
            "projectionState": "active",
            "preview": ["title": "公开标题", "body": "公开正文"],
            "requiresSecondConfirmation": false,
            "thirdPartyReviewRequired": false,
            "aiDisclosureRequired": false,
        ]))
    }

    private func makeIssueReceipt(
        vaultID: String,
        publication: PublicationManagementPublication,
        recipient: PublicationGrantRecipient,
        expiresAt: Date
    ) throws -> PublicationGrantIssueReceipt {
        try XCTUnwrap(PublicationGrantIssueReceipt(json: [
            "schemaVersion": "publication-owner-grant-issue-v1",
            "vaultId": vaultID,
            "grantId": "64444444-4444-4444-8444-444444444444",
            "publicationId": publication.publicationID,
            "publicationVersionId": publication.publicationVersionID!,
            "recipientDisplayLabel": recipient.displayLabel,
            "outcome": "created",
            "expiresAt": ISO8601DateFormatter().string(from: expiresAt),
            "credentialIssued": false,
        ]))
    }

    private func makeRuntime(subjectID: String, vaultID: String, generation: UInt64) -> AccountLeaseRuntime {
        let runtime = AccountLeaseRuntime(authorityEpoch: "epoch-v1")
        runtime.publish(session: makeSession(subjectID: subjectID, vaultID: vaultID, generation: generation))
        return runtime
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

final class PublicationVersionAuditAccessTests: XCTestCase {
    func testParserAcceptsOrderedRedactedPublicVersionSnapshots() throws {
        let publicationID = UUID().uuidString.lowercased()
        let audit = try XCTUnwrap(PublicationOwnerVersionAudit(json: [
            "schemaVersion": PublicationOwnerVersionAudit.schemaVersion,
            "vaultId": "vault-a",
            "publicationId": publicationID,
            "versions": [
                makeVersionJSON(id: UUID().uuidString, number: 2, isCurrent: true),
                makeVersionJSON(id: UUID().uuidString, number: 1, isCurrent: false),
            ],
        ]))

        XCTAssertEqual(audit.publicationID, publicationID)
        XCTAssertEqual(audit.versions.map(\.versionNumber), [2, 1])
        XCTAssertEqual(audit.versions.first?.items.first?.publicTitle, "第 2 版")
    }

    func testParserRejectsUnorderedOrMultipleCurrentVersions() {
        XCTAssertNil(PublicationOwnerVersionAudit(json: [
            "schemaVersion": PublicationOwnerVersionAudit.schemaVersion,
            "vaultId": "vault-a",
            "publicationId": UUID().uuidString,
            "versions": [
                makeVersionJSON(id: UUID().uuidString, number: 1, isCurrent: true),
                makeVersionJSON(id: UUID().uuidString, number: 2, isCurrent: true),
            ],
        ]))
    }

    func testUseCaseDropsVersionAuditAfterAccountSwitch() throws {
        let runtime = AccountLeaseRuntime(authorityEpoch: "epoch-v1")
        runtime.publish(session: makeSession(subjectID: "owner-a", vaultID: "vault-a", generation: 4))
        let lease = try XCTUnwrap(runtime.capture(forSubjectId: "owner-a"))
        let publicationID = UUID().uuidString.lowercased()
        let client = PublicationVersionAuditReaderClientStub()
        client.result = .success(try XCTUnwrap(PublicationOwnerVersionAudit(json: [
            "schemaVersion": PublicationOwnerVersionAudit.schemaVersion,
            "vaultId": "vault-a",
            "publicationId": publicationID,
            "versions": [
                makeVersionJSON(id: UUID().uuidString, number: 1, isCurrent: true),
            ],
        ])))
        client.beforeCompletion = {
            runtime.publish(session: self.makeSession(
                subjectID: "owner-b",
                vaultID: "vault-b",
                generation: 5
            ))
        }
        let useCase = PublicationVersionAuditUseCase(
            client: client,
            accountLeaseRuntime: runtime,
            isEnabled: { true }
        )

        let expectation = expectation(description: "stale version audit rejected")
        useCase.load(publicationID: publicationID, accountLease: lease) { result in
            guard case let .failure(error) = result else {
                XCTFail("Expected account switch to discard the version audit")
                expectation.fulfill()
                return
            }
            XCTAssertEqual(error as? PublicationManagementAccessError, .accountLeaseInvalid)
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1)
    }

    private func makeVersionJSON(id: String, number: Int, isCurrent: Bool) -> [String: Any] {
        [
            "publicationVersionId": id,
            "versionNumber": number,
            "confirmedAt": "2026-08-19T12:00:00Z",
            "projectionState": "active",
            "publicSnapshotHash": String(repeating: "a", count: 64),
            "isCurrent": isCurrent,
            "itemCount": 1,
            "items": [[
                "itemIndex": 0,
                "publicTitle": "第 \(number) 版",
                "publicBody": "公开正文。",
                "aiDisclosureRequired": true,
            ]],
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

final class PublicationLifecycleAccessTests: XCTestCase {
    func testWithdrawalPresentationRequiresOrdinaryLifecycleRouteAndWithdrawableState() throws {
        let withdrawable = try makeWithdrawablePublication()

        XCTAssertTrue(PublicationWithdrawalPresentationPolicy.isAvailable(
            for: withdrawable,
            routeAllowed: true
        ))
        XCTAssertFalse(PublicationWithdrawalPresentationPolicy.isAvailable(
            for: withdrawable,
            routeAllowed: false
        ))

        let missingAuthority = try XCTUnwrap(PublicationManagementPublication(json: [
            "publicationId": UUID().uuidString.lowercased(),
            "publicationVersionId": UUID().uuidString.lowercased(),
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
        XCTAssertFalse(PublicationWithdrawalPresentationPolicy.isAvailable(
            for: missingAuthority,
            routeAllowed: true
        ))
    }

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
            isRouteAllowed: { true }
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
            isRouteAllowed: { false }
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

final class PublicationDraftAccessTests: XCTestCase {
    func testEditorStatePreservesEditedOrderInCreateCommand() throws {
        let firstID = UUID().uuidString.lowercased()
        let secondID = UUID().uuidString.lowercased()
        var state = try OwnerPublicationDraftEditorState(items: [
            OwnerPublicationDraftEditorItem(
                memoryVersionID: firstID,
                memoryKindTitle: "经历",
                sensitivityTitle: "普通内容",
                publicTitle: "第一章",
                publicBody: "第一段"
            ),
            OwnerPublicationDraftEditorItem(
                memoryVersionID: secondID,
                memoryKindTitle: "感受",
                sensitivityTitle: "敏感内容",
                publicTitle: "第二章",
                publicBody: "第二段"
            ),
        ])

        state.move(from: 0, to: 1)
        var edited = state.items[0]
        edited.publicTitle = "更新后的第二章"
        state.update(edited, at: 0)
        let command = try state.makeCommand()

        XCTAssertEqual(command.items.map(\.memoryVersionID), [secondID, firstID])
        XCTAssertEqual(command.items.first?.publicTitle, "更新后的第二章")
    }

    func testOrderedDraftCommandPreservesOrderAndRejectsDuplicates() throws {
        let firstID = UUID().uuidString.lowercased()
        let secondID = UUID().uuidString.lowercased()
        let first = try PublicationDraftItemInput(
            memoryVersionID: firstID,
            publicTitle: "第一章",
            publicBody: "第一段公开正文。"
        )
        let second = try PublicationDraftItemInput(
            memoryVersionID: secondID,
            publicTitle: "第二章",
            publicBody: "第二段公开正文。"
        )
        let command = try PublicationDraftCreateCommand(items: [first, second])
        let payloadItems = try XCTUnwrap(command.requestPayload["items"] as? [[String: Any]])

        XCTAssertEqual(payloadItems.compactMap { $0["memoryVersionId"] as? String }, [firstID, secondID])
        XCTAssertThrowsError(try PublicationDraftCreateCommand(items: [first, first]))
    }

    func testRevisionCommandOmitsPrivateMemoryIdentifiersAndParsesV3Receipt() throws {
        let publicationID = UUID().uuidString.lowercased()
        let baseVersionID = UUID().uuidString.lowercased()
        let draftID = UUID().uuidString.lowercased()
        let command = try PublicationRevisionDraftCreateCommand(
            publicationID: publicationID,
            expectedPublicationVersionID: baseVersionID,
            expectedPublicationVersion: 2,
            items: [
                PublicationRevisionDraftItemInput(
                    itemIndex: 0,
                    publicTitle: "第三版标题",
                    publicBody: "第三版公开正文。"
                ),
            ]
        )
        let payloadItems = try XCTUnwrap(command.requestPayload["items"] as? [[String: Any]])

        XCTAssertEqual(command.requestPayload["publicationId"] as? String, publicationID)
        XCTAssertEqual(command.requestPayload["expectedPublicationVersionId"] as? String, baseVersionID)
        XCTAssertEqual(command.requestPayload["expectedPublicationVersion"] as? Int, 2)
        XCTAssertEqual(payloadItems.first?["itemIndex"] as? Int, 0)
        XCTAssertNil(payloadItems.first?["memoryVersionId"])

        let receipt = try XCTUnwrap(PublicationDraftReceipt(json: [
            "schemaVersion": "publication-authority-v3",
            "vaultId": "vault-a",
            "publicationId": publicationID,
            "draftId": draftID,
            "outcome": "created",
            "state": "draft",
            "expectedDraftRevision": 1,
            "expectedDraftSnapshotHash": String(repeating: "a", count: 64),
            "basePublicationVersionId": baseVersionID,
            "targetPublicationVersion": 3,
            "itemCount": 1,
            "items": [[
                "itemIndex": 0,
                "itemSnapshotHash": String(repeating: "b", count: 64),
                "preview": ["title": "第三版标题", "body": "第三版公开正文。"],
                "thirdPartyReviewRequired": false,
            ]],
            "requiresSecondConfirmation": true,
            "thirdPartyReviewRequired": false,
            "aiDisclosureRequired": true,
        ]))

        XCTAssertEqual(receipt.basePublicationVersionID, baseVersionID)
        XCTAssertEqual(receipt.targetPublicationVersion, 3)
        XCTAssertNil(receipt.items.first?.memoryVersionID)
    }

    func testV2DraftAndConfirmationReceiptsRequireContiguousOrderedItems() throws {
        let vaultID = "vault-a"
        let publicationID = UUID().uuidString.lowercased()
        let draftID = UUID().uuidString.lowercased()
        let firstID = UUID().uuidString.lowercased()
        let secondID = UUID().uuidString.lowercased()
        let draft = try XCTUnwrap(PublicationDraftReceipt(json: [
            "schemaVersion": "publication-authority-v2",
            "vaultId": vaultID,
            "publicationId": publicationID,
            "draftId": draftID,
            "outcome": "created",
            "state": "draft",
            "expectedDraftRevision": 1,
            "expectedDraftSnapshotHash": String(repeating: "a", count: 64),
            "itemCount": 2,
            "items": [
                makeDraftReceiptItem(index: 0, memoryVersionID: firstID, hash: "b"),
                makeDraftReceiptItem(index: 1, memoryVersionID: secondID, hash: "c"),
            ],
            "requiresSecondConfirmation": true,
            "thirdPartyReviewRequired": false,
            "aiDisclosureRequired": true,
        ]))
        XCTAssertEqual(draft.items.map(\.memoryVersionID), [firstID, secondID])

        let confirmation = try XCTUnwrap(PublicationDraftConfirmReceipt(json: [
            "schemaVersion": "publication-authority-v2",
            "vaultId": vaultID,
            "publicationId": publicationID,
            "draftId": draftID,
            "publicationVersionId": UUID().uuidString.lowercased(),
            "publicationVersion": 1,
            "outcome": "created",
            "publicationState": "confirmed",
            "projectionState": "active",
            "publicProjectionHash": String(repeating: "d", count: 64),
            "itemCount": 2,
            "publicProjectionItemHashes": [
                String(repeating: "e", count: 64),
                String(repeating: "f", count: 64),
            ],
            "aiDisclosureRequired": true,
        ]))
        XCTAssertEqual(confirmation.itemCount, 2)

        var malformed = draftJSON(
            vaultID: vaultID,
            publicationID: publicationID,
            draftID: draftID,
            firstID: firstID,
            secondID: secondID
        )
        malformed["items"] = [
            makeDraftReceiptItem(index: 1, memoryVersionID: firstID, hash: "b"),
            makeDraftReceiptItem(index: 0, memoryVersionID: secondID, hash: "c"),
        ]
        XCTAssertNil(PublicationDraftReceipt(json: malformed))
    }

    func testCreateDropsResultAfterAccountSwitch() throws {
        let runtime = AccountLeaseRuntime(authorityEpoch: "epoch-v1")
        runtime.publish(session: makeSession(
            subjectID: "owner-a",
            vaultID: "vault-a",
            generation: 4
        ))
        let lease = try XCTUnwrap(runtime.capture(forSubjectId: "owner-a"))
        let client = PublicationDraftWriterClientStub()
        let publicationID = UUID().uuidString.lowercased()
        let draftID = UUID().uuidString.lowercased()
        client.createResult = .success(try XCTUnwrap(PublicationDraftReceipt(json: draftJSON(
            vaultID: "vault-a",
            publicationID: publicationID,
            draftID: draftID,
            firstID: UUID().uuidString.lowercased(),
            secondID: UUID().uuidString.lowercased()
        ))))
        client.beforeCreateCompletion = {
            runtime.publish(session: self.makeSession(
                subjectID: "owner-b",
                vaultID: "vault-b",
                generation: 5
            ))
        }
        let useCase = PublicationDraftUseCase(
            client: client,
            accountLeaseRuntime: runtime,
            isEnabled: { true }
        )
        let command = try PublicationDraftCreateCommand(items: [
            PublicationDraftItemInput(
                memoryVersionID: UUID().uuidString.lowercased(),
                publicTitle: "公开标题",
                publicBody: "公开正文。"
            ),
        ])

        let expectation = expectation(description: "stale publication draft rejected")
        useCase.create(command: command, accountLease: lease) { result in
            guard case let .failure(error) = result else {
                XCTFail("Expected account switch to discard the draft response")
                expectation.fulfill()
                return
            }
            XCTAssertEqual(error as? PublicationDraftAccessError, .accountLeaseInvalid)
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1)
    }

    func testRevisionDropsResultAfterAccountSwitch() throws {
        let runtime = AccountLeaseRuntime(authorityEpoch: "epoch-v1")
        runtime.publish(session: makeSession(
            subjectID: "owner-a",
            vaultID: "vault-a",
            generation: 4
        ))
        let lease = try XCTUnwrap(runtime.capture(forSubjectId: "owner-a"))
        let client = PublicationDraftWriterClientStub()
        let publicationID = UUID().uuidString.lowercased()
        let versionID = UUID().uuidString.lowercased()
        let command = try PublicationRevisionDraftCreateCommand(
            publicationID: publicationID,
            expectedPublicationVersionID: versionID,
            expectedPublicationVersion: 1,
            items: [
                PublicationRevisionDraftItemInput(
                    itemIndex: 0,
                    publicTitle: "第二版",
                    publicBody: "第二版公开正文。"
                ),
            ]
        )
        client.revisionResult = .success(try XCTUnwrap(PublicationDraftReceipt(json: [
            "schemaVersion": "publication-authority-v3",
            "vaultId": "vault-a",
            "publicationId": publicationID,
            "draftId": UUID().uuidString.lowercased(),
            "outcome": "created",
            "state": "draft",
            "expectedDraftRevision": 1,
            "expectedDraftSnapshotHash": String(repeating: "a", count: 64),
            "basePublicationVersionId": versionID,
            "targetPublicationVersion": 2,
            "itemCount": 1,
            "items": [[
                "itemIndex": 0,
                "itemSnapshotHash": String(repeating: "b", count: 64),
                "preview": ["title": "第二版", "body": "第二版公开正文。"],
                "thirdPartyReviewRequired": false,
            ]],
            "requiresSecondConfirmation": true,
            "thirdPartyReviewRequired": false,
            "aiDisclosureRequired": true,
        ])))
        client.beforeRevisionCompletion = {
            runtime.publish(session: self.makeSession(
                subjectID: "owner-b",
                vaultID: "vault-b",
                generation: 5
            ))
        }
        let useCase = PublicationDraftUseCase(
            client: client,
            accountLeaseRuntime: runtime,
            isEnabled: { true }
        )

        let expectation = expectation(description: "stale publication revision rejected")
        useCase.createRevision(command: command, accountLease: lease) { result in
            guard case let .failure(error) = result else {
                XCTFail("Expected account switch to discard the revision response")
                expectation.fulfill()
                return
            }
            XCTAssertEqual(error as? PublicationDraftAccessError, .accountLeaseInvalid)
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1)
    }

    func testConfirmationStopsBeforeClientWhenThirdPartyReviewIsRequired() throws {
        let runtime = AccountLeaseRuntime(authorityEpoch: "epoch-v1")
        runtime.publish(session: makeSession(subjectID: "owner-a", vaultID: "vault-a", generation: 4))
        let lease = try XCTUnwrap(runtime.capture(forSubjectId: "owner-a"))
        let client = PublicationDraftWriterClientStub()
        let draft = try XCTUnwrap(PublicationDraftReceipt(json: draftJSON(
            vaultID: "vault-a",
            publicationID: UUID().uuidString.lowercased(),
            draftID: UUID().uuidString.lowercased(),
            firstID: UUID().uuidString.lowercased(),
            secondID: UUID().uuidString.lowercased(),
            thirdPartyReviewRequired: true
        )))
        let command = try PublicationDraftConfirmCommand(
            expectedDraftRevision: draft.expectedDraftRevision,
            expectedDraftSnapshotHash: draft.expectedDraftSnapshotHash,
            secondConfirmation: true
        )
        let useCase = PublicationDraftUseCase(
            client: client,
            accountLeaseRuntime: runtime,
            isEnabled: { true }
        )

        let expectation = expectation(description: "third-party review blocks confirmation")
        useCase.confirm(draft: draft, command: command, accountLease: lease) { result in
            guard case let .failure(error) = result else {
                XCTFail("Expected third-party review to block confirmation")
                expectation.fulfill()
                return
            }
            XCTAssertEqual(error as? PublicationDraftAccessError, .thirdPartyReviewRequired)
            XCTAssertEqual(client.confirmCallCount, 0)
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1)
    }

    private func makeDraftReceiptItem(
        index: Int,
        memoryVersionID: String,
        hash: Character
    ) -> [String: Any] {
        [
            "itemIndex": index,
            "memoryVersionId": memoryVersionID,
            "itemSnapshotHash": String(repeating: hash, count: 64),
            "preview": ["title": "第 \(index + 1) 章", "body": "公开正文。"],
            "thirdPartyReviewRequired": false,
        ]
    }

    private func draftJSON(
        vaultID: String,
        publicationID: String,
        draftID: String,
        firstID: String,
        secondID: String,
        thirdPartyReviewRequired: Bool = false
    ) -> [String: Any] {
        [
            "schemaVersion": "publication-authority-v2",
            "vaultId": vaultID,
            "publicationId": publicationID,
            "draftId": draftID,
            "outcome": "created",
            "state": "draft",
            "expectedDraftRevision": 1,
            "expectedDraftSnapshotHash": String(repeating: "a", count: 64),
            "itemCount": 2,
            "items": [
                makeDraftReceiptItem(index: 0, memoryVersionID: firstID, hash: "b"),
                makeDraftReceiptItem(index: 1, memoryVersionID: secondID, hash: "c"),
            ],
            "requiresSecondConfirmation": true,
            "thirdPartyReviewRequired": thirdPartyReviewRequired,
            "aiDisclosureRequired": true,
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

private final class PublicationVersionAuditReaderClientStub: PublicationVersionAuditReaderClient {
    var result: Result<PublicationOwnerVersionAudit, Error>?
    var beforeCompletion: (() -> Void)?

    func fetchOwnerPublicationVersions(
        vaultID: String,
        publicationID: String,
        accountLease: AccountLease,
        completion: @escaping (Result<PublicationOwnerVersionAudit, Error>) -> Void
    ) {
        beforeCompletion?()
        completion(result ?? .failure(PublicationManagementAccessError.unavailable))
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

private final class PublicationGrantManagementClientStub: PublicationGrantManagementClient {
    var issueResult: Result<PublicationGrantIssueReceipt, Error>?
    var revokeResult: Result<PublicationGrantRevokeReceipt, Error>?
    var beforeIssueCompletion: (() -> Void)?
    private(set) var issueCallCount = 0

    func issueOwnerPublicationGrant(
        vaultID: String,
        command: PublicationGrantIssueCommand,
        accountLease: AccountLease,
        completion: @escaping (Result<PublicationGrantIssueReceipt, Error>) -> Void
    ) {
        issueCallCount += 1
        beforeIssueCompletion?()
        completion(issueResult ?? .failure(PublicationManagementAccessError.unavailable))
    }

    func revokeOwnerPublicationGrant(
        vaultID: String,
        grantID: String,
        command: PublicationGrantRevokeCommand,
        accountLease: AccountLease,
        completion: @escaping (Result<PublicationGrantRevokeReceipt, Error>) -> Void
    ) {
        completion(revokeResult ?? .failure(PublicationManagementAccessError.unavailable))
    }
}

private final class PublicationDraftWriterClientStub: PublicationDraftWriterClient {
    var createResult: Result<PublicationDraftReceipt, Error>?
    var revisionResult: Result<PublicationDraftReceipt, Error>?
    var confirmResult: Result<PublicationDraftConfirmReceipt, Error>?
    var beforeCreateCompletion: (() -> Void)?
    var beforeRevisionCompletion: (() -> Void)?
    var confirmCallCount = 0

    func createPublicationDraft(
        vaultID: String,
        command: PublicationDraftCreateCommand,
        accountLease: AccountLease,
        completion: @escaping (Result<PublicationDraftReceipt, Error>) -> Void
    ) {
        beforeCreateCompletion?()
        completion(createResult ?? .failure(PublicationDraftAccessError.unavailable))
    }

    func createPublicationRevisionDraft(
        vaultID: String,
        publicationID: String,
        command: PublicationRevisionDraftCreateCommand,
        accountLease: AccountLease,
        completion: @escaping (Result<PublicationDraftReceipt, Error>) -> Void
    ) {
        beforeRevisionCompletion?()
        completion(revisionResult ?? .failure(PublicationDraftAccessError.unavailable))
    }

    func confirmPublicationDraft(
        vaultID: String,
        publicationID: String,
        draftID: String,
        command: PublicationDraftConfirmCommand,
        accountLease: AccountLease,
        completion: @escaping (Result<PublicationDraftConfirmReceipt, Error>) -> Void
    ) {
        confirmCallCount += 1
        completion(confirmResult ?? .failure(PublicationDraftAccessError.unavailable))
    }
}

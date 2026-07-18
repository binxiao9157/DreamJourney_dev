import XCTest
#if canImport(DreamJourney)
@testable import DreamJourney
#elseif canImport(DreamJourneyCore)
@testable import DreamJourneyCore
#endif

final class OwnerTruthContractsTests: XCTestCase {
    func testOntologyKeepsMemoryKindAndPerspectiveOrthogonal() {
        XCTAssertEqual(
            Set(OwnerTruthMemoryKind.allCases),
            [.experience, .knowledge, .emotion]
        )
        XCTAssertEqual(
            Set(OwnerTruthPerspectiveType.allCases),
            [.firstPerson, .reported, .inferred]
        )
    }

    func testTerminalDecisionCannotBeRewritten() throws {
        let accepted = try advanceOwnerTruthCandidateDecision(
            current: .pending,
            requested: .accepted
        )

        XCTAssertEqual(accepted, .accepted)
        XCTAssertEqual(
            try advanceOwnerTruthCandidateDecision(current: accepted, requested: .accepted),
            .accepted
        )
        XCTAssertThrowsError(
            try advanceOwnerTruthCandidateDecision(current: accepted, requested: .rejected)
        ) { error in
            XCTAssertEqual(error as? OwnerTruthContractError, .terminalDecisionImmutable)
        }
    }

    func testSourceReferenceMaintainsStableIdentifiers() throws {
        let vaultID = try XCTUnwrap(OwnerTruthVaultID("vault-a"))
        let sourceID = OwnerTruthRecordID(
            rawValue: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
        )

        let reference = OwnerTruthSourceReference(
            vaultID: vaultID,
            sourceID: sourceID,
            sourceVersion: 0
        )

        XCTAssertEqual(reference.vaultID.rawValue, "vault-a")
        XCTAssertEqual(reference.sourceID, sourceID)
        XCTAssertEqual(reference.sourceVersion, 1)
    }

    func testTypedIdentifiersEncodeAsScalarContractValues() throws {
        let vaultID = try XCTUnwrap(OwnerTruthVaultID("vault-a"))
        let recordID = OwnerTruthRecordID(
            rawValue: UUID(uuidString: "00000000-0000-0000-0000-000000000009")!
        )

        XCTAssertEqual(String(data: try JSONEncoder().encode(vaultID), encoding: .utf8), "\"vault-a\"")
        XCTAssertEqual(
            String(data: try JSONEncoder().encode(recordID), encoding: .utf8),
            "\"00000000-0000-0000-0000-000000000009\""
        )
    }

    func testCandidateInboxDecodesTypedProposalAndEvidence() throws {
        let vaultID = try XCTUnwrap(OwnerTruthVaultID("vault-owner-a"))
        let candidateID = "00000000-0000-0000-0000-000000000010"
        let sourceID = "00000000-0000-0000-0000-000000000011"
        let inbox = try OwnerTruthCandidateInbox(
            backendJSONObject: [
                "schemaVersion": "owner-truth-candidate-inbox-v1",
                "vaultId": vaultID.rawValue,
                "candidates": [[
                    "candidateId": candidateID,
                    "sourceId": sourceID,
                    "memoryKind": "experience",
                    "perspectiveType": "firstPerson",
                    "epistemicStatus": "recalled",
                    "sensitivity": "standard",
                    "contentSchemaVersion": "owner-truth-candidate-content-v1",
                    "content": [
                        "summary": "小时候在院子里听父亲讲故事",
                        "confidence": 0.92,
                    ],
                    "contentHash": "content-hash",
                    "sourceRefs": [[
                        "sourceId": sourceID,
                        "sourceVersion": 1,
                        "span": ["start": 0, "end": 12],
                    ]],
                    "reviewMode": "single",
                    "candidateVersion": 1,
                    "createdAt": "2026-07-19T08:00:00.000Z",
                ]],
            ],
            expectedVaultID: vaultID
        )

        let candidate = try XCTUnwrap(inbox.candidates.first)
        XCTAssertEqual(candidate.vaultID, vaultID)
        XCTAssertEqual(candidate.id.rawValue.uuidString.lowercased(), candidateID)
        XCTAssertEqual(candidate.sourceReferences.count, 1)
        XCTAssertEqual(candidate.sourceReferences[0].span, OwnerTruthEvidenceSpan(backendJSONObject: ["start": 0, "end": 12]))
        XCTAssertEqual(candidate.content["summary"], .string("小时候在院子里听父亲讲故事"))
        XCTAssertEqual(candidate.content["confidence"], .number(0.92))
    }

    func testCandidateInboxRejectsMismatchedVault() throws {
        let vaultID = try XCTUnwrap(OwnerTruthVaultID("vault-owner-a"))
        XCTAssertThrowsError(
            try OwnerTruthCandidateInbox(
                backendJSONObject: [
                    "schemaVersion": "owner-truth-candidate-inbox-v1",
                    "vaultId": "vault-owner-b",
                    "candidates": [],
                ],
                expectedVaultID: vaultID
            )
        ) { error in
            XCTAssertEqual(
                error as? OwnerTruthRemoteContractError,
                .invalidInbox("schemaVersion, vaultId or candidates does not match the contract")
            )
        }
    }

    func testCorrectReviewCommandRequiresValueAndProducesOnlyCorrectPayload() throws {
        XCTAssertThrowsError(
            try OwnerTruthCandidateReviewCommand(
                commandID: "candidate-correct-missing-value",
                expectedCandidateVersion: 1,
                action: .correct,
                reasonCode: "ownerCorrected"
            )
        ) { error in
            XCTAssertEqual(
                error as? OwnerTruthRemoteContractError,
                .invalidCommand("correct requires correctedValue and correctedValueSchemaVersion")
            )
        }

        let command = try OwnerTruthCandidateReviewCommand(
            commandID: "candidate-correct-001",
            expectedCandidateVersion: 2,
            action: .correct,
            correctedValue: ["summary": .string("更正后的记忆")],
            correctedValueSchemaVersion: "owner-truth-candidate-content-v1",
            reasonCode: "ownerCorrected"
        )

        let payload = command.backendPayload
        XCTAssertEqual(payload["action"] as? String, "correct")
        XCTAssertEqual(payload["expectedCandidateVersion"] as? Int, 2)
        XCTAssertEqual(
            (payload["correctedValue"] as? [String: Any])?["summary"] as? String,
            "更正后的记忆"
        )
        XCTAssertEqual(payload["correctedValueSchemaVersion"] as? String, "owner-truth-candidate-content-v1")

        XCTAssertThrowsError(
            try OwnerTruthCandidateReviewCommand(
                commandID: "candidate-accept-with-value",
                expectedCandidateVersion: 1,
                action: .accept,
                correctedValue: ["summary": .string("不应发送")],
                reasonCode: "ownerReviewed"
            )
        )
    }

    func testRejectDecisionDoesNotCreateMemoryVersion() throws {
        let candidateID = OwnerTruthRecordID(
            rawValue: UUID(uuidString: "00000000-0000-0000-0000-000000000020")!
        )
        let result = try OwnerTruthCandidateDecisionResult(
            backendJSONObject: [
                "schemaVersion": "owner-truth-candidate-decision-memory-v1",
                "status": "created",
                "receipt": [
                    "receiptId": "00000000-0000-0000-0000-000000000021",
                    "candidateId": candidateID.rawValue.uuidString.lowercased(),
                    "decision": "rejected",
                    "candidateVersion": 1,
                    "candidateBeforeHash": "before-hash",
                    "candidateAfterHash": "after-hash",
                    "correctedValueId": NSNull(),
                ],
                "memoryActivation": [
                    "status": "notApplicable",
                    "memoryId": NSNull(),
                    "memoryVersionId": NSNull(),
                    "contentHash": NSNull(),
                ],
            ],
            expectedCandidateID: candidateID
        )

        XCTAssertEqual(result.receipt.decision, .rejected)
        XCTAssertEqual(result.memoryActivation.outcome, .notApplicable)
        XCTAssertNil(result.memoryActivation.memoryID)
        XCTAssertNil(result.memoryActivation.memoryVersionID)
    }

    func testAcceptedDecisionRejectsMissingMemoryVersionActivation() throws {
        let candidateID = OwnerTruthRecordID(
            rawValue: UUID(uuidString: "00000000-0000-0000-0000-000000000030")!
        )
        XCTAssertThrowsError(
            try OwnerTruthCandidateDecisionResult(
                backendJSONObject: [
                    "schemaVersion": "owner-truth-candidate-decision-memory-v1",
                    "status": "created",
                    "receipt": [
                        "receiptId": "00000000-0000-0000-0000-000000000031",
                        "candidateId": candidateID.rawValue.uuidString.lowercased(),
                        "decision": "accepted",
                        "candidateVersion": 1,
                        "candidateBeforeHash": "before-hash",
                        "candidateAfterHash": "after-hash",
                        "correctedValueId": NSNull(),
                    ],
                    "memoryActivation": [
                        "status": "notApplicable",
                        "memoryId": NSNull(),
                        "memoryVersionId": NSNull(),
                        "contentHash": NSNull(),
                    ],
                ],
                expectedCandidateID: candidateID
            )
        ) { error in
            XCTAssertEqual(
                error as? OwnerTruthRemoteContractError,
                .invalidDecision("accepted or corrected decisions require a MemoryVersion activation")
            )
        }
    }

    func testCandidateReviewUseCaseMapsInboxAndAcceptsThroughTypedReceipt() throws {
        let (runtime, lease) = try makeActiveRuntime()
        let candidateID = recordID("00000000-0000-0000-0000-000000000041")
        let client = CandidateReviewClientSpy()
        client.inboxResult = .success(try candidateInbox(vaultID: lease.vaultId, candidateID: candidateID))
        client.reviewResult = .success(try decisionResult(candidateID: candidateID, decision: .accepted))
        let useCase = OwnerTruthCandidateReviewUseCase(
            accountLease: lease,
            client: client,
            accountLeaseRuntime: runtime,
            qaGateEnabled: { true },
            commandIDFactory: { "candidate-review-accept-001" }
        )

        useCase.send(.refresh)

        XCTAssertEqual(useCase.viewState.phase, .ready)
        XCTAssertEqual(useCase.viewState.items.count, 1)
        XCTAssertEqual(useCase.viewState.items.first?.proposalPreview, "小时候在院子里听父亲讲故事")
        XCTAssertEqual(useCase.viewState.items.first?.evidenceCount, 1)

        useCase.send(.accept(candidateID: candidateID))

        XCTAssertEqual(client.reviewedCommands.count, 1)
        XCTAssertEqual(client.reviewedCommands.first?.action, .accept)
        XCTAssertEqual(client.reviewedCommands.first?.expectedCandidateVersion, 1)
        XCTAssertEqual(useCase.viewState.phase, .empty)
        XCTAssertEqual(useCase.viewState.notice, .candidateAccepted)
        XCTAssertEqual(useCase.viewState.latestReceipt?.decision, .accepted)
        XCTAssertTrue(useCase.viewState.latestReceipt?.createdMemoryVersion == true)
    }

    func testCandidateReviewUseCasePreservesCandidateContentForCorrection() throws {
        let (runtime, lease) = try makeActiveRuntime()
        let candidateID = recordID("00000000-0000-0000-0000-000000000042")
        let client = CandidateReviewClientSpy()
        client.inboxResult = .success(try candidateInbox(vaultID: lease.vaultId, candidateID: candidateID))
        client.reviewResult = .success(try decisionResult(candidateID: candidateID, decision: .corrected))
        let useCase = OwnerTruthCandidateReviewUseCase(
            accountLease: lease,
            client: client,
            accountLeaseRuntime: runtime,
            qaGateEnabled: { true },
            commandIDFactory: { "candidate-review-correct-001" }
        )

        useCase.send(.refresh)
        useCase.send(.correct(candidateID: candidateID, correctedSummary: "实际是在外祖父的院子里听故事"))

        let command = try XCTUnwrap(client.reviewedCommands.first)
        XCTAssertEqual(command.action, .correct)
        XCTAssertEqual(command.reasonCode, "ownerCorrected")
        XCTAssertEqual(command.correctedValue?["summary"], .string("实际是在外祖父的院子里听故事"))
        XCTAssertEqual(command.correctedValue?["confidence"], .number(0.92))
        XCTAssertEqual(command.correctedValueSchemaVersion, "owner-truth-candidate-content-v1")
        XCTAssertEqual(useCase.viewState.notice, .candidateCorrected)
        XCTAssertEqual(useCase.viewState.latestReceipt?.decision, .corrected)
    }

    func testCandidateReviewUseCaseRejectsStaleCompletionAfterAccountSwitch() throws {
        let (runtime, lease) = try makeActiveRuntime()
        let candidateID = recordID("00000000-0000-0000-0000-000000000043")
        let client = CandidateReviewClientSpy()
        client.deferInbox = true
        let useCase = OwnerTruthCandidateReviewUseCase(
            accountLease: lease,
            client: client,
            accountLeaseRuntime: runtime,
            qaGateEnabled: { true }
        )

        useCase.send(.refresh)
        XCTAssertEqual(useCase.viewState.phase, .loading)
        runtime.publish(session: accountSession(
            subjectId: "owner-b",
            vaultId: "vault-b",
            generation: 2,
            generationID: UUID(uuidString: "00000000-0000-0000-0000-000000000102")!
        ))
        client.completeDeferredInbox(.success(try candidateInbox(vaultID: lease.vaultId, candidateID: candidateID)))

        XCTAssertEqual(useCase.viewState.phase, .unavailable)
        XCTAssertEqual(useCase.viewState.notice, .staleAccountLease)
        XCTAssertTrue(useCase.viewState.items.isEmpty)
    }

    func testCandidateReviewUseCaseRejectsMismatchedTerminalDecision() throws {
        let (runtime, lease) = try makeActiveRuntime()
        let candidateID = recordID("00000000-0000-0000-0000-000000000044")
        let client = CandidateReviewClientSpy()
        client.inboxResult = .success(try candidateInbox(vaultID: lease.vaultId, candidateID: candidateID))
        client.reviewResult = .success(try decisionResult(candidateID: candidateID, decision: .rejected))
        let useCase = OwnerTruthCandidateReviewUseCase(
            accountLease: lease,
            client: client,
            accountLeaseRuntime: runtime,
            qaGateEnabled: { true },
            commandIDFactory: { "candidate-review-mismatch-001" }
        )

        useCase.send(.refresh)
        useCase.send(.accept(candidateID: candidateID))

        XCTAssertEqual(useCase.viewState.phase, .failed)
        XCTAssertEqual(useCase.viewState.notice, .reviewResultMismatch)
        XCTAssertEqual(useCase.viewState.items.map(\.id), [candidateID])
    }

    private func makeActiveRuntime() throws -> (AccountLeaseRuntime, AccountLease) {
        let runtime = AccountLeaseRuntime(authorityEpoch: "epoch-v1")
        runtime.publish(session: accountSession(
            subjectId: "owner-a",
            vaultId: "vault-a",
            generation: 1,
            generationID: UUID(uuidString: "00000000-0000-0000-0000-000000000101")!
        ))
        return (runtime, try XCTUnwrap(runtime.capture(forSubjectId: "owner-a")))
    }

    private func accountSession(
        subjectId: String,
        vaultId: String,
        generation: UInt64,
        generationID: UUID
    ) -> AccountSession {
        AccountSession(
            subjectId: subjectId,
            vaultId: vaultId,
            sessionId: "session-\(generation)",
            tokenFamilyId: "family-\(generation)",
            sessionVersion: Int(generation),
            generation: generation,
            generationId: generationID,
            state: .active,
            activatedAt: Date(timeIntervalSince1970: 1_700_000_000)
        )
    }

    private func recordID(_ rawValue: String) -> OwnerTruthRecordID {
        OwnerTruthRecordID(rawValue: UUID(uuidString: rawValue)!)
    }

    private func candidateInbox(
        vaultID: String,
        candidateID: OwnerTruthRecordID
    ) throws -> OwnerTruthCandidateInbox {
        let sourceID = "00000000-0000-0000-0000-000000000045"
        let expectedVaultID = try XCTUnwrap(OwnerTruthVaultID(vaultID))
        return try OwnerTruthCandidateInbox(
            backendJSONObject: [
                "schemaVersion": "owner-truth-candidate-inbox-v1",
                "vaultId": vaultID,
                "candidates": [[
                    "candidateId": candidateID.rawValue.uuidString.lowercased(),
                    "sourceId": sourceID,
                    "memoryKind": "experience",
                    "perspectiveType": "firstPerson",
                    "epistemicStatus": "recalled",
                    "sensitivity": "standard",
                    "contentSchemaVersion": "owner-truth-candidate-content-v1",
                    "content": [
                        "summary": "小时候在院子里听父亲讲故事",
                        "confidence": 0.92,
                    ],
                    "contentHash": "content-hash",
                    "sourceRefs": [[
                        "sourceId": sourceID,
                        "sourceVersion": 1,
                    ]],
                    "reviewMode": "single",
                    "candidateVersion": 1,
                ]],
            ],
            expectedVaultID: expectedVaultID
        )
    }

    private func decisionResult(
        candidateID: OwnerTruthRecordID,
        decision: OwnerTruthCandidateDecision
    ) throws -> OwnerTruthCandidateDecisionResult {
        let activatesMemory = decision == .accepted || decision == .corrected
        let receipt: [String: Any] = [
            "receiptId": "00000000-0000-0000-0000-000000000046",
            "candidateId": candidateID.rawValue.uuidString.lowercased(),
            "decision": decision.rawValue,
            "candidateVersion": 2,
            "candidateBeforeHash": "before-hash",
            "candidateAfterHash": "after-hash",
            "correctedValueId": NSNull(),
        ]
        let memoryActivation: [String: Any] = [
            "status": activatesMemory ? "created" : "notApplicable",
            "memoryId": activatesMemory ? "00000000-0000-0000-0000-000000000047" : NSNull(),
            "memoryVersionId": activatesMemory ? "00000000-0000-0000-0000-000000000048" : NSNull(),
            "contentHash": activatesMemory ? "memory-hash" : NSNull(),
        ]
        return try OwnerTruthCandidateDecisionResult(
            backendJSONObject: [
                "schemaVersion": "owner-truth-candidate-decision-memory-v1",
                "status": "created",
                "receipt": receipt,
                "memoryActivation": memoryActivation,
            ],
            expectedCandidateID: candidateID
        )
    }
}

private final class CandidateReviewClientSpy: OwnerTruthCandidateReviewClient {
    var inboxResult: Result<OwnerTruthCandidateInbox, Error>?
    var reviewResult: Result<OwnerTruthCandidateDecisionResult, Error>?
    var deferInbox = false
    private var deferredInboxCompletion: ((Result<OwnerTruthCandidateInbox, Error>) -> Void)?
    private(set) var reviewedCommands: [OwnerTruthCandidateReviewCommand] = []

    func fetchOwnerTruthCandidateInbox(
        vaultID: OwnerTruthVaultID,
        completion: @escaping (Result<OwnerTruthCandidateInbox, Error>) -> Void
    ) {
        if deferInbox {
            deferredInboxCompletion = completion
            return
        }
        completion(inboxResult ?? .failure(CandidateReviewClientSpyError.missingInboxResult))
    }

    func reviewOwnerTruthCandidate(
        vaultID: OwnerTruthVaultID,
        candidateID: OwnerTruthRecordID,
        command: OwnerTruthCandidateReviewCommand,
        completion: @escaping (Result<OwnerTruthCandidateDecisionResult, Error>) -> Void
    ) {
        reviewedCommands.append(command)
        completion(reviewResult ?? .failure(CandidateReviewClientSpyError.missingReviewResult))
    }

    func completeDeferredInbox(_ result: Result<OwnerTruthCandidateInbox, Error>) {
        let completion = deferredInboxCompletion
        deferredInboxCompletion = nil
        completion?(result)
    }
}

private enum CandidateReviewClientSpyError: Error {
    case missingInboxResult
    case missingReviewResult
}

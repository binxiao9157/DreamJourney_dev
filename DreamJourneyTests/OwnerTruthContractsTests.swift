import CryptoKit
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

    func testInterviewCandidateReviewDecodesSeparatedPathsAndNonActivationReceipt() throws {
        let vaultID = try XCTUnwrap(OwnerTruthVaultID("vault-owner-a"))
        let reviewBatchID = recordID("00000000-0000-0000-0000-000000000045")
        let standardID = recordID("00000000-0000-0000-0000-000000000046")
        let sensitiveID = recordID("00000000-0000-0000-0000-000000000047")
        let sourceID = "00000000-0000-0000-0000-000000000048"
        let extractionID = "00000000-0000-0000-0000-000000000049"
        let response: [String: Any] = [
            "schemaVersion": OwnerTruthInterviewCandidateReviewBatch.schemaVersion,
            "vaultId": vaultID.rawValue,
            "review": [
                "schemaVersion": OwnerTruthInterviewCandidateReviewBatch.compositionSchemaVersion,
                "reviewBatchId": reviewBatchID.rawValue.uuidString,
                "admissionId": "00000000-0000-0000-0000-000000000050",
                "sourceId": sourceID,
                "sourceVersion": 1,
                "authorityEpoch": 0,
                "readiness": OwnerTruthInterviewCandidateReviewReadiness.reviewReady.rawValue,
                "latestExtractionStatus": "succeeded",
                "batchCandidateCount": 1,
                "singleCandidateCount": 1,
            ],
            "batchCandidates": [[
                "candidateId": standardID.rawValue.uuidString,
                "sourceId": sourceID,
                "memoryKind": OwnerTruthMemoryKind.experience.rawValue,
                "perspectiveType": OwnerTruthPerspectiveType.firstPerson.rawValue,
                "epistemicStatus": OwnerTruthEpistemicStatus.recalled.rawValue,
                "sensitivity": OwnerTruthSensitivityLevel.standard.rawValue,
                "contentSchemaVersion": "owner-truth-candidate-content-v1",
                "content": ["summary": "院子里听家人讲故事"],
                "contentHash": "interview-standard-hash",
                "sourceRefs": [["sourceId": sourceID, "sourceVersion": 1]],
                "reviewMode": "batch",
                "candidateVersion": 1,
                "extractionId": extractionID,
                "reviewPath": OwnerTruthInterviewCandidateReviewPath.batch.rawValue,
            ]],
            "singleCandidates": [[
                "candidateId": sensitiveID.rawValue.uuidString,
                "sourceId": sourceID,
                "memoryKind": OwnerTruthMemoryKind.experience.rawValue,
                "perspectiveType": OwnerTruthPerspectiveType.firstPerson.rawValue,
                "epistemicStatus": OwnerTruthEpistemicStatus.recalled.rawValue,
                "sensitivity": OwnerTruthSensitivityLevel.sensitive.rawValue,
                "contentSchemaVersion": "owner-truth-candidate-content-v1",
                "content": ["summary": "需要逐条确认的敏感经历"],
                "contentHash": "interview-sensitive-hash",
                "sourceRefs": [["sourceId": sourceID, "sourceVersion": 1]],
                "reviewMode": "single",
                "candidateVersion": 1,
                "extractionId": extractionID,
                "reviewPath": OwnerTruthInterviewCandidateReviewPath.single.rawValue,
            ]],
        ]

        let review = try OwnerTruthInterviewCandidateReviewBatch(
            backendJSONObject: response,
            expectedVaultID: vaultID,
            expectedReviewBatchID: reviewBatchID
        )
        XCTAssertEqual(review.batchCandidates.map(\.id), [standardID])
        XCTAssertEqual(review.singleCandidates.map(\.id), [sensitiveID])
        XCTAssertEqual(review.batchCandidates.first?.reviewPath, .batch)
        XCTAssertEqual(review.singleCandidates.first?.reviewPath, .single)

        let command = try OwnerTruthInterviewCandidateBatchAcceptCommand(
            commandID: "interview-batch-accept-ios-001",
            reviewBatchID: reviewBatchID,
            selections: [
                try OwnerTruthInterviewCandidateBatchSelection(
                    candidateID: standardID,
                    expectedCandidateVersion: 1
                )
            ],
            reasonCode: "ownerReviewed"
        )
        let accepted = try OwnerTruthInterviewCandidateBatchAcceptResult(
            backendJSONObject: [
                "schemaVersion": OwnerTruthInterviewCandidateBatchAcceptResult.schemaVersion,
                "status": OwnerTruthCommandOutcome.created.rawValue,
                "batchDecisionId": "00000000-0000-0000-0000-000000000051",
                "reviewBatchId": reviewBatchID.rawValue.uuidString,
                "acceptedCandidateCount": 1,
                "receipts": [[
                    "receiptId": "00000000-0000-0000-0000-000000000052",
                    "candidateId": standardID.rawValue.uuidString,
                    "decision": OwnerTruthCandidateDecision.accepted.rawValue,
                    "candidateVersion": 2,
                    "correctedValueId": NSNull(),
                ]],
                "memoryActivation": [
                    "status": OwnerTruthMemoryActivationOutcome.notApplicable.rawValue,
                    "memoryVersionCreated": false,
                ],
            ],
            expectedCommand: command
        )
        XCTAssertEqual(accepted.receipts.map(\.candidateID), [standardID])
        XCTAssertFalse(accepted.memoryVersionCreated)
    }

    func testInterviewCandidateReviewRejectsMemoryVersionActivationClaim() throws {
        let reviewBatchID = recordID("00000000-0000-0000-0000-000000000053")
        let candidateID = recordID("00000000-0000-0000-0000-000000000054")
        let review = try OwnerTruthCandidateReviewCommand(
            commandID: "interview-single-reject-ios-001",
            expectedCandidateVersion: 1,
            action: .reject,
            reasonCode: "ownerReviewed"
        )
        let command = OwnerTruthInterviewCandidateSingleReviewCommand(
            reviewBatchID: reviewBatchID,
            candidateID: candidateID,
            review: review
        )

        XCTAssertThrowsError(
            try OwnerTruthInterviewCandidateSingleReviewResult(
                backendJSONObject: [
                    "schemaVersion": OwnerTruthInterviewCandidateSingleReviewResult.schemaVersion,
                    "status": OwnerTruthCommandOutcome.created.rawValue,
                    "batchDecisionId": "00000000-0000-0000-0000-000000000055",
                    "reviewBatchId": reviewBatchID.rawValue.uuidString,
                    "receipt": [
                        "receiptId": "00000000-0000-0000-0000-000000000056",
                        "candidateId": candidateID.rawValue.uuidString,
                        "decision": OwnerTruthCandidateDecision.rejected.rawValue,
                        "candidateVersion": 2,
                        "correctedValueId": NSNull(),
                    ],
                    "memoryActivation": [
                        "status": OwnerTruthMemoryActivationOutcome.notApplicable.rawValue,
                        "memoryVersionCreated": true,
                    ],
                ],
                expectedCommand: command
            )
        ) { error in
            XCTAssertEqual(
                error as? OwnerTruthRemoteContractError,
                .invalidInterviewCandidateDecision(
                    "interview review must not activate a MemoryVersion"
                )
            )
        }
    }

    func testInterviewCandidateReviewUseCaseKeepsBatchAndSingleReceiptsSeparated() throws {
        let (runtime, lease) = try makeActiveRuntime()
        let reviewBatchID = recordID("00000000-0000-0000-0000-000000000057")
        let batchCandidateID = recordID("00000000-0000-0000-0000-000000000058")
        let singleCandidateID = recordID("00000000-0000-0000-0000-000000000059")
        let client = InterviewCandidateReviewClientSpy()
        client.readResult = .success(try interviewCandidateReviewBatch(
            vaultID: lease.vaultId,
            reviewBatchID: reviewBatchID,
            batchCandidateID: batchCandidateID,
            singleCandidateID: singleCandidateID
        ))
        let useCase = OwnerTruthInterviewCandidateReviewUseCase(
            accountLease: lease,
            reviewBatchID: reviewBatchID,
            client: client,
            accountLeaseRuntime: runtime,
            qaGateEnabled: { true },
            commandIDFactory: { "interview-review-command" }
        )

        useCase.send(.refresh)
        XCTAssertEqual(useCase.viewState.phase, .ready)
        XCTAssertEqual(useCase.viewState.batchItems.map(\.id), [batchCandidateID])
        XCTAssertEqual(useCase.viewState.singleItems.map(\.id), [singleCandidateID])

        client.batchResult = .success(try interviewBatchAcceptResult(
            reviewBatchID: reviewBatchID,
            candidateIDs: [batchCandidateID]
        ))
        useCase.send(.acceptBatch(candidateIDs: [batchCandidateID]))

        XCTAssertEqual(useCase.viewState.phase, .ready)
        XCTAssertTrue(useCase.viewState.batchItems.isEmpty)
        XCTAssertEqual(useCase.viewState.singleItems.map(\.id), [singleCandidateID])
        XCTAssertEqual(useCase.viewState.notice, .batchAccepted)
        XCTAssertEqual(useCase.viewState.latestReceipt?.candidateIDs, [batchCandidateID])
        XCTAssertFalse(useCase.viewState.latestReceipt?.memoryVersionCreated ?? true)
        XCTAssertEqual(client.requestedBatchCommand?.selections.map(\.candidateID), [batchCandidateID])

        client.singleResult = .success(try interviewSingleReviewResult(
            reviewBatchID: reviewBatchID,
            candidateID: singleCandidateID,
            decision: .rejected
        ))
        useCase.send(.rejectSingle(candidateID: singleCandidateID))

        XCTAssertEqual(useCase.viewState.phase, .empty)
        XCTAssertTrue(useCase.viewState.batchItems.isEmpty)
        XCTAssertTrue(useCase.viewState.singleItems.isEmpty)
        XCTAssertEqual(useCase.viewState.notice, .singleRejected)
        XCTAssertEqual(useCase.viewState.latestReceipt?.decisions, [.rejected])
        XCTAssertFalse(useCase.viewState.latestReceipt?.memoryVersionCreated ?? true)
        XCTAssertEqual(client.requestedSingleCommand?.candidateID, singleCandidateID)
        XCTAssertEqual(client.requestedSingleCommand?.review.action, .reject)
    }

    func testInterviewCandidateReviewUseCaseRejectsSingleCandidateFromBatchRoute() throws {
        let (runtime, lease) = try makeActiveRuntime()
        let reviewBatchID = recordID("00000000-0000-0000-0000-000000000060")
        let batchCandidateID = recordID("00000000-0000-0000-0000-000000000061")
        let singleCandidateID = recordID("00000000-0000-0000-0000-000000000062")
        let client = InterviewCandidateReviewClientSpy()
        client.readResult = .success(try interviewCandidateReviewBatch(
            vaultID: lease.vaultId,
            reviewBatchID: reviewBatchID,
            batchCandidateID: batchCandidateID,
            singleCandidateID: singleCandidateID
        ))
        let useCase = OwnerTruthInterviewCandidateReviewUseCase(
            accountLease: lease,
            reviewBatchID: reviewBatchID,
            client: client,
            accountLeaseRuntime: runtime,
            qaGateEnabled: { true }
        )

        useCase.send(.refresh)
        useCase.send(.acceptBatch(candidateIDs: [singleCandidateID]))

        XCTAssertEqual(useCase.viewState.phase, .failed)
        XCTAssertEqual(useCase.viewState.notice, .invalidSelection)
        XCTAssertNil(client.requestedBatchCommand)
        XCTAssertEqual(useCase.viewState.batchItems.map(\.id), [batchCandidateID])
        XCTAssertEqual(useCase.viewState.singleItems.map(\.id), [singleCandidateID])
    }

    func testInterviewCandidateReviewUseCaseDiscardsDeferredReadAfterAccountChange() throws {
        let (runtime, lease) = try makeActiveRuntime()
        let reviewBatchID = recordID("00000000-0000-0000-0000-000000000063")
        let client = InterviewCandidateReviewClientSpy()
        client.deferRead = true
        let useCase = OwnerTruthInterviewCandidateReviewUseCase(
            accountLease: lease,
            reviewBatchID: reviewBatchID,
            client: client,
            accountLeaseRuntime: runtime,
            qaGateEnabled: { true }
        )

        useCase.send(.refresh)
        runtime.publish(session: accountSession(
            subjectId: "owner-b",
            vaultId: "vault-b",
            generation: 2,
            generationID: UUID(uuidString: "00000000-0000-0000-0000-000000000102")!
        ))
        client.completeDeferredRead(.success(try interviewCandidateReviewBatch(
            vaultID: lease.vaultId,
            reviewBatchID: reviewBatchID,
            batchCandidateID: recordID("00000000-0000-0000-0000-000000000064"),
            singleCandidateID: recordID("00000000-0000-0000-0000-000000000065")
        )))

        XCTAssertEqual(useCase.viewState.phase, .unavailable)
        XCTAssertEqual(useCase.viewState.notice, .staleAccountLease)
        XCTAssertTrue(useCase.viewState.batchItems.isEmpty)
        XCTAssertTrue(useCase.viewState.singleItems.isEmpty)
    }

    func testInterviewCandidateConfirmationDecodesDedicatedPolicyEnvelope() throws {
        let (_, lease) = try makeActiveRuntime()
        let reviewBatchID = recordID("00000000-0000-0000-0000-000000000068")
        let batchCandidateID = recordID("00000000-0000-0000-0000-000000000069")
        let singleCandidateID = recordID("00000000-0000-0000-0000-000000000070")

        let confirmation = try interviewCandidateConfirmation(
            vaultID: lease.vaultId,
            reviewBatchID: reviewBatchID,
            batchCandidateID: batchCandidateID,
            singleCandidateID: singleCandidateID
        )

        XCTAssertEqual(confirmation.vaultID.rawValue, lease.vaultId)
        XCTAssertEqual(confirmation.reviewBatchID, reviewBatchID)
        XCTAssertEqual(confirmation.readiness, .reviewReady)
        XCTAssertEqual(confirmation.batchCandidates.map(\.id), [batchCandidateID])
        XCTAssertEqual(confirmation.singleCandidates.map(\.id), [singleCandidateID])
    }

    func testInterviewCandidateConfirmationUseCaseFailsClosedWithoutReleasePolicy() throws {
        let (runtime, lease) = try makeActiveRuntime()
        let client = InterviewCandidateConfirmationClientSpy()
        let useCase = OwnerTruthInterviewCandidateConfirmationUseCase(
            accountLease: lease,
            reviewBatchID: recordID("00000000-0000-0000-0000-000000000073"),
            client: client,
            accountLeaseRuntime: runtime,
            releasePolicyAvailable: { false }
        )

        useCase.send(.refresh)

        XCTAssertEqual(useCase.viewState.phase, .unavailable)
        XCTAssertEqual(useCase.viewState.notice, .releasePolicyDisabled)
        XCTAssertEqual(client.requestCount, 0)
    }

    func testInterviewCandidateConfirmationUseCaseDiscardsDeferredReadAfterAccountChange() throws {
        let (runtime, lease) = try makeActiveRuntime()
        let reviewBatchID = recordID("00000000-0000-0000-0000-000000000074")
        let client = InterviewCandidateConfirmationClientSpy()
        client.deferRead = true
        let useCase = OwnerTruthInterviewCandidateConfirmationUseCase(
            accountLease: lease,
            reviewBatchID: reviewBatchID,
            client: client,
            accountLeaseRuntime: runtime,
            releasePolicyAvailable: { true }
        )

        useCase.send(.refresh)
        runtime.publish(session: accountSession(
            subjectId: "owner-b",
            vaultId: "vault-b",
            generation: 2,
            generationID: UUID(uuidString: "00000000-0000-0000-0000-000000000102")!
        ))
        client.completeDeferredRead(.success(try interviewCandidateConfirmation(
            vaultID: lease.vaultId,
            reviewBatchID: reviewBatchID,
            batchCandidateID: recordID("00000000-0000-0000-0000-000000000075"),
            singleCandidateID: recordID("00000000-0000-0000-0000-000000000076")
        )))

        XCTAssertEqual(useCase.viewState.phase, .unavailable)
        XCTAssertEqual(useCase.viewState.notice, .staleAccountLease)
        XCTAssertNil(useCase.viewState.confirmation)
    }

    func testInterviewCandidateConfirmationActionDecodesValueMinimizedResult() throws {
        let reviewBatchID = recordID("00000000-0000-0000-0000-000000000077")
        let candidateID = recordID("00000000-0000-0000-0000-000000000078")
        let command = try OwnerTruthInterviewCandidateConfirmationBatchCommand(
            commandID: "confirmation-action-ios-001",
            reviewBatchID: reviewBatchID,
            selections: [
                try OwnerTruthInterviewCandidateBatchSelection(
                    candidateID: candidateID,
                    expectedCandidateVersion: 1
                )
            ]
        )
        let result = try OwnerTruthInterviewCandidateConfirmationBatchResult(
            backendJSONObject: [
                "schemaVersion": OwnerTruthInterviewCandidateConfirmationBatchResult.schemaVersion,
                "status": OwnerTruthCommandOutcome.created.rawValue,
                "batchDecisionId": "00000000-0000-0000-0000-000000000079",
                "reviewBatchId": reviewBatchID.rawValue.uuidString,
                "acceptedCandidateCount": 1,
                "acceptedCandidateIds": [candidateID.rawValue.uuidString],
                "memoryActivation": [
                    "status": OwnerTruthMemoryActivationOutcome.notApplicable.rawValue,
                    "memoryVersionCreated": false,
                ],
            ],
            expectedCommand: command
        )

        XCTAssertEqual(result.acceptedCandidateIDs, [candidateID])
        XCTAssertFalse(result.memoryVersionCreated)
        XCTAssertThrowsError(
            try OwnerTruthInterviewCandidateConfirmationBatchResult(
                backendJSONObject: [
                    "schemaVersion": OwnerTruthInterviewCandidateConfirmationBatchResult.schemaVersion,
                    "status": OwnerTruthCommandOutcome.created.rawValue,
                    "batchDecisionId": "00000000-0000-0000-0000-000000000079",
                    "reviewBatchId": reviewBatchID.rawValue.uuidString,
                    "acceptedCandidateCount": 1,
                    "acceptedCandidateIds": [candidateID.rawValue.uuidString],
                    "receipts": [],
                    "memoryActivation": [
                        "status": OwnerTruthMemoryActivationOutcome.notApplicable.rawValue,
                        "memoryVersionCreated": false,
                    ],
                ],
                expectedCommand: command
            )
        )
    }

    func testInterviewCandidateConfirmationActionUseCaseFailsClosedAndRejectsSingleCandidate() throws {
        let (runtime, lease) = try makeActiveRuntime()
        let reviewBatchID = recordID("00000000-0000-0000-0000-000000000080")
        let batchCandidateID = recordID("00000000-0000-0000-0000-000000000081")
        let singleCandidateID = recordID("00000000-0000-0000-0000-000000000082")
        let confirmation = try interviewCandidateConfirmation(
            vaultID: lease.vaultId,
            reviewBatchID: reviewBatchID,
            batchCandidateID: batchCandidateID,
            singleCandidateID: singleCandidateID
        )
        let client = InterviewCandidateConfirmationActionClientSpy()
        let reader = InterviewCandidateConfirmationClientSpy()
        let disabled = OwnerTruthInterviewCandidateConfirmationActionUseCase(
            accountLease: lease,
            confirmation: confirmation,
            client: client,
            confirmationReader: reader,
            accountLeaseRuntime: runtime,
            releasePolicyAvailable: { false }
        )

        disabled.send(.confirmBatch(candidateIDs: [batchCandidateID]))

        XCTAssertEqual(disabled.viewState.phase, .unavailable)
        XCTAssertEqual(disabled.viewState.notice, .releasePolicyDisabled)
        XCTAssertTrue(client.requestedCommands.isEmpty)

        let enabled = OwnerTruthInterviewCandidateConfirmationActionUseCase(
            accountLease: lease,
            confirmation: confirmation,
            client: client,
            confirmationReader: reader,
            accountLeaseRuntime: runtime,
            releasePolicyAvailable: { true }
        )
        enabled.send(.confirmBatch(candidateIDs: [singleCandidateID]))

        XCTAssertEqual(enabled.viewState.phase, .failed)
        XCTAssertEqual(enabled.viewState.notice, .invalidSelection)
        XCTAssertTrue(client.requestedCommands.isEmpty)
    }

    func testInterviewCandidateConfirmationActionUseCaseRetriesWithSameCommandID() throws {
        let (runtime, lease) = try makeActiveRuntime()
        let reviewBatchID = recordID("00000000-0000-0000-0000-000000000083")
        let batchCandidateID = recordID("00000000-0000-0000-0000-000000000084")
        let singleCandidateID = recordID("00000000-0000-0000-0000-000000000085")
        let confirmation = try interviewCandidateConfirmation(
            vaultID: lease.vaultId,
            reviewBatchID: reviewBatchID,
            batchCandidateID: batchCandidateID,
            singleCandidateID: singleCandidateID
        )
        let client = InterviewCandidateConfirmationActionClientSpy()
        let reader = InterviewCandidateConfirmationClientSpy()
        client.result = .failure(InterviewCandidateConfirmationActionClientSpyError.missingActionResult)
        let useCase = OwnerTruthInterviewCandidateConfirmationActionUseCase(
            accountLease: lease,
            confirmation: confirmation,
            client: client,
            confirmationReader: reader,
            accountLeaseRuntime: runtime,
            releasePolicyAvailable: { true },
            commandIDFactory: { "stable-confirmation-command" }
        )

        useCase.send(.confirmBatch(candidateIDs: [batchCandidateID]))
        XCTAssertEqual(useCase.viewState.phase, .failed)

        client.result = .success(try interviewCandidateConfirmationActionResult(
            reviewBatchID: reviewBatchID,
            candidateIDs: [batchCandidateID],
            commandID: "stable-confirmation-command"
        ))
        reader.readResult = .success(try reconciledInterviewCandidateConfirmation(
            vaultID: lease.vaultId,
            reviewBatchID: reviewBatchID,
            remainingSingleCandidateID: singleCandidateID
        ))
        useCase.send(.confirmBatch(candidateIDs: [batchCandidateID]))

        XCTAssertEqual(client.requestedCommands.map(\.commandID), [
            "stable-confirmation-command",
            "stable-confirmation-command",
        ])
        XCTAssertEqual(useCase.viewState.phase, .confirmed)
        XCTAssertEqual(useCase.viewState.notice, .batchConfirmed)
        XCTAssertEqual(useCase.viewState.latestResult?.acceptedCandidateIDs, [batchCandidateID])
    }

    func testInterviewCandidateConfirmationActionUseCaseDiscardsDeferredResultAfterAccountChange() throws {
        let (runtime, lease) = try makeActiveRuntime()
        let reviewBatchID = recordID("00000000-0000-0000-0000-000000000086")
        let batchCandidateID = recordID("00000000-0000-0000-0000-000000000087")
        let singleCandidateID = recordID("00000000-0000-0000-0000-000000000088")
        let confirmation = try interviewCandidateConfirmation(
            vaultID: lease.vaultId,
            reviewBatchID: reviewBatchID,
            batchCandidateID: batchCandidateID,
            singleCandidateID: singleCandidateID
        )
        let client = InterviewCandidateConfirmationActionClientSpy()
        let reader = InterviewCandidateConfirmationClientSpy()
        client.deferResult = true
        let useCase = OwnerTruthInterviewCandidateConfirmationActionUseCase(
            accountLease: lease,
            confirmation: confirmation,
            client: client,
            confirmationReader: reader,
            accountLeaseRuntime: runtime,
            releasePolicyAvailable: { true }
        )

        useCase.send(.confirmBatch(candidateIDs: [batchCandidateID]))
        runtime.publish(session: accountSession(
            subjectId: "owner-b",
            vaultId: "vault-b",
            generation: 2,
            generationID: UUID(uuidString: "00000000-0000-0000-0000-000000000102")!
        ))
        client.completeDeferredResult(.success(try interviewCandidateConfirmationActionResult(
            reviewBatchID: reviewBatchID,
            candidateIDs: [batchCandidateID],
            commandID: try XCTUnwrap(client.requestedCommands.first?.commandID)
        )))

        XCTAssertEqual(useCase.viewState.phase, .unavailable)
        XCTAssertEqual(useCase.viewState.notice, .staleAccountLease)
        XCTAssertNil(useCase.viewState.latestResult)
    }

    func testInterviewCandidateConfirmationActionUseCaseRequiresProjectionReconciliation() throws {
        let (runtime, lease) = try makeActiveRuntime()
        let reviewBatchID = recordID("00000000-0000-0000-0000-000000000090")
        let batchCandidateID = recordID("00000000-0000-0000-0000-000000000091")
        let singleCandidateID = recordID("00000000-0000-0000-0000-000000000092")
        let confirmation = try interviewCandidateConfirmation(
            vaultID: lease.vaultId,
            reviewBatchID: reviewBatchID,
            batchCandidateID: batchCandidateID,
            singleCandidateID: singleCandidateID
        )
        let client = InterviewCandidateConfirmationActionClientSpy()
        client.result = .success(try interviewCandidateConfirmationActionResult(
            reviewBatchID: reviewBatchID,
            candidateIDs: [batchCandidateID],
            commandID: "confirmation-reconciliation-command"
        ))
        let reader = InterviewCandidateConfirmationClientSpy()
        reader.readResult = .success(confirmation)
        let useCase = OwnerTruthInterviewCandidateConfirmationActionUseCase(
            accountLease: lease,
            confirmation: confirmation,
            client: client,
            confirmationReader: reader,
            accountLeaseRuntime: runtime,
            releasePolicyAvailable: { true },
            commandIDFactory: { "confirmation-reconciliation-command" }
        )

        useCase.send(.confirmBatch(candidateIDs: [batchCandidateID]))

        XCTAssertEqual(reader.requestCount, 1)
        XCTAssertEqual(useCase.viewState.phase, .failed)
        XCTAssertEqual(useCase.viewState.notice, .reconciliationFailed)
        XCTAssertEqual(useCase.viewState.latestResult?.acceptedCandidateIDs, [batchCandidateID])
    }

    func testInterviewSessionStateDecodesValueMinimizedEnvelope() throws {
        let (_, lease) = try makeActiveRuntime()
        let state = try interviewSessionState(vaultID: lease.vaultId)

        XCTAssertEqual(state.vaultID.rawValue, lease.vaultId)
        XCTAssertEqual(state.lifecycle, .active)
        XCTAssertEqual(state.boundary, .open)
        XCTAssertEqual(state.rowVersion, 1)
        XCTAssertEqual(state.threadVersion, 2)
        XCTAssertEqual(state.ownerTurnCount, 3)
        XCTAssertEqual(state.deepeningTurnCount, 1)
        XCTAssertEqual(state.candidateBatchTurnCount, 0)
        XCTAssertEqual(state.fatigue, .normal)
        XCTAssertFalse(state.hasPendingReviewBatch)
        XCTAssertEqual(state.authorityEpoch, 4)
    }

    func testInterviewSessionStateUseCaseDiscardsDeferredReadAfterAccountChange() throws {
        let (runtime, lease) = try makeActiveRuntime()
        let client = InterviewSessionStateClientSpy()
        client.deferRead = true
        let useCase = OwnerTruthInterviewSessionStateUseCase(
            accountLease: lease,
            sessionID: recordID("00000000-0000-0000-0000-000000000066"),
            client: client,
            accountLeaseRuntime: runtime,
            qaGateEnabled: { true }
        )

        useCase.send(.refresh)
        runtime.publish(session: accountSession(
            subjectId: "owner-b",
            vaultId: "vault-b",
            generation: 2,
            generationID: UUID(uuidString: "00000000-0000-0000-0000-000000000102")!
        ))
        client.completeDeferredRead(.success(try interviewSessionState(vaultID: lease.vaultId)))

        XCTAssertEqual(useCase.viewState.phase, .unavailable)
        XCTAssertEqual(useCase.viewState.notice, .staleAccountLease)
        XCTAssertNil(useCase.viewState.session)
    }

    func testInterviewSessionStateUseCaseFailsClosedWhenQAGateIsDisabled() throws {
        let (runtime, lease) = try makeActiveRuntime()
        let client = InterviewSessionStateClientSpy()
        let useCase = OwnerTruthInterviewSessionStateUseCase(
            accountLease: lease,
            sessionID: recordID("00000000-0000-0000-0000-000000000067"),
            client: client,
            accountLeaseRuntime: runtime,
            qaGateEnabled: { false }
        )

        useCase.send(.refresh)

        XCTAssertEqual(useCase.viewState.phase, .unavailable)
        XCTAssertEqual(useCase.viewState.notice, .qaOnlyDisabled)
        XCTAssertEqual(client.requestCount, 0)
    }

    func testInterviewNaturalInputReceiptDecodesOnlyValueMinimizedMetadata() throws {
        let (_, lease) = try makeActiveRuntime()
        let vaultID = try XCTUnwrap(OwnerTruthVaultID(lease.vaultId))
        let start = try OwnerTruthInterviewNaturalInputStartCommand(
            commandID: "natural-input-start",
            threadID: recordID("00000000-0000-0000-0000-000000000071"),
            sessionID: recordID("00000000-0000-0000-0000-000000000072")
        )
        let append = try OwnerTruthInterviewNaturalInputAppendCommand(
            commandID: "natural-input-append",
            threadID: start.threadID,
            sessionID: start.sessionID,
            messageID: recordID("00000000-0000-0000-0000-000000000073"),
            expectedThreadVersion: 1,
            expectedSessionVersion: 1,
            text: "只应通过命令传输，不应出现在回执。"
        )

        let receipt = try interviewNaturalInputReceipt(vaultID: vaultID, append: append)

        XCTAssertEqual(receipt.vaultID, vaultID)
        XCTAssertEqual(receipt.outcome, .created)
        XCTAssertEqual(receipt.threadID, start.threadID)
        XCTAssertEqual(receipt.sessionID, start.sessionID)
        XCTAssertEqual(receipt.messageID, append.messageID)
        XCTAssertEqual(receipt.messageSequence, 1)
        XCTAssertTrue(receipt.matches(append))
        XCTAssertFalse(String(describing: receipt).contains(append.text))
    }

    func testInterviewNaturalInputUseCaseStartsAndAppendsWithoutRetainingText() throws {
        let (runtime, lease) = try makeActiveRuntime()
        let vaultID = try XCTUnwrap(OwnerTruthVaultID(lease.vaultId))
        let client = InterviewNaturalInputClientSpy()
        client.startHandler = { command in
            Result { try self.interviewNaturalInputReceipt(vaultID: vaultID, start: command) }
        }
        client.appendHandler = { command in
            Result { try self.interviewNaturalInputReceipt(vaultID: vaultID, append: command) }
        }
        let useCase = OwnerTruthInterviewNaturalInputUseCase(
            accountLease: lease,
            client: client,
            accountLeaseRuntime: runtime,
            qaGateEnabled: { true }
        )

        useCase.send(.start)
        XCTAssertEqual(useCase.viewState.phase, .ready)
        XCTAssertEqual(useCase.viewState.latestReceipt?.messageSequence, nil)
        XCTAssertNotNil(client.startCommand)

        let text = "小时候下雨天，我会在院子里听家人讲故事。"
        useCase.send(.submit(text: text))

        XCTAssertEqual(useCase.viewState.phase, .ready)
        XCTAssertEqual(useCase.viewState.latestReceipt?.messageSequence, 1)
        XCTAssertEqual(client.appendCommand?.text, text)
        XCTAssertFalse(String(describing: useCase.viewState).contains(text))
    }

    func testInterviewNaturalInputUseCaseDiscardsDeferredAppendAfterAccountChange() throws {
        let (runtime, lease) = try makeActiveRuntime()
        let vaultID = try XCTUnwrap(OwnerTruthVaultID(lease.vaultId))
        let client = InterviewNaturalInputClientSpy()
        client.startHandler = { command in
            Result { try self.interviewNaturalInputReceipt(vaultID: vaultID, start: command) }
        }
        client.deferAppend = true
        let useCase = OwnerTruthInterviewNaturalInputUseCase(
            accountLease: lease,
            client: client,
            accountLeaseRuntime: runtime,
            qaGateEnabled: { true }
        )

        useCase.send(.start)
        useCase.send(.submit(text: "这条输入不能跨账号提交。"))
        runtime.publish(session: accountSession(
            subjectId: "owner-b",
            vaultId: "vault-b",
            generation: 2,
            generationID: UUID(uuidString: "00000000-0000-0000-0000-000000000102")!
        ))
        let command = try XCTUnwrap(client.appendCommand)
        client.completeDeferredAppend(.success(try interviewNaturalInputReceipt(
            vaultID: vaultID,
            append: command
        )))

        XCTAssertEqual(useCase.viewState.phase, .unavailable)
        XCTAssertEqual(useCase.viewState.notice, .staleAccountLease)
        XCTAssertNil(useCase.viewState.latestReceipt)
    }

    func testInterviewNaturalInputUseCaseFailsClosedWhenQAGateIsDisabled() throws {
        let (runtime, lease) = try makeActiveRuntime()
        let client = InterviewNaturalInputClientSpy()
        let useCase = OwnerTruthInterviewNaturalInputUseCase(
            accountLease: lease,
            client: client,
            accountLeaseRuntime: runtime,
            qaGateEnabled: { false }
        )

        useCase.send(.start)

        XCTAssertEqual(useCase.viewState.phase, .unavailable)
        XCTAssertEqual(useCase.viewState.notice, .qaOnlyDisabled)
        XCTAssertNil(client.startCommand)
    }

    func testKBLiteCompatibilityReadEnvelopeAcceptsOnlyConfirmedProjectionFacts() throws {
        let (_, lease) = try makeActiveRuntime()
        let envelope = try compatibilityReadEnvelope(for: lease)

        XCTAssertEqual(envelope.state, .ready)
        XCTAssertEqual(envelope.cacheDisposition, .replace)
        XCTAssertEqual(envelope.vaultID.rawValue, lease.vaultId)
        XCTAssertEqual(envelope.ownerSubjectID, lease.subjectId)
        XCTAssertEqual(envelope.graph.facts.count, 1)
        XCTAssertEqual(envelope.graph.facts.first?.statement, "院子里有一棵树")
        XCTAssertEqual(
            try OwnerTruthKBLiteCompatibilityReadEnvelope.graphContentHash(envelope.graph),
            envelope.contentHash
        )
    }

    func testKBLiteCompatibilityReadEnvelopeRejectsTamperedContentHash() throws {
        let (_, lease) = try makeActiveRuntime()
        var object = try compatibilityReadEnvelopeJSONObject(for: lease)
        object["contentHash"] = String(repeating: "0", count: 64)

        XCTAssertThrowsError(
            try OwnerTruthKBLiteCompatibilityReadEnvelope(
                backendJSONObject: object,
                expectedVaultID: try XCTUnwrap(OwnerTruthVaultID(lease.vaultId)),
                expectedOwnerSubjectID: lease.subjectId
            )
        ) { error in
            XCTAssertEqual(
                error as? OwnerTruthRemoteContractError,
                .invalidKBLiteCompatibilityReadEnvelope(
                    "ready envelope integrity fields are invalid"
                )
            )
        }
    }

    func testKBLiteCompatibilityStoreFailsClosedAcrossAccountABA() throws {
        let (runtime, firstLease) = try makeActiveRuntime()
        let directoryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("owner-truth-kblite-aba-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directoryURL) }
        let store = OwnerTruthKBLiteCompatibilityStore(
            directoryURL: directoryURL,
            accountLeaseRuntime: runtime
        )
        let envelope = try compatibilityReadEnvelope(for: firstLease)

        guard case .ready(let written) = store.apply(envelope, for: firstLease) else {
            return XCTFail("expected a valid first compatibility projection")
        }
        XCTAssertEqual(written.graph.facts.count, 1)

        runtime.publish(session: accountSession(
            subjectId: "owner-b",
            vaultId: "vault-b",
            generation: 2,
            generationID: UUID(uuidString: "00000000-0000-0000-0000-000000000202")!
        ))
        XCTAssertEqual(store.load(for: firstLease), .unavailable)
        XCTAssertFalse(
            FileManager.default.fileExists(
                atPath: directoryURL
                    .appendingPathComponent(OwnerTruthKBLiteCompatibilityStore.fileName)
                    .path
            )
        )

        runtime.publish(session: accountSession(
            subjectId: "owner-a",
            vaultId: "vault-a",
            generation: 1,
            generationID: UUID(uuidString: "00000000-0000-0000-0000-000000000101")!,
            sessionID: "session-owner-a-relogged"
        ))
        let recoveredLease = try XCTUnwrap(runtime.capture(forSubjectId: "owner-a"))
        XCTAssertNotEqual(recoveredLease.sessionId, firstLease.sessionId)
        XCTAssertEqual(store.load(for: recoveredLease), .rebuilding)
    }

    func testKBLiteCompatibilityStoreDiscardsNonReadyAndCorruptCaches() throws {
        let (runtime, lease) = try makeActiveRuntime()
        let directoryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("owner-truth-kblite-corruption-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directoryURL) }
        let store = OwnerTruthKBLiteCompatibilityStore(
            directoryURL: directoryURL,
            accountLeaseRuntime: runtime
        )
        let readyEnvelope = try compatibilityReadEnvelope(for: lease)
        guard case .ready = store.apply(readyEnvelope, for: lease) else {
            return XCTFail("expected a cacheable projection")
        }

        let cacheURL = directoryURL.appendingPathComponent(
            OwnerTruthKBLiteCompatibilityStore.fileName
        )
        try Data("not-json".utf8).write(to: cacheURL, options: .atomic)
        XCTAssertEqual(store.load(for: lease), .rebuilding)
        XCTAssertFalse(FileManager.default.fileExists(atPath: cacheURL.path))

        let nonReadyEnvelope = try OwnerTruthKBLiteCompatibilityReadEnvelope(
            backendJSONObject: [
                "schemaVersion": OwnerTruthKBLiteCompatibilityReadEnvelope.schemaVersion,
                "projectionSource": OwnerTruthKBLiteCompatibilityReadEnvelope.projectionSource,
                "compatibilitySource": OwnerTruthKBLiteCompatibilityReadEnvelope.compatibilitySource,
                "state": "rebuilding",
                "vaultId": lease.vaultId,
                "ownerSubjectId": lease.subjectId,
                "authorityEpoch": 2,
                "projectionCheckpoint": NSNull(),
                "cacheDisposition": "discard",
                "contentHash": NSNull(),
                "graph": ["people": [], "places": [], "events": [], "facts": []],
                "filteredEntries": [],
            ],
            expectedVaultID: try XCTUnwrap(OwnerTruthVaultID(lease.vaultId)),
            expectedOwnerSubjectID: lease.subjectId
        )
        XCTAssertEqual(store.apply(nonReadyEnvelope, for: lease), .rebuilding)
        XCTAssertFalse(FileManager.default.fileExists(atPath: cacheURL.path))
    }

    func testContextShadowBuildAcceptsTypedProjectionCitationsWithoutRawContent() throws {
        let (_, lease) = try makeActiveRuntime()
        let query = "只允许已确认记忆参与本轮回响"
        let build = try OwnerTruthContextShadowBuild(
            backendJSONObject: try contextShadowBuildResponse(for: lease, query: query),
            expectedVaultID: try XCTUnwrap(OwnerTruthVaultID(lease.vaultId)),
            expectedIntent: "echo_chat",
            expectedQuery: query
        )

        XCTAssertEqual(build.contextVersion, "echo-context-v4-shadow")
        XCTAssertTrue(build.shadowOnly)
        XCTAssertTrue(build.legacyContextUnchanged)
        XCTAssertFalse(build.legacyContextRead)
        XCTAssertEqual(build.selectedContext.count, 1)
        XCTAssertEqual(build.filteredContext.count, 1)
        XCTAssertEqual(build.rankingTrace.count, 1)
        XCTAssertEqual(build.citationProof.count, 1)
        XCTAssertEqual(build.selectedContext[0].citation.sourceID, build.selectedContext[0].sourceReference.sourceID)
        XCTAssertEqual(build.filteredContext[0].reason, "sensitivity_not_context_eligible")

        let trace = build.traceSummary()
        XCTAssertEqual(trace.selectedContextCount, 1)
        XCTAssertEqual(trace.filteredContextCount, 1)
        XCTAssertEqual(trace.citationCount, 1)
        XCTAssertEqual(trace.selectedContextRefsBySource["owner-truth-memory-projection"], [
            "memory-version:00000000-0000-0000-0000-000000000302",
        ])
        let encoded = try JSONEncoder().encode(trace)
        XCTAssertFalse(String(decoding: encoded, as: UTF8.self).contains(query))
    }

    func testContextShadowBuildAcceptsJSONRoundTripNumberValues() throws {
        let (_, lease) = try makeActiveRuntime()
        let query = "网络 JSON 的数字字段必须能稳定解析"
        let original = try contextShadowBuildResponse(for: lease, query: query)
        let data = try JSONSerialization.data(withJSONObject: original)
        let response = try XCTUnwrap(
            JSONSerialization.jsonObject(with: data) as? [String: Any]
        )

        let build = try OwnerTruthContextShadowBuild(
            backendJSONObject: response,
            expectedVaultID: try XCTUnwrap(OwnerTruthVaultID(lease.vaultId)),
            expectedIntent: "echo_chat",
            expectedQuery: query
        )

        XCTAssertEqual(
            build.selectedContextSourceCounts,
            ["owner-truth-memory-projection": 1]
        )
    }

    func testContextShadowBuildRejectsBooleanAndFractionalJSONNumbers() throws {
        let (_, lease) = try makeActiveRuntime()
        let query = "数字字段不能接受布尔或小数"
        let expectedVaultID = try XCTUnwrap(OwnerTruthVaultID(lease.vaultId))

        for invalidSourceVersion: Any in [true, 1.5] {
            var response = try contextShadowBuildResponse(for: lease, query: query)
            var shadow = try XCTUnwrap(response["contextShadow"] as? [String: Any])
            var selected = try XCTUnwrap(shadow["selectedContext"] as? [[String: Any]])
            var sourceRef = try XCTUnwrap(selected[0]["sourceRef"] as? [String: Any])
            sourceRef["sourceVersion"] = invalidSourceVersion
            selected[0]["sourceRef"] = sourceRef
            shadow["selectedContext"] = selected
            response["contextShadow"] = shadow

            let data = try JSONSerialization.data(withJSONObject: response)
            let jsonResponse = try XCTUnwrap(
                JSONSerialization.jsonObject(with: data) as? [String: Any]
            )
            XCTAssertThrowsError(
                try OwnerTruthContextShadowBuild(
                    backendJSONObject: jsonResponse,
                    expectedVaultID: expectedVaultID,
                    expectedIntent: "echo_chat",
                    expectedQuery: query
                ),
                "invalid numeric value: \(invalidSourceVersion)"
            )
        }
    }

    func testContextShadowBuildRejectsRawMemoryValueAndCrossVaultCitation() throws {
        let (_, lease) = try makeActiveRuntime()
        let query = "原文必须不进入 QA evidence"
        let expectedVaultID = try XCTUnwrap(OwnerTruthVaultID(lease.vaultId))
        var response = try contextShadowBuildResponse(for: lease, query: query)
        var shadow = try XCTUnwrap(response["contextShadow"] as? [String: Any])
        var selected = try XCTUnwrap(shadow["selectedContext"] as? [[String: Any]])
        selected[0]["content"] = "不得导出的记忆正文"
        shadow["selectedContext"] = selected
        response["contextShadow"] = shadow

        XCTAssertThrowsError(
            try OwnerTruthContextShadowBuild(
                backendJSONObject: response,
                expectedVaultID: expectedVaultID,
                expectedIntent: "echo_chat",
                expectedQuery: query
            )
        ) { error in
            guard case .invalidContextCitationShadowBuild = error as? OwnerTruthRemoteContractError else {
                return XCTFail("expected raw context contract rejection, got \(error)")
            }
        }

        response = try contextShadowBuildResponse(for: lease, query: query)
        shadow = try XCTUnwrap(response["contextShadow"] as? [String: Any])
        selected = try XCTUnwrap(shadow["selectedContext"] as? [[String: Any]])
        var sourceRef = try XCTUnwrap(selected[0]["sourceRef"] as? [String: Any])
        sourceRef["vaultId"] = "vault-other"
        selected[0]["sourceRef"] = sourceRef
        shadow["selectedContext"] = selected
        response["contextShadow"] = shadow

        XCTAssertThrowsError(
            try OwnerTruthContextShadowBuild(
                backendJSONObject: response,
                expectedVaultID: expectedVaultID,
                expectedIntent: "echo_chat",
                expectedQuery: query
            )
        ) { error in
            guard case .invalidContextCitationShadowBuild = error as? OwnerTruthRemoteContractError else {
                return XCTFail("expected cross-vault context contract rejection, got \(error)")
            }
        }
    }

    func testAnswerCitationReceiptBindsExactContextWithoutStoringAnswerText() throws {
        let (_, lease) = try makeActiveRuntime()
        let query = "请只依据已确认记忆回答"
        let answer = "我会基于已确认的记忆继续陪您回顾。"
        let commandID = "owner-truth-answer-citation-ios-001"
        let build = try OwnerTruthContextShadowBuild(
            backendJSONObject: try contextShadowBuildResponse(for: lease, query: query),
            expectedVaultID: try XCTUnwrap(OwnerTruthVaultID(lease.vaultId)),
            expectedIntent: "echo_chat",
            expectedQuery: query
        )
        let receipt = try OwnerTruthAnswerCitationReceipt(
            backendJSONObject: answerCitationReceiptResponse(
                for: build,
                commandID: commandID,
                query: query,
                answer: answer
            ),
            expectedContext: build,
            expectedCommandID: commandID,
            expectedQuery: query,
            expectedAnswerText: answer
        )

        XCTAssertEqual(receipt.outcome, .created)
        XCTAssertEqual(receipt.contextHash, build.contextHash)
        XCTAssertEqual(receipt.citations.count, build.selectedContext.count)
        XCTAssertEqual(receipt.citations[0].citation, build.selectedContext[0].citation)
        XCTAssertEqual(receipt.citations[0].resolution, "current_confirmed_projection_entry")

        let trace = build.traceSummary(receipt: receipt)
        XCTAssertEqual(trace.answerCitationCount, 1)
        XCTAssertEqual(trace.contextHash, build.contextHash)
        let encoded = try JSONEncoder().encode(trace)
        let text = String(decoding: encoded, as: UTF8.self)
        XCTAssertFalse(text.contains(query))
        XCTAssertFalse(text.contains(answer))
    }

    func testCorrectionRequestCommandBindsVerifiedCitationAndReceiptIsValueFree() throws {
        let (_, lease) = try makeActiveRuntime()
        let query = "请只依据已确认记忆回答"
        let answer = "我会基于已确认的记忆继续陪您回顾。"
        let correctionText = "不是父亲，是外祖父在院子里讲故事。"
        let answerReceipt = try verifiedAnswerCitationReceipt(
            for: lease,
            query: query,
            answer: answer,
            commandID: "owner-truth-answer-citation-correction-001"
        )
        let citation = try XCTUnwrap(answerReceipt.citations.first)
        let command = try OwnerTruthCorrectionRequestCommand(
            commandID: "owner-truth-correction-request-001",
            receipt: answerReceipt,
            citationID: citation.citationID,
            correctionText: correctionText,
            reasonCode: "ownerReportedCorrection"
        )

        XCTAssertEqual(command.answerID, answerReceipt.answerID)
        XCTAssertEqual(command.citationID, citation.citationID)
        XCTAssertEqual(command.memoryID, citation.citation.memoryID)
        XCTAssertEqual(command.expectedMemoryVersionID, citation.citation.memoryVersionID)
        XCTAssertEqual(command.backendJSONObject["commandId"] as? String, command.commandID)
        XCTAssertEqual(
            command.backendJSONObject["answerId"] as? String,
            answerReceipt.answerID.rawValue.uuidString.lowercased()
        )
        XCTAssertEqual(command.backendJSONObject["correctionText"] as? String, correctionText)

        let receipt = try OwnerTruthCorrectionRequestReceipt(
            backendJSONObject: correctionRequestReceiptResponse(for: command),
            expectedCommand: command
        )

        XCTAssertEqual(receipt.outcome, .created)
        XCTAssertEqual(receipt.status, .pendingReview)
        XCTAssertEqual(receipt.answerID, command.answerID)
        XCTAssertEqual(receipt.citationID, command.citationID)
        XCTAssertEqual(receipt.memoryID, command.memoryID)
        XCTAssertEqual(receipt.expectedMemoryVersionID, command.expectedMemoryVersionID)
        XCTAssertEqual(receipt.correctionTextHash, command.correctionTextHash)
        XCTAssertEqual(receipt.correctionTextLength, command.correctionTextLength)

        let encoded = try JSONEncoder().encode(receipt)
        let text = String(decoding: encoded, as: UTF8.self)
        XCTAssertFalse(text.contains(correctionText))
        XCTAssertFalse(text.contains(answer))
        XCTAssertFalse(text.contains(query))
    }

    func testCorrectionRequestReceiptRejectsRawCorrectionAnswerAndContent() throws {
        let (_, lease) = try makeActiveRuntime()
        let query = "纠错回执不得回显问题"
        let answer = "纠错回执也不得回显回答。"
        let correctionText = "正确人物应为外祖父。"
        let answerReceipt = try verifiedAnswerCitationReceipt(
            for: lease,
            query: query,
            answer: answer,
            commandID: "owner-truth-answer-citation-correction-raw"
        )
        let command = try OwnerTruthCorrectionRequestCommand(
            commandID: "owner-truth-correction-request-raw",
            receipt: answerReceipt,
            citationID: try XCTUnwrap(answerReceipt.citations.first).citationID,
            correctionText: correctionText,
            reasonCode: "ownerReportedCorrection"
        )

        let prohibitedValues: [(String, Any)] = [
            ("correctionText", correctionText),
            ("answerText", answer),
            ("content", ["summary": "不得出现在纠错回执里的档案正文"]),
        ]
        for (field, value) in prohibitedValues {
            var response = correctionRequestReceiptResponse(for: command)
            var request = try XCTUnwrap(response["correctionRequest"] as? [String: Any])
            request[field] = value
            response["correctionRequest"] = request

            XCTAssertThrowsError(
                try OwnerTruthCorrectionRequestReceipt(
                    backendJSONObject: response,
                    expectedCommand: command
                ),
                "raw field \(field) must be rejected"
            ) { error in
                guard case .invalidCorrectionRequestReceipt = error as? OwnerTruthRemoteContractError else {
                    return XCTFail("expected raw correction receipt rejection, got \(error)")
                }
            }
        }
    }

    func testCorrectionRequestReceiptRejectsMismatchedIdentityAndIntegrity() throws {
        let (_, lease) = try makeActiveRuntime()
        let answerReceipt = try verifiedAnswerCitationReceipt(
            for: lease,
            query: "纠错回执必须绑定原回答",
            answer: "每个纠错请求只对应一个已验证引用。",
            commandID: "owner-truth-answer-citation-correction-binding"
        )
        let command = try OwnerTruthCorrectionRequestCommand(
            commandID: "owner-truth-correction-request-binding",
            receipt: answerReceipt,
            citationID: try XCTUnwrap(answerReceipt.citations.first).citationID,
            correctionText: "被引用的记忆需要更正。",
            reasonCode: "ownerReportedCorrection"
        )
        let mismatches: [(String, Any)] = [
            ("citationId", "00000000-0000-0000-0000-000000000331"),
            ("memoryId", "00000000-0000-0000-0000-000000000332"),
            ("expectedMemoryVersionId", "00000000-0000-0000-0000-000000000333"),
            ("correctionTextHash", digest("another-correction")),
            ("correctionTextLength", command.correctionTextLength + 1),
        ]
        for (field, value) in mismatches {
            var response = correctionRequestReceiptResponse(for: command)
            var request = try XCTUnwrap(response["correctionRequest"] as? [String: Any])
            request[field] = value
            response["correctionRequest"] = request

            XCTAssertThrowsError(
                try OwnerTruthCorrectionRequestReceipt(
                    backendJSONObject: response,
                    expectedCommand: command
                ),
                "mismatched \(field) must be rejected"
            ) { error in
                guard case .invalidCorrectionRequestReceipt = error as? OwnerTruthRemoteContractError else {
                    return XCTFail("expected correction identity rejection, got \(error)")
                }
            }
        }
    }

    func testCorrectionRequestCommandRejectsInvalidInputAndUnknownCitation() throws {
        let (_, lease) = try makeActiveRuntime()
        let answerReceipt = try verifiedAnswerCitationReceipt(
            for: lease,
            query: "只允许已验证引用发起纠错",
            answer: "纠错请求必须锁定一条已有引用。",
            commandID: "owner-truth-answer-citation-correction-invalid"
        )
        let citationID = try XCTUnwrap(answerReceipt.citations.first).citationID

        let invalidCommands: [(String, String, String)] = [
            (" ", "ownerReportedCorrection", "需要更正"),
            ("1-invalid-command", "ownerReportedCorrection", "需要更正"),
            ("owner-truth-correction-request-invalid", "reason code", "需要更正"),
            ("owner-truth-correction-request-invalid", "ownerReportedCorrection", " \n "),
        ]
        for (commandID, reasonCode, correctionText) in invalidCommands {
            XCTAssertThrowsError(
                try OwnerTruthCorrectionRequestCommand(
                    commandID: commandID,
                    receipt: answerReceipt,
                    citationID: citationID,
                    correctionText: correctionText,
                    reasonCode: reasonCode
                ),
                "invalid correction input must fail closed"
            ) { error in
                guard case .invalidCorrectionRequestCommand = error as? OwnerTruthRemoteContractError else {
                    return XCTFail("expected invalid correction command, got \(error)")
                }
            }
        }

        XCTAssertThrowsError(
            try OwnerTruthCorrectionRequestCommand(
                commandID: "owner-truth-correction-request-unknown-citation",
                receipt: answerReceipt,
                citationID: recordID("00000000-0000-0000-0000-000000000339"),
                correctionText: "不能绑定未验证引用。",
                reasonCode: "ownerReportedCorrection"
            )
        ) { error in
            guard case .invalidCorrectionRequestCommand = error as? OwnerTruthRemoteContractError else {
                return XCTFail("expected unknown citation rejection, got \(error)")
            }
        }
    }

    func testContextCitationQAEvidenceReadoutHashesReferencesWithoutRawText() throws {
        let (_, lease) = try makeActiveRuntime()
        let query = "这段问题不能进入 QA 导出包"
        let answer = "这段回答也不能进入 QA 导出包"
        let reference = "memory-version:00000000-0000-0000-0000-000000000302"
        let build = try OwnerTruthContextShadowBuild(
            backendJSONObject: try contextShadowBuildResponse(for: lease, query: query),
            expectedVaultID: try XCTUnwrap(OwnerTruthVaultID(lease.vaultId)),
            expectedIntent: "echo_chat",
            expectedQuery: query
        )
        let receipt = try OwnerTruthAnswerCitationReceipt(
            backendJSONObject: answerCitationReceiptResponse(
                for: build,
                commandID: "owner-truth-answer-citation-ios-readout",
                query: query,
                answer: answer
            ),
            expectedContext: build,
            expectedCommandID: "owner-truth-answer-citation-ios-readout",
            expectedQuery: query,
            expectedAnswerText: answer
        )

        let readout = OwnerTruthContextCitationQAEvidenceReadout(
            summary: build.traceSummary(receipt: receipt)
        )
        XCTAssertEqual(
            readout.schemaVersion,
            OwnerTruthContextCitationQAEvidenceReadout.schemaVersion
        )
        XCTAssertEqual(readout.authorityState, .ready)
        XCTAssertEqual(readout.authorityEpoch, 7)
        XCTAssertEqual(readout.selectedContextRefDigests.count, 1)
        XCTAssertNotEqual(readout.selectedContextRefDigests, [reference])
        XCTAssertEqual(readout.selectedContextRefDigests.first?.count, 64)
        XCTAssertEqual(readout.citationCount, 1)
        XCTAssertEqual(readout.answerCitationCount, 1)

        let encoded = try JSONEncoder().encode(readout)
        let text = String(decoding: encoded, as: UTF8.self)
        XCTAssertFalse(text.contains(reference))
        XCTAssertFalse(text.contains(query))
        XCTAssertFalse(text.contains(answer))
        XCTAssertFalse(text.contains(build.contextHash))
        XCTAssertFalse(text.contains(build.authority.projectionCheckpoint ?? ""))
    }

    func testAnswerCitationReceiptRejectsChangedContextHash() throws {
        let (_, lease) = try makeActiveRuntime()
        let query = "上下文 hash 必须精确绑定"
        let answer = "不能把新旧上下文混在同一份回答证据里。"
        let commandID = "owner-truth-answer-citation-ios-002"
        let build = try OwnerTruthContextShadowBuild(
            backendJSONObject: try contextShadowBuildResponse(for: lease, query: query),
            expectedVaultID: try XCTUnwrap(OwnerTruthVaultID(lease.vaultId)),
            expectedIntent: "echo_chat",
            expectedQuery: query
        )
        var response = answerCitationReceiptResponse(
            for: build,
            commandID: commandID,
            query: query,
            answer: answer
        )
        var receipt = try XCTUnwrap(response["answerCitation"] as? [String: Any])
        receipt["contextHash"] = digest("different-context")
        response["answerCitation"] = receipt

        XCTAssertThrowsError(
            try OwnerTruthAnswerCitationReceipt(
                backendJSONObject: response,
                expectedContext: build,
                expectedCommandID: commandID,
                expectedQuery: query,
                expectedAnswerText: answer
            )
        ) { error in
            guard case .invalidAnswerCitationReceipt = error as? OwnerTruthRemoteContractError else {
                return XCTFail("expected changed context rejection, got \(error)")
            }
        }
    }

    func testCorrectionRequestCommandAndReceiptBindExactAnswerCitationWithoutRawText() throws {
        let (_, lease) = try makeActiveRuntime()
        let query = "请依据已确认记忆回答"
        let answer = "我会只依据已确认的个人记忆继续回答。"
        let correctionText = "不是父亲，是外祖父在院子里讲故事。"
        let build = try OwnerTruthContextShadowBuild(
            backendJSONObject: try contextShadowBuildResponse(for: lease, query: query),
            expectedVaultID: try XCTUnwrap(OwnerTruthVaultID(lease.vaultId)),
            expectedIntent: "echo_chat",
            expectedQuery: query
        )
        let answerReceipt = try OwnerTruthAnswerCitationReceipt(
            backendJSONObject: answerCitationReceiptResponse(
                for: build,
                commandID: "owner-truth-answer-citation-correction-ios-001",
                query: query,
                answer: answer
            ),
            expectedContext: build,
            expectedCommandID: "owner-truth-answer-citation-correction-ios-001",
            expectedQuery: query,
            expectedAnswerText: answer
        )
        let citationID = try XCTUnwrap(answerReceipt.citations.first?.citationID)
        let command = try OwnerTruthCorrectionRequestCommand(
            commandID: "owner-truth-correction-request-ios-001",
            answerCitationReceipt: answerReceipt,
            citationID: citationID,
            correctionText: correctionText,
            reasonCode: "ownerReportedCorrection"
        )
        let receipt = try OwnerTruthCorrectionRequestReceipt(
            backendJSONObject: correctionRequestReceiptResponse(for: command),
            expectedCommand: command
        )

        XCTAssertEqual(command.vaultID, OwnerTruthVaultID(lease.vaultId))
        XCTAssertEqual(command.answerID, answerReceipt.answerID)
        XCTAssertEqual(command.citationID, citationID)
        XCTAssertEqual(command.memoryID, answerReceipt.citations[0].citation.memoryID)
        XCTAssertEqual(command.expectedMemoryVersionID, answerReceipt.citations[0].citation.memoryVersionID)
        XCTAssertEqual(receipt.outcome, .created)
        XCTAssertEqual(receipt.status, .pendingReview)
        XCTAssertEqual(receipt.answerID, command.answerID)
        XCTAssertEqual(receipt.citationID, command.citationID)
        XCTAssertEqual(receipt.correctionTextHash, digest(correctionText))
        XCTAssertEqual(receipt.correctionTextLength, correctionText.unicodeScalars.count)

        let encoded = try JSONEncoder().encode(receipt)
        let encodedText = String(decoding: encoded, as: UTF8.self)
        XCTAssertFalse(encodedText.contains(correctionText))
        XCTAssertFalse(encodedText.contains(answer))
        XCTAssertFalse(encodedText.contains(query))
    }

    func testCorrectionRequestCommandRejectsCitationOutsideVerifiedReceipt() throws {
        let (_, lease) = try makeActiveRuntime()
        let query = "引用必须来自同一份已验证的回答回执"
        let answer = "没有可验证的引用时不能提交纠正。"
        let build = try OwnerTruthContextShadowBuild(
            backendJSONObject: try contextShadowBuildResponse(for: lease, query: query),
            expectedVaultID: try XCTUnwrap(OwnerTruthVaultID(lease.vaultId)),
            expectedIntent: "echo_chat",
            expectedQuery: query
        )
        let answerReceipt = try OwnerTruthAnswerCitationReceipt(
            backendJSONObject: answerCitationReceiptResponse(
                for: build,
                commandID: "owner-truth-answer-citation-correction-ios-002",
                query: query,
                answer: answer
            ),
            expectedContext: build,
            expectedCommandID: "owner-truth-answer-citation-correction-ios-002",
            expectedQuery: query,
            expectedAnswerText: answer
        )

        XCTAssertThrowsError(
            try OwnerTruthCorrectionRequestCommand(
                commandID: "owner-truth-correction-request-ios-002",
                answerCitationReceipt: answerReceipt,
                citationID: recordID("00000000-0000-0000-0000-000000000399"),
                correctionText: "这条修正不应绑定不存在的引用。",
                reasonCode: "ownerReportedCorrection"
            )
        ) { error in
            guard case .invalidCorrectionRequestCommand = error as? OwnerTruthRemoteContractError else {
                return XCTFail("expected unverified citation rejection, got \(error)")
            }
        }
    }

    func testCorrectionRequestUseCaseSubmitsPendingCandidateWithoutMutatingLegacyState() throws {
        let (runtime, lease) = try makeActiveRuntime()
        let query = "请记录一次可以纠正的回答"
        let answer = "我会在确认后再更新个人记忆。"
        let correctionText = "这段记忆的时间应改为夏天。"
        let build = try OwnerTruthContextShadowBuild(
            backendJSONObject: try contextShadowBuildResponse(for: lease, query: query),
            expectedVaultID: try XCTUnwrap(OwnerTruthVaultID(lease.vaultId)),
            expectedIntent: "echo_chat",
            expectedQuery: query
        )
        let answerReceipt = try OwnerTruthAnswerCitationReceipt(
            backendJSONObject: answerCitationReceiptResponse(
                for: build,
                commandID: "owner-truth-answer-citation-correction-ios-003",
                query: query,
                answer: answer
            ),
            expectedContext: build,
            expectedCommandID: "owner-truth-answer-citation-correction-ios-003",
            expectedQuery: query,
            expectedAnswerText: answer
        )
        let citationID = try XCTUnwrap(answerReceipt.citations.first?.citationID)
        let expectedCommand = try OwnerTruthCorrectionRequestCommand(
            commandID: "owner-truth-correction-request-ios-003",
            answerCitationReceipt: answerReceipt,
            citationID: citationID,
            correctionText: correctionText,
            reasonCode: "ownerReportedCorrection"
        )
        let client = CorrectionRequestClientSpy()
        client.requestResult = .success(try OwnerTruthCorrectionRequestReceipt(
            backendJSONObject: correctionRequestReceiptResponse(for: expectedCommand),
            expectedCommand: expectedCommand
        ))
        let useCase = OwnerTruthCorrectionRequestUseCase(
            accountLease: lease,
            answerCitationReceipt: answerReceipt,
            client: client,
            accountLeaseRuntime: runtime,
            qaGateEnabled: { true },
            commandIDFactory: { "owner-truth-correction-request-ios-003" }
        )

        useCase.send(.submit(
            citationID: citationID,
            correctionText: correctionText,
            reasonCode: "ownerReportedCorrection"
        ))

        XCTAssertEqual(client.requestedCommands, [expectedCommand])
        XCTAssertEqual(useCase.viewState.phase, .submitted)
        XCTAssertEqual(useCase.viewState.notice, .requestCreated)
        XCTAssertEqual(
            useCase.viewState.latestReceipt?.candidateID,
            recordID("00000000-0000-0000-0000-000000000351")
        )
        XCTAssertEqual(useCase.viewState.latestReceipt?.candidateVersion, 1)
    }

    func testCorrectionRequestUseCaseFailsClosedWhenContextQAGateIsDisabled() throws {
        let (runtime, lease) = try makeActiveRuntime()
        let answerReceipt = try verifiedAnswerCitationReceipt(
            for: lease,
            query: "未开启 QA 时不得创建纠错请求",
            answer: "关闭 QA gate 后不能访问纠错写入路径。",
            commandID: "owner-truth-answer-citation-correction-gate"
        )
        let client = CorrectionRequestClientSpy()
        let useCase = OwnerTruthCorrectionRequestUseCase(
            accountLease: lease,
            answerCitationReceipt: answerReceipt,
            client: client,
            accountLeaseRuntime: runtime,
            qaGateEnabled: { false },
            commandIDFactory: { "owner-truth-correction-request-gate" }
        )

        useCase.send(.submit(
            citationID: try XCTUnwrap(answerReceipt.citations.first).citationID,
            correctionText: "这条请求必须在 gate 关闭时被拒绝。",
            reasonCode: "ownerReportedCorrection"
        ))

        XCTAssertEqual(useCase.viewState.phase, .unavailable)
        XCTAssertEqual(useCase.viewState.notice, .qaOnlyDisabled)
        XCTAssertNil(useCase.viewState.latestReceipt)
        XCTAssertTrue(client.requestedCommands.isEmpty)
    }

    func testCorrectionRequestUseCaseRejectsCompletionAfterAccountLeaseChanges() throws {
        let (runtime, lease) = try makeActiveRuntime()
        let answerReceipt = try verifiedAnswerCitationReceipt(
            for: lease,
            query: "账户切换后不得接收纠错回执",
            answer: "纠错结果必须绑定发起时的账户租约。",
            commandID: "owner-truth-answer-citation-correction-stale"
        )
        let citationID = try XCTUnwrap(answerReceipt.citations.first).citationID
        let expectedCommand = try OwnerTruthCorrectionRequestCommand(
            commandID: "owner-truth-correction-request-stale",
            answerCitationReceipt: answerReceipt,
            citationID: citationID,
            correctionText: "账户切换后的异步结果必须被丢弃。",
            reasonCode: "ownerReportedCorrection"
        )
        let client = CorrectionRequestClientSpy()
        client.deferRequest = true
        let useCase = OwnerTruthCorrectionRequestUseCase(
            accountLease: lease,
            answerCitationReceipt: answerReceipt,
            client: client,
            accountLeaseRuntime: runtime,
            qaGateEnabled: { true },
            commandIDFactory: { expectedCommand.commandID }
        )

        useCase.send(.submit(
            citationID: citationID,
            correctionText: expectedCommand.correctionText,
            reasonCode: expectedCommand.reasonCode
        ))
        XCTAssertEqual(useCase.viewState.phase, .submitting(citationID))
        XCTAssertEqual(client.requestedCommands, [expectedCommand])

        runtime.publish(session: accountSession(
            subjectId: "owner-b",
            vaultId: "vault-b",
            generation: 2,
            generationID: UUID(uuidString: "00000000-0000-0000-0000-000000000102")!
        ))
        client.completeDeferredRequest(.success(try OwnerTruthCorrectionRequestReceipt(
            backendJSONObject: correctionRequestReceiptResponse(for: expectedCommand),
            expectedCommand: expectedCommand
        )))

        XCTAssertEqual(useCase.viewState.phase, .unavailable)
        XCTAssertEqual(useCase.viewState.notice, .staleAccountLease)
        XCTAssertNil(useCase.viewState.latestReceipt)
    }

    func testCorrectionCandidateHandoffRefreshesExistingInboxAndLeavesReviewAuthorityWithInbox() throws {
        let (runtime, lease) = try makeActiveRuntime()
        let answerReceipt = try verifiedAnswerCitationReceipt(
            for: lease,
            query: "这条回答可以被纠正后进入审核。",
            answer: "我会先把需要纠正的内容交给本人审核。",
            commandID: "owner-truth-answer-citation-handoff"
        )
        let citationID = try XCTUnwrap(answerReceipt.citations.first?.citationID)
        let expectedCommand = try OwnerTruthCorrectionRequestCommand(
            commandID: "owner-truth-correction-handoff",
            answerCitationReceipt: answerReceipt,
            citationID: citationID,
            correctionText: "这条记忆应保留为待审核候选。",
            reasonCode: "ownerReportedCorrection"
        )
        let correctionClient = CorrectionRequestClientSpy()
        let correctionReceipt = try OwnerTruthCorrectionRequestReceipt(
            backendJSONObject: correctionRequestReceiptResponse(for: expectedCommand),
            expectedCommand: expectedCommand
        )
        correctionClient.requestResult = .success(correctionReceipt)

        let candidateClient = CandidateReviewClientSpy()
        candidateClient.inboxResult = .success(try candidateInbox(
            vaultID: lease.vaultId,
            candidateID: correctionReceipt.candidateID
        ))
        candidateClient.reviewResult = .success(try decisionResult(
            candidateID: correctionReceipt.candidateID,
            decision: .accepted
        ))
        let handoff = OwnerTruthCorrectionCandidateInboxHandoffUseCase(
            accountLease: lease,
            answerCitationReceipt: answerReceipt,
            correctionClient: correctionClient,
            candidateReviewClient: candidateClient,
            accountLeaseRuntime: runtime,
            correctionQAGateEnabled: { true },
            candidateReviewQAGateEnabled: { true },
            correctionCommandIDFactory: { expectedCommand.commandID }
        )

        handoff.send(.submit(
            citationID: citationID,
            correctionText: expectedCommand.correctionText,
            reasonCode: expectedCommand.reasonCode
        ))

        XCTAssertEqual(correctionClient.requestedCommands, [expectedCommand])
        XCTAssertEqual(handoff.viewState.phase, .ready)
        XCTAssertNil(handoff.viewState.notice)
        XCTAssertEqual(handoff.viewState.correctionRequestID, correctionReceipt.correctionRequestID)
        XCTAssertEqual(handoff.viewState.candidateID, correctionReceipt.candidateID)
        XCTAssertEqual(handoff.candidateInboxUseCase.viewState.phase, .ready)
        XCTAssertEqual(
            handoff.candidateInboxUseCase.viewState.items.map(\.id),
            [correctionReceipt.candidateID]
        )

        handoff.candidateInboxUseCase.send(.accept(candidateID: correctionReceipt.candidateID))

        XCTAssertEqual(handoff.candidateInboxUseCase.viewState.phase, .empty)
        XCTAssertEqual(
            handoff.candidateInboxUseCase.viewState.latestReceipt?.candidateID,
            correctionReceipt.candidateID
        )
        XCTAssertTrue(handoff.candidateInboxUseCase.viewState.latestReceipt?.createdMemoryVersion == true)
        XCTAssertEqual(handoff.viewState.phase, .ready)
    }

    func testCorrectionCandidateHandoffFailsClosedWhenPendingCandidateIsAbsentFromInbox() throws {
        let (runtime, lease) = try makeActiveRuntime()
        let answerReceipt = try verifiedAnswerCitationReceipt(
            for: lease,
            query: "纠正候选必须出现在同一 Vault 的审核收件箱。",
            answer: "不可见的候选不得被假定为可审核。",
            commandID: "owner-truth-answer-citation-handoff-missing"
        )
        let citationID = try XCTUnwrap(answerReceipt.citations.first?.citationID)
        let expectedCommand = try OwnerTruthCorrectionRequestCommand(
            commandID: "owner-truth-correction-handoff-missing",
            answerCitationReceipt: answerReceipt,
            citationID: citationID,
            correctionText: "候选必须先在收件箱中可见。",
            reasonCode: "ownerReportedCorrection"
        )
        let correctionClient = CorrectionRequestClientSpy()
        let correctionReceipt = try OwnerTruthCorrectionRequestReceipt(
            backendJSONObject: correctionRequestReceiptResponse(for: expectedCommand),
            expectedCommand: expectedCommand
        )
        correctionClient.requestResult = .success(correctionReceipt)
        let candidateClient = CandidateReviewClientSpy()
        candidateClient.inboxResult = .success(try candidateInbox(
            vaultID: lease.vaultId,
            candidateID: recordID("00000000-0000-0000-0000-000000000353")
        ))
        let handoff = OwnerTruthCorrectionCandidateInboxHandoffUseCase(
            accountLease: lease,
            answerCitationReceipt: answerReceipt,
            correctionClient: correctionClient,
            candidateReviewClient: candidateClient,
            accountLeaseRuntime: runtime,
            correctionQAGateEnabled: { true },
            candidateReviewQAGateEnabled: { true },
            correctionCommandIDFactory: { expectedCommand.commandID }
        )

        handoff.send(.submit(
            citationID: citationID,
            correctionText: expectedCommand.correctionText,
            reasonCode: expectedCommand.reasonCode
        ))

        XCTAssertEqual(handoff.viewState.phase, .failed)
        XCTAssertEqual(handoff.viewState.notice, .candidateUnavailable)
        XCTAssertEqual(handoff.viewState.correctionRequestID, correctionReceipt.correctionRequestID)
        XCTAssertEqual(handoff.viewState.candidateID, correctionReceipt.candidateID)
    }

    func testCorrectionCandidateHandoffRequiresBothQAGatesBeforeWritingOrReading() throws {
        let (runtime, lease) = try makeActiveRuntime()
        let answerReceipt = try verifiedAnswerCitationReceipt(
            for: lease,
            query: "关闭审核 QA 时不得请求纠正候选。",
            answer: "写入与审核必须同时处于受控 QA 环境。",
            commandID: "owner-truth-answer-citation-handoff-gate"
        )
        let correctionClient = CorrectionRequestClientSpy()
        let candidateClient = CandidateReviewClientSpy()
        let handoff = OwnerTruthCorrectionCandidateInboxHandoffUseCase(
            accountLease: lease,
            answerCitationReceipt: answerReceipt,
            correctionClient: correctionClient,
            candidateReviewClient: candidateClient,
            accountLeaseRuntime: runtime,
            correctionQAGateEnabled: { true },
            candidateReviewQAGateEnabled: { false },
            correctionCommandIDFactory: { "owner-truth-correction-handoff-gate" }
        )

        handoff.send(.submit(
            citationID: try XCTUnwrap(answerReceipt.citations.first?.citationID),
            correctionText: "关闭审核入口时不得创建候选。",
            reasonCode: "ownerReportedCorrection"
        ))

        XCTAssertEqual(handoff.viewState.phase, .unavailable)
        XCTAssertEqual(handoff.viewState.notice, .qaOnlyDisabled)
        XCTAssertNil(handoff.viewState.correctionRequestID)
        XCTAssertNil(handoff.viewState.candidateID)
        XCTAssertTrue(correctionClient.requestedCommands.isEmpty)
    }

    private func contextShadowBuildResponse(
        for lease: AccountLease,
        query: String
    ) throws -> [String: Any] {
        let selectedCitation: [String: Any] = [
            "vaultId": lease.vaultId,
            "memoryId": "00000000-0000-0000-0000-000000000301",
            "memoryVersionId": "00000000-0000-0000-0000-000000000302",
            "memoryVersion": 2,
            "sourceId": "00000000-0000-0000-0000-000000000303",
            "sourceVersion": 1,
            "contentHash": digest("selected-content"),
        ]
        let selectedSourceRef: [String: Any] = [
            "vaultId": lease.vaultId,
            "sourceId": "00000000-0000-0000-0000-000000000303",
            "sourceVersion": 1,
        ]
        let selected: [String: Any] = [
            "source": "owner-truth-memory-projection",
            "refId": "memory-version:00000000-0000-0000-0000-000000000302",
            "memoryId": "00000000-0000-0000-0000-000000000301",
            "memoryVersionId": "00000000-0000-0000-0000-000000000302",
            "memoryVersion": 2,
            "memoryKind": "experience",
            "perspectiveType": "firstPerson",
            "epistemicStatus": "recalled",
            "sensitivity": "standard",
            "visibility": "owner",
            "sourceRef": selectedSourceRef,
            "citation": selectedCitation,
            "reason": "confirmed_current_memory_version",
            "rank": [
                "position": 1,
                "strategy": "projectionCitationOrder",
            ],
        ]
        let filteredCitation: [String: Any] = [
            "vaultId": lease.vaultId,
            "memoryId": "00000000-0000-0000-0000-000000000311",
            "memoryVersionId": "00000000-0000-0000-0000-000000000312",
            "memoryVersion": 1,
            "sourceId": "00000000-0000-0000-0000-000000000313",
            "sourceVersion": 1,
            "contentHash": digest("filtered-content"),
        ]
        let filtered: [String: Any] = [
            "source": "owner-truth-memory-projection",
            "refId": "memory-version:00000000-0000-0000-0000-000000000312",
            "memoryId": "00000000-0000-0000-0000-000000000311",
            "memoryVersionId": "00000000-0000-0000-0000-000000000312",
            "memoryKind": "experience",
            "sensitivity": "sensitive",
            "sourceRef": [
                "vaultId": lease.vaultId,
                "sourceId": "00000000-0000-0000-0000-000000000313",
                "sourceVersion": 1,
            ],
            "citation": filteredCitation,
            "reason": "sensitivity_not_context_eligible",
        ]
        let shadow: [String: Any] = [
            "schemaVersion": "owner-truth-context-shadow-build-v1",
            "contextVersion": "echo-context-v4-shadow",
            "policyVersion": "owner-truth-context-shadow-build-policy-v1",
            "shadowOnly": true,
            "legacyContextUnchanged": true,
            "legacyContextRead": false,
            "contextHash": digest("context-hash"),
            "request": [
                "intent": "echo_chat",
                "queryHash": digest(query),
                "queryLength": query.unicodeScalars.count,
            ],
            "authority": [
                "source": "owner-truth-memory-projection",
                "state": "ready",
                "vaultId": lease.vaultId,
                "authorityEpoch": 7,
                "projectionCheckpoint": digest("projection-checkpoint"),
            ],
            "selectedContext": [selected],
            "filteredContext": [filtered],
            "rankingTrace": [[
                "refId": "memory-version:00000000-0000-0000-0000-000000000302",
                "source": "owner-truth-memory-projection",
                "selected": true,
                "reason": "confirmed_current_memory_version",
                "rank": [
                    "position": 1,
                    "strategy": "projectionCitationOrder",
                ],
            ]],
            "citationProof": [[
                "refId": "memory-version:00000000-0000-0000-0000-000000000302",
                "source": "owner-truth-memory-projection",
                "resolved": true,
                "resolution": "current_confirmed_projection_entry",
                "citation": selectedCitation,
                "sourceRef": selectedSourceRef,
            ]],
            "selectedContextSourceCounts": [
                "owner-truth-memory-projection": 1,
            ],
            "fallbacks": [],
            "trace": [
                "selectedContextCount": 1,
                "filteredContextCount": 1,
                "rankingTraceCount": 1,
                "citationProofCount": 1,
                "fallbackCount": 0,
            ],
        ]
        return [
            "schemaVersion": "owner-truth-context-shadow-build-response-v1",
            "contextShadow": shadow,
        ]
    }

    private func answerCitationReceiptResponse(
        for context: OwnerTruthContextShadowBuild,
        commandID: String,
        query: String,
        answer: String
    ) -> [String: Any] {
        let citations: [[String: Any]] = context.selectedContext.enumerated().map { index, item in
            [
                "citationId": index == 0
                    ? "00000000-0000-0000-0000-000000000321"
                    : UUID().uuidString.lowercased(),
                "position": index + 1,
                "resolved": true,
                "resolution": "current_confirmed_projection_entry",
                "citation": item.citation.backendJSONObject,
            ]
        }
        return [
            "schemaVersion": "owner-truth-answer-citation-receipt-response-v1",
            "status": "created",
            "answerCitation": [
                "schemaVersion": "owner-truth-answer-citation-v1",
                "outcome": "created",
                "answerId": "00000000-0000-0000-0000-000000000320",
                "commandIdHash": digest(commandID),
                "contextHash": context.contextHash,
                "contextVersion": context.contextVersion,
                "queryHash": digest(query),
                "answerHash": digest(answer),
                "answerLength": answer.unicodeScalars.count,
                "authorityEpoch": context.authority.authorityEpoch ?? NSNull(),
                "projectionCheckpoint": context.authority.projectionCheckpoint ?? NSNull(),
                "citationCount": citations.count,
                "citations": citations,
                "fallbacks": context.fallbacks,
            ],
        ]
    }

    private func correctionRequestReceiptResponse(
        for command: OwnerTruthCorrectionRequestCommand,
        outcome: OwnerTruthCorrectionRequestOutcome = .created
    ) -> [String: Any] {
        [
            "schemaVersion": "owner-truth-correction-request-response-v1",
            "status": outcome.rawValue,
            "correctionRequest": [
                "schemaVersion": "owner-truth-correction-request-v1",
                "outcome": outcome.rawValue,
                "correctionRequestId": "00000000-0000-0000-0000-000000000350",
                "candidateId": "00000000-0000-0000-0000-000000000351",
                "candidateVersion": 1,
                "answerId": command.answerID.rawValue.uuidString.lowercased(),
                "citationId": command.citationID.rawValue.uuidString.lowercased(),
                "memoryId": command.memoryID.rawValue.uuidString.lowercased(),
                "expectedMemoryVersionId": command.expectedMemoryVersionID.rawValue.uuidString.lowercased(),
                "correctionSourceId": "00000000-0000-0000-0000-000000000352",
                "correctionTextHash": command.correctionTextHash,
                "correctionTextLength": command.correctionTextLength,
                "status": "pendingReview",
            ],
        ]
    }

    private func verifiedAnswerCitationReceipt(
        for lease: AccountLease,
        query: String,
        answer: String,
        commandID: String
    ) throws -> OwnerTruthAnswerCitationReceipt {
        let build = try OwnerTruthContextShadowBuild(
            backendJSONObject: try contextShadowBuildResponse(for: lease, query: query),
            expectedVaultID: try XCTUnwrap(OwnerTruthVaultID(lease.vaultId)),
            expectedIntent: "echo_chat",
            expectedQuery: query
        )
        return try OwnerTruthAnswerCitationReceipt(
            backendJSONObject: answerCitationReceiptResponse(
                for: build,
                commandID: commandID,
                query: query,
                answer: answer
            ),
            expectedContext: build,
            expectedCommandID: commandID,
            expectedQuery: query,
            expectedAnswerText: answer
        )
    }

    private func digest(_ value: String) -> String {
        SHA256.hash(data: Data(value.utf8))
            .map { String(format: "%02x", $0) }
            .joined()
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
        generationID: UUID,
        sessionID: String? = nil
    ) -> AccountSession {
        AccountSession(
            subjectId: subjectId,
            vaultId: vaultId,
            sessionId: sessionID ?? "session-\(generation)",
            tokenFamilyId: "family-\(generation)",
            sessionVersion: Int(generation),
            generation: generation,
            generationId: generationID,
            state: .active,
            activatedAt: Date(timeIntervalSince1970: 1_700_000_000)
        )
    }

    private func compatibilityReadEnvelope(
        for lease: AccountLease
    ) throws -> OwnerTruthKBLiteCompatibilityReadEnvelope {
        try OwnerTruthKBLiteCompatibilityReadEnvelope(
            backendJSONObject: try compatibilityReadEnvelopeJSONObject(for: lease),
            expectedVaultID: try XCTUnwrap(OwnerTruthVaultID(lease.vaultId)),
            expectedOwnerSubjectID: lease.subjectId
        )
    }

    private func compatibilityReadEnvelopeJSONObject(
        for lease: AccountLease
    ) throws -> [String: Any] {
        let graph = try OwnerTruthKBLiteCompatibilityGraph(backendJSONObject: [
            "people": [],
            "places": [],
            "events": [],
            "facts": [[
                "id": "owner_truth_fact_memory-version-1",
                "statement": "院子里有一棵树",
                "confidence": "confirmed",
                "evidenceStatus": "confirmed",
                "compatibilitySource": OwnerTruthKBLiteCompatibilityReadEnvelope.compatibilitySource,
                "citation": [
                    "memoryId": "memory-1",
                    "memoryVersionId": "memory-version-1",
                    "sourceId": "source-1",
                    "sourceVersion": 1,
                    "contentHash": "source-content-hash",
                    "memoryVersion": 1,
                ],
            ]],
        ])
        return [
            "schemaVersion": OwnerTruthKBLiteCompatibilityReadEnvelope.schemaVersion,
            "projectionSource": OwnerTruthKBLiteCompatibilityReadEnvelope.projectionSource,
            "compatibilitySource": OwnerTruthKBLiteCompatibilityReadEnvelope.compatibilitySource,
            "state": "ready",
            "vaultId": lease.vaultId,
            "ownerSubjectId": lease.subjectId,
            "authorityEpoch": 2,
            "projectionCheckpoint": "projection-checkpoint-2",
            "cacheDisposition": "replace",
            "contentHash": try OwnerTruthKBLiteCompatibilityReadEnvelope.graphContentHash(graph),
            "graph": graph.backendJSONObject,
            "filteredEntries": [],
        ]
    }

    private func recordID(_ rawValue: String) -> OwnerTruthRecordID {
        OwnerTruthRecordID(rawValue: UUID(uuidString: rawValue)!)
    }

    private func interviewCandidateReviewBatch(
        vaultID: String,
        reviewBatchID: OwnerTruthRecordID,
        batchCandidateID: OwnerTruthRecordID,
        singleCandidateID: OwnerTruthRecordID
    ) throws -> OwnerTruthInterviewCandidateReviewBatch {
        let sourceID = "00000000-0000-0000-0000-000000000141"
        let extractionID = "00000000-0000-0000-0000-000000000142"
        return try OwnerTruthInterviewCandidateReviewBatch(
            backendJSONObject: [
                "schemaVersion": OwnerTruthInterviewCandidateReviewBatch.schemaVersion,
                "vaultId": vaultID,
                "review": [
                    "schemaVersion": OwnerTruthInterviewCandidateReviewBatch.compositionSchemaVersion,
                    "reviewBatchId": reviewBatchID.rawValue.uuidString,
                    "admissionId": "00000000-0000-0000-0000-000000000143",
                    "sourceId": sourceID,
                    "sourceVersion": 1,
                    "authorityEpoch": 0,
                    "readiness": OwnerTruthInterviewCandidateReviewReadiness.reviewReady.rawValue,
                    "latestExtractionStatus": "succeeded",
                    "batchCandidateCount": 1,
                    "singleCandidateCount": 1,
                ],
                "batchCandidates": [[
                    "candidateId": batchCandidateID.rawValue.uuidString,
                    "sourceId": sourceID,
                    "memoryKind": OwnerTruthMemoryKind.experience.rawValue,
                    "perspectiveType": OwnerTruthPerspectiveType.firstPerson.rawValue,
                    "epistemicStatus": OwnerTruthEpistemicStatus.recalled.rawValue,
                    "sensitivity": OwnerTruthSensitivityLevel.standard.rawValue,
                    "contentSchemaVersion": "owner-truth-candidate-content-v1",
                    "content": ["summary": "院子里听家人讲故事"],
                    "contentHash": "interview-usecase-batch-hash",
                    "sourceRefs": [["sourceId": sourceID, "sourceVersion": 1]],
                    "reviewMode": "batch",
                    "candidateVersion": 1,
                    "extractionId": extractionID,
                    "reviewPath": OwnerTruthInterviewCandidateReviewPath.batch.rawValue,
                ]],
                "singleCandidates": [[
                    "candidateId": singleCandidateID.rawValue.uuidString,
                    "sourceId": sourceID,
                    "memoryKind": OwnerTruthMemoryKind.experience.rawValue,
                    "perspectiveType": OwnerTruthPerspectiveType.firstPerson.rawValue,
                    "epistemicStatus": OwnerTruthEpistemicStatus.recalled.rawValue,
                    "sensitivity": OwnerTruthSensitivityLevel.sensitive.rawValue,
                    "contentSchemaVersion": "owner-truth-candidate-content-v1",
                    "content": ["summary": "需要逐条确认的敏感经历"],
                    "contentHash": "interview-usecase-single-hash",
                    "sourceRefs": [["sourceId": sourceID, "sourceVersion": 1]],
                    "reviewMode": "single",
                    "candidateVersion": 1,
                    "extractionId": extractionID,
                    "reviewPath": OwnerTruthInterviewCandidateReviewPath.single.rawValue,
                ]],
            ],
            expectedVaultID: try XCTUnwrap(OwnerTruthVaultID(vaultID)),
            expectedReviewBatchID: reviewBatchID
        )
    }

    private func interviewCandidateConfirmation(
        vaultID: String,
        reviewBatchID: OwnerTruthRecordID,
        batchCandidateID: OwnerTruthRecordID,
        singleCandidateID: OwnerTruthRecordID
    ) throws -> OwnerTruthInterviewCandidateConfirmation {
        let sourceID = "00000000-0000-0000-0000-000000000151"
        let extractionID = "00000000-0000-0000-0000-000000000152"
        return try OwnerTruthInterviewCandidateConfirmation(
            backendJSONObject: [
                "schemaVersion": OwnerTruthInterviewCandidateConfirmation.schemaVersion,
                "vaultId": vaultID,
                "confirmation": [
                    "schemaVersion": OwnerTruthInterviewCandidateConfirmation.compositionSchemaVersion,
                    "reviewBatchId": reviewBatchID.rawValue.uuidString,
                    "admissionId": "00000000-0000-0000-0000-000000000153",
                    "sourceId": sourceID,
                    "sourceVersion": 1,
                    "authorityEpoch": 0,
                    "readiness": OwnerTruthInterviewCandidateReviewReadiness.reviewReady.rawValue,
                    "latestExtractionStatus": "succeeded",
                    "batchCandidateCount": 1,
                    "singleCandidateCount": 1,
                ],
                "batchCandidates": [[
                    "candidateId": batchCandidateID.rawValue.uuidString,
                    "sourceId": sourceID,
                    "memoryKind": OwnerTruthMemoryKind.experience.rawValue,
                    "perspectiveType": OwnerTruthPerspectiveType.firstPerson.rawValue,
                    "epistemicStatus": OwnerTruthEpistemicStatus.recalled.rawValue,
                    "sensitivity": OwnerTruthSensitivityLevel.standard.rawValue,
                    "contentSchemaVersion": "owner-truth-candidate-content-v1",
                    "content": ["summary": "确认前只读的普通候选"],
                    "contentHash": "interview-confirmation-batch-hash",
                    "sourceRefs": [["sourceId": sourceID, "sourceVersion": 1]],
                    "reviewMode": "batch",
                    "candidateVersion": 1,
                    "extractionId": extractionID,
                    "reviewPath": OwnerTruthInterviewCandidateReviewPath.batch.rawValue,
                ]],
                "singleCandidates": [[
                    "candidateId": singleCandidateID.rawValue.uuidString,
                    "sourceId": sourceID,
                    "memoryKind": OwnerTruthMemoryKind.experience.rawValue,
                    "perspectiveType": OwnerTruthPerspectiveType.firstPerson.rawValue,
                    "epistemicStatus": OwnerTruthEpistemicStatus.recalled.rawValue,
                    "sensitivity": OwnerTruthSensitivityLevel.sensitive.rawValue,
                    "contentSchemaVersion": "owner-truth-candidate-content-v1",
                    "content": ["summary": "确认前只读的敏感候选"],
                    "contentHash": "interview-confirmation-single-hash",
                    "sourceRefs": [["sourceId": sourceID, "sourceVersion": 1]],
                    "reviewMode": "single",
                    "candidateVersion": 1,
                    "extractionId": extractionID,
                    "reviewPath": OwnerTruthInterviewCandidateReviewPath.single.rawValue,
                ]],
            ],
            expectedVaultID: try XCTUnwrap(OwnerTruthVaultID(vaultID)),
            expectedReviewBatchID: reviewBatchID
        )
    }

    private func reconciledInterviewCandidateConfirmation(
        vaultID: String,
        reviewBatchID: OwnerTruthRecordID,
        remainingSingleCandidateID: OwnerTruthRecordID
    ) throws -> OwnerTruthInterviewCandidateConfirmation {
        let sourceID = "00000000-0000-0000-0000-000000000161"
        let extractionID = "00000000-0000-0000-0000-000000000162"
        return try OwnerTruthInterviewCandidateConfirmation(
            backendJSONObject: [
                "schemaVersion": OwnerTruthInterviewCandidateConfirmation.schemaVersion,
                "vaultId": vaultID,
                "confirmation": [
                    "schemaVersion": OwnerTruthInterviewCandidateConfirmation.compositionSchemaVersion,
                    "reviewBatchId": reviewBatchID.rawValue.uuidString,
                    "admissionId": "00000000-0000-0000-0000-000000000163",
                    "sourceId": sourceID,
                    "sourceVersion": 1,
                    "authorityEpoch": 0,
                    "readiness": OwnerTruthInterviewCandidateReviewReadiness.reviewReady.rawValue,
                    "latestExtractionStatus": "succeeded",
                    "batchCandidateCount": 0,
                    "singleCandidateCount": 1,
                ],
                "batchCandidates": [],
                "singleCandidates": [[
                    "candidateId": remainingSingleCandidateID.rawValue.uuidString,
                    "sourceId": sourceID,
                    "memoryKind": OwnerTruthMemoryKind.experience.rawValue,
                    "perspectiveType": OwnerTruthPerspectiveType.firstPerson.rawValue,
                    "epistemicStatus": OwnerTruthEpistemicStatus.recalled.rawValue,
                    "sensitivity": OwnerTruthSensitivityLevel.sensitive.rawValue,
                    "contentSchemaVersion": "owner-truth-candidate-content-v1",
                    "content": ["summary": "仍需要逐条确认的敏感经历"],
                    "contentHash": "interview-confirmation-reconciled-single-hash",
                    "sourceRefs": [["sourceId": sourceID, "sourceVersion": 1]],
                    "reviewMode": "single",
                    "candidateVersion": 1,
                    "extractionId": extractionID,
                    "reviewPath": OwnerTruthInterviewCandidateReviewPath.single.rawValue,
                ]],
            ],
            expectedVaultID: try XCTUnwrap(OwnerTruthVaultID(vaultID)),
            expectedReviewBatchID: reviewBatchID
        )
    }

    private func interviewSessionState(
        vaultID: String,
        lifecycle: OwnerTruthInterviewSessionLifecycle = .active,
        boundary: OwnerTruthInterviewSessionBoundary = .open,
        fatigue: OwnerTruthInterviewSessionFatigue = .normal,
        hasPendingReviewBatch: Bool = false
    ) throws -> OwnerTruthInterviewSessionState {
        try OwnerTruthInterviewSessionState(
            backendJSONObject: [
                "schemaVersion": OwnerTruthInterviewSessionState.schemaVersion,
                "vaultId": vaultID,
                "session": [
                    "state": lifecycle.rawValue,
                    "boundary": boundary.rawValue,
                    "rowVersion": 1,
                    "threadVersion": 2,
                    "ownerTurnCount": 3,
                    "deepeningTurnCount": 1,
                    "candidateBatchTurnCount": 0,
                    "fatigue": fatigue.rawValue,
                    "hasPendingReviewBatch": hasPendingReviewBatch,
                    "authorityEpoch": 4,
                ],
            ],
            expectedVaultID: try XCTUnwrap(OwnerTruthVaultID(vaultID))
        )
    }

    private func interviewNaturalInputReceipt(
        vaultID: OwnerTruthVaultID,
        start: OwnerTruthInterviewNaturalInputStartCommand
    ) throws -> OwnerTruthInterviewNaturalInputReceipt {
        try OwnerTruthInterviewNaturalInputReceipt(
            backendJSONObject: [
                "schemaVersion": OwnerTruthInterviewNaturalInputReceipt.schemaVersion,
                "vaultId": vaultID.rawValue,
                "receipt": [
                    "status": OwnerTruthCommandOutcome.created.rawValue,
                    "threadId": start.threadID.rawValue.uuidString,
                    "sessionId": start.sessionID.rawValue.uuidString,
                    "threadVersion": 1,
                    "sessionVersion": 1,
                    "state": OwnerTruthInterviewSessionLifecycle.active.rawValue,
                    "boundary": OwnerTruthInterviewSessionBoundary.open.rawValue,
                ],
            ],
            expectedVaultID: vaultID
        )
    }

    private func interviewNaturalInputReceipt(
        vaultID: OwnerTruthVaultID,
        append: OwnerTruthInterviewNaturalInputAppendCommand
    ) throws -> OwnerTruthInterviewNaturalInputReceipt {
        try OwnerTruthInterviewNaturalInputReceipt(
            backendJSONObject: [
                "schemaVersion": OwnerTruthInterviewNaturalInputReceipt.schemaVersion,
                "vaultId": vaultID.rawValue,
                "receipt": [
                    "status": OwnerTruthCommandOutcome.created.rawValue,
                    "threadId": append.threadID.rawValue.uuidString,
                    "sessionId": append.sessionID.rawValue.uuidString,
                    "threadVersion": append.expectedThreadVersion + 1,
                    "sessionVersion": append.expectedSessionVersion + 1,
                    "state": OwnerTruthInterviewSessionLifecycle.active.rawValue,
                    "boundary": OwnerTruthInterviewSessionBoundary.open.rawValue,
                    "messageId": append.messageID.rawValue.uuidString,
                    "messageSequence": 1,
                ],
            ],
            expectedVaultID: vaultID
        )
    }

    private func interviewBatchAcceptResult(
        reviewBatchID: OwnerTruthRecordID,
        candidateIDs: [OwnerTruthRecordID]
    ) throws -> OwnerTruthInterviewCandidateBatchAcceptResult {
        let command = try OwnerTruthInterviewCandidateBatchAcceptCommand(
            commandID: "interview-batch-receipt-command",
            reviewBatchID: reviewBatchID,
            selections: try candidateIDs.map {
                try OwnerTruthInterviewCandidateBatchSelection(
                    candidateID: $0,
                    expectedCandidateVersion: 1
                )
            },
            reasonCode: "ownerReviewed"
        )
        return try OwnerTruthInterviewCandidateBatchAcceptResult(
            backendJSONObject: [
                "schemaVersion": OwnerTruthInterviewCandidateBatchAcceptResult.schemaVersion,
                "status": OwnerTruthCommandOutcome.created.rawValue,
                "batchDecisionId": "00000000-0000-0000-0000-000000000144",
                "reviewBatchId": reviewBatchID.rawValue.uuidString,
                "acceptedCandidateCount": candidateIDs.count,
                "receipts": candidateIDs.enumerated().map { offset, candidateID in
                    [
                        "receiptId": String(format: "00000000-0000-0000-0000-%012d", 145 + offset),
                        "candidateId": candidateID.rawValue.uuidString,
                        "decision": OwnerTruthCandidateDecision.accepted.rawValue,
                        "candidateVersion": 2,
                        "correctedValueId": NSNull(),
                    ] as [String: Any]
                },
                "memoryActivation": [
                    "status": OwnerTruthMemoryActivationOutcome.notApplicable.rawValue,
                    "memoryVersionCreated": false,
                ],
            ],
            expectedCommand: command
        )
    }

    private func interviewCandidateConfirmationActionResult(
        reviewBatchID: OwnerTruthRecordID,
        candidateIDs: [OwnerTruthRecordID],
        commandID: String
    ) throws -> OwnerTruthInterviewCandidateConfirmationBatchResult {
        let command = try OwnerTruthInterviewCandidateConfirmationBatchCommand(
            commandID: commandID,
            reviewBatchID: reviewBatchID,
            selections: try candidateIDs.map {
                try OwnerTruthInterviewCandidateBatchSelection(
                    candidateID: $0,
                    expectedCandidateVersion: 1
                )
            }
        )
        return try OwnerTruthInterviewCandidateConfirmationBatchResult(
            backendJSONObject: [
                "schemaVersion": OwnerTruthInterviewCandidateConfirmationBatchResult.schemaVersion,
                "status": OwnerTruthCommandOutcome.created.rawValue,
                "batchDecisionId": "00000000-0000-0000-0000-000000000089",
                "reviewBatchId": reviewBatchID.rawValue.uuidString,
                "acceptedCandidateCount": candidateIDs.count,
                "acceptedCandidateIds": candidateIDs.map { $0.rawValue.uuidString },
                "memoryActivation": [
                    "status": OwnerTruthMemoryActivationOutcome.notApplicable.rawValue,
                    "memoryVersionCreated": false,
                ],
            ],
            expectedCommand: command
        )
    }

    private func interviewSingleReviewResult(
        reviewBatchID: OwnerTruthRecordID,
        candidateID: OwnerTruthRecordID,
        decision: OwnerTruthCandidateDecision
    ) throws -> OwnerTruthInterviewCandidateSingleReviewResult {
        let action: OwnerTruthCandidateReviewAction
        switch decision {
        case .accepted: action = .accept
        case .corrected: action = .correct
        case .rejected: action = .reject
        case .pending, .invalidated:
            throw OwnerTruthRemoteContractError.invalidInterviewCandidateDecision("test requires a terminal owner action")
        }
        let review = try OwnerTruthCandidateReviewCommand(
            commandID: "interview-single-receipt-command",
            expectedCandidateVersion: 1,
            action: action,
            correctedValue: action == .correct ? ["summary": .string("更正后的访谈线索")] : nil,
            correctedValueSchemaVersion: action == .correct ? "owner-truth-candidate-content-v1" : nil,
            reasonCode: action == .correct ? "ownerCorrected" : "ownerReviewed"
        )
        let command = OwnerTruthInterviewCandidateSingleReviewCommand(
            reviewBatchID: reviewBatchID,
            candidateID: candidateID,
            review: review
        )
        return try OwnerTruthInterviewCandidateSingleReviewResult(
            backendJSONObject: [
                "schemaVersion": OwnerTruthInterviewCandidateSingleReviewResult.schemaVersion,
                "status": OwnerTruthCommandOutcome.created.rawValue,
                "batchDecisionId": "00000000-0000-0000-0000-000000000149",
                "reviewBatchId": reviewBatchID.rawValue.uuidString,
                "receipt": [
                    "receiptId": "00000000-0000-0000-0000-000000000150",
                    "candidateId": candidateID.rawValue.uuidString,
                    "decision": decision.rawValue,
                    "candidateVersion": 2,
                    "correctedValueId": NSNull(),
                ],
                "memoryActivation": [
                    "status": OwnerTruthMemoryActivationOutcome.notApplicable.rawValue,
                    "memoryVersionCreated": false,
                ],
            ],
            expectedCommand: command
        )
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

private final class InterviewCandidateReviewClientSpy: OwnerTruthInterviewCandidateReviewClient {
    var readResult: Result<OwnerTruthInterviewCandidateReviewBatch, Error>?
    var batchResult: Result<OwnerTruthInterviewCandidateBatchAcceptResult, Error>?
    var singleResult: Result<OwnerTruthInterviewCandidateSingleReviewResult, Error>?
    var deferRead = false
    private var deferredReadCompletion: ((Result<OwnerTruthInterviewCandidateReviewBatch, Error>) -> Void)?

    private(set) var requestedBatchCommand: OwnerTruthInterviewCandidateBatchAcceptCommand?
    private(set) var requestedSingleCommand: OwnerTruthInterviewCandidateSingleReviewCommand?

    func fetchOwnerTruthInterviewCandidateReview(
        vaultID: OwnerTruthVaultID,
        reviewBatchID: OwnerTruthRecordID,
        completion: @escaping (Result<OwnerTruthInterviewCandidateReviewBatch, Error>) -> Void
    ) {
        if deferRead {
            deferredReadCompletion = completion
            return
        }
        completion(readResult ?? .failure(InterviewCandidateReviewClientSpyError.missingReadResult))
    }

    func acceptOwnerTruthInterviewCandidateBatch(
        vaultID: OwnerTruthVaultID,
        command: OwnerTruthInterviewCandidateBatchAcceptCommand,
        completion: @escaping (Result<OwnerTruthInterviewCandidateBatchAcceptResult, Error>) -> Void
    ) {
        requestedBatchCommand = command
        completion(batchResult ?? .failure(InterviewCandidateReviewClientSpyError.missingBatchResult))
    }

    func reviewOwnerTruthInterviewCandidateSingle(
        vaultID: OwnerTruthVaultID,
        command: OwnerTruthInterviewCandidateSingleReviewCommand,
        completion: @escaping (Result<OwnerTruthInterviewCandidateSingleReviewResult, Error>) -> Void
    ) {
        requestedSingleCommand = command
        completion(singleResult ?? .failure(InterviewCandidateReviewClientSpyError.missingSingleResult))
    }

    func completeDeferredRead(_ result: Result<OwnerTruthInterviewCandidateReviewBatch, Error>) {
        let completion = deferredReadCompletion
        deferredReadCompletion = nil
        completion?(result)
    }
}

private enum InterviewCandidateReviewClientSpyError: Error {
    case missingReadResult
    case missingBatchResult
    case missingSingleResult
}

private final class InterviewCandidateConfirmationClientSpy: OwnerTruthInterviewCandidateConfirmationClient {
    var readResult: Result<OwnerTruthInterviewCandidateConfirmation, Error>?
    var deferRead = false
    private var deferredReadCompletion: ((Result<OwnerTruthInterviewCandidateConfirmation, Error>) -> Void)?
    private(set) var requestCount = 0

    func fetchOwnerTruthInterviewCandidateConfirmation(
        vaultID: OwnerTruthVaultID,
        reviewBatchID: OwnerTruthRecordID,
        completion: @escaping (Result<OwnerTruthInterviewCandidateConfirmation, Error>) -> Void
    ) {
        requestCount += 1
        if deferRead {
            deferredReadCompletion = completion
            return
        }
        completion(readResult ?? .failure(InterviewCandidateConfirmationClientSpyError.missingReadResult))
    }

    func completeDeferredRead(_ result: Result<OwnerTruthInterviewCandidateConfirmation, Error>) {
        let completion = deferredReadCompletion
        deferredReadCompletion = nil
        completion?(result)
    }
}

private enum InterviewCandidateConfirmationClientSpyError: Error {
    case missingReadResult
}

private final class InterviewCandidateConfirmationActionClientSpy: OwnerTruthInterviewCandidateConfirmationActionClient {
    var result: Result<OwnerTruthInterviewCandidateConfirmationBatchResult, Error>?
    var deferResult = false
    private var deferredCompletion: ((Result<OwnerTruthInterviewCandidateConfirmationBatchResult, Error>) -> Void)?
    private(set) var requestedCommands: [OwnerTruthInterviewCandidateConfirmationBatchCommand] = []

    func confirmOwnerTruthInterviewCandidateBatch(
        vaultID: OwnerTruthVaultID,
        command: OwnerTruthInterviewCandidateConfirmationBatchCommand,
        completion: @escaping (Result<OwnerTruthInterviewCandidateConfirmationBatchResult, Error>) -> Void
    ) {
        requestedCommands.append(command)
        if deferResult {
            deferredCompletion = completion
            return
        }
        completion(result ?? .failure(InterviewCandidateConfirmationActionClientSpyError.missingActionResult))
    }

    func completeDeferredResult(_ result: Result<OwnerTruthInterviewCandidateConfirmationBatchResult, Error>) {
        let completion = deferredCompletion
        deferredCompletion = nil
        completion?(result)
    }
}

private enum InterviewCandidateConfirmationActionClientSpyError: Error {
    case missingActionResult
}

private final class InterviewSessionStateClientSpy: OwnerTruthInterviewSessionStateClient {
    var readResult: Result<OwnerTruthInterviewSessionState, Error>?
    var deferRead = false
    private var deferredReadCompletion: ((Result<OwnerTruthInterviewSessionState, Error>) -> Void)?
    private(set) var requestCount = 0

    func fetchOwnerTruthInterviewSessionState(
        vaultID: OwnerTruthVaultID,
        sessionID: OwnerTruthRecordID,
        completion: @escaping (Result<OwnerTruthInterviewSessionState, Error>) -> Void
    ) {
        requestCount += 1
        if deferRead {
            deferredReadCompletion = completion
            return
        }
        completion(readResult ?? .failure(InterviewSessionStateClientSpyError.missingReadResult))
    }

    func completeDeferredRead(_ result: Result<OwnerTruthInterviewSessionState, Error>) {
        let completion = deferredReadCompletion
        deferredReadCompletion = nil
        completion?(result)
    }
}

private enum InterviewSessionStateClientSpyError: Error {
    case missingReadResult
}

private final class InterviewNaturalInputClientSpy: OwnerTruthInterviewNaturalInputClient {
    var startHandler: ((OwnerTruthInterviewNaturalInputStartCommand) -> Result<OwnerTruthInterviewNaturalInputReceipt, Error>)?
    var appendHandler: ((OwnerTruthInterviewNaturalInputAppendCommand) -> Result<OwnerTruthInterviewNaturalInputReceipt, Error>)?
    var continuationHandler: ((OwnerTruthRecordID) -> Result<OwnerTruthInterviewNaturalInputContinuation, Error>)?
    var deferAppend = false
    private var deferredAppendCompletion: ((Result<OwnerTruthInterviewNaturalInputReceipt, Error>) -> Void)?

    private(set) var startCommand: OwnerTruthInterviewNaturalInputStartCommand?
    private(set) var appendCommand: OwnerTruthInterviewNaturalInputAppendCommand?

    func startOwnerTruthInterviewNaturalInput(
        vaultID: OwnerTruthVaultID,
        command: OwnerTruthInterviewNaturalInputStartCommand,
        completion: @escaping (Result<OwnerTruthInterviewNaturalInputReceipt, Error>) -> Void
    ) {
        startCommand = command
        completion(startHandler?(command) ?? .failure(InterviewNaturalInputClientSpyError.missingStartResult))
    }

    func appendOwnerTruthInterviewNaturalInput(
        vaultID: OwnerTruthVaultID,
        command: OwnerTruthInterviewNaturalInputAppendCommand,
        completion: @escaping (Result<OwnerTruthInterviewNaturalInputReceipt, Error>) -> Void
    ) {
        appendCommand = command
        if deferAppend {
            deferredAppendCompletion = completion
            return
        }
        completion(appendHandler?(command) ?? .failure(InterviewNaturalInputClientSpyError.missingAppendResult))
    }

    func fetchOwnerTruthInterviewNaturalInputContinuation(
        vaultID: OwnerTruthVaultID,
        sessionID: OwnerTruthRecordID,
        completion: @escaping (Result<OwnerTruthInterviewNaturalInputContinuation, Error>) -> Void
    ) {
        completion(continuationHandler?(sessionID) ?? .failure(
            InterviewNaturalInputClientSpyError.missingContinuationResult
        ))
    }

    func completeDeferredAppend(_ result: Result<OwnerTruthInterviewNaturalInputReceipt, Error>) {
        let completion = deferredAppendCompletion
        deferredAppendCompletion = nil
        completion?(result)
    }
}

private enum InterviewNaturalInputClientSpyError: Error {
    case missingStartResult
    case missingAppendResult
    case missingContinuationResult
}

private final class CorrectionRequestClientSpy: OwnerTruthCorrectionRequestClient {
    var requestResult: Result<OwnerTruthCorrectionRequestReceipt, Error>?
    var deferRequest = false
    private var deferredRequestCompletion: ((Result<OwnerTruthCorrectionRequestReceipt, Error>) -> Void)?
    private(set) var requestedCommands: [OwnerTruthCorrectionRequestCommand] = []

    func requestOwnerTruthCorrection(
        vaultID: OwnerTruthVaultID,
        expectedOwnerSubjectID: String,
        command: OwnerTruthCorrectionRequestCommand,
        completion: @escaping (Result<OwnerTruthCorrectionRequestReceipt, Error>) -> Void
    ) {
        requestedCommands.append(command)
        if deferRequest {
            deferredRequestCompletion = completion
            return
        }
        completion(requestResult ?? .failure(CorrectionRequestClientSpyError.missingRequestResult))
    }

    func completeDeferredRequest(_ result: Result<OwnerTruthCorrectionRequestReceipt, Error>) {
        let completion = deferredRequestCompletion
        deferredRequestCompletion = nil
        completion?(result)
    }
}

private enum CorrectionRequestClientSpyError: Error {
    case missingRequestResult
}

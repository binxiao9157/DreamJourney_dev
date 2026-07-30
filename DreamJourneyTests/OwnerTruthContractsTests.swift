import CryptoKit
import UIKit
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
                "selectedExtractionId": extractionID,
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
        XCTAssertEqual(review.selectedExtractionID?.rawValue.uuidString, extractionID)

        var mixedExtractionResponse = response
        var mixedSingleCandidates = try XCTUnwrap(
            mixedExtractionResponse["singleCandidates"] as? [[String: Any]]
        )
        mixedSingleCandidates[0]["extractionId"] = "00000000-0000-0000-0000-000000000052"
        mixedExtractionResponse["singleCandidates"] = mixedSingleCandidates
        XCTAssertThrowsError(
            try OwnerTruthInterviewCandidateReviewBatch(
                backendJSONObject: mixedExtractionResponse,
                expectedVaultID: vaultID,
                expectedReviewBatchID: reviewBatchID
            )
        )

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
        ).bound(to: lease)

        XCTAssertEqual(confirmation.vaultID.rawValue, lease.vaultId)
        XCTAssertEqual(confirmation.reviewBatchID, reviewBatchID)
        XCTAssertEqual(confirmation.readiness, .reviewReady)
        XCTAssertEqual(confirmation.batchCandidates.map(\.id), [batchCandidateID])
        XCTAssertEqual(confirmation.singleCandidates.map(\.id), [singleCandidateID])
    }

    func testInterviewCandidateConfirmationInboxDecodesContentFreeBatchHandles() throws {
        let (_, lease) = try makeActiveRuntime()
        let firstBatchID = recordID("00000000-0000-0000-0000-000000000071")
        let secondBatchID = recordID("00000000-0000-0000-0000-000000000072")

        let inbox = try interviewCandidateConfirmationInbox(
            vaultID: lease.vaultId,
            reviewBatchIDs: [firstBatchID, secondBatchID]
        )

        XCTAssertEqual(inbox.vaultID.rawValue, lease.vaultId)
        XCTAssertEqual(inbox.items.map(\.reviewBatchID), [firstBatchID, secondBatchID])
        XCTAssertTrue(inbox.items.allSatisfy { $0.readiness == .reviewReady })
        XCTAssertTrue(inbox.items.allSatisfy { $0.batchCandidateCount == 1 && $0.singleCandidateCount == 1 })
    }

    func testInterviewCandidateConfirmationInboxRejectsCandidateContentField() throws {
        let (_, lease) = try makeActiveRuntime()
        let reviewBatchID = recordID("00000000-0000-0000-0000-000000000072")

        XCTAssertThrowsError(
            try OwnerTruthInterviewCandidateConfirmationInbox(
                backendJSONObject: [
                    "schemaVersion": OwnerTruthInterviewCandidateConfirmationInbox.schemaVersion,
                    "vaultId": lease.vaultId,
                    "confirmations": [[
                        "reviewBatchId": reviewBatchID.rawValue.uuidString,
                        "readiness": OwnerTruthInterviewCandidateReviewReadiness.reviewReady.rawValue,
                        "batchCandidateCount": 1,
                        "singleCandidateCount": 0,
                        "candidateId": "must-not-be-in-discovery-response",
                    ]],
                ],
                expectedVaultID: try XCTUnwrap(OwnerTruthVaultID(lease.vaultId))
            )
        ) { error in
            XCTAssertEqual(
                error as? OwnerTruthRemoteContractError,
                .invalidInterviewCandidateConfirmationInbox(
                    "confirmation inbox item misses a required content-free field"
                )
            )
        }
    }

    func testInterviewCandidateConfirmationInboxUseCaseFailsClosedWithoutReleasePolicy() throws {
        let (runtime, lease) = try makeActiveRuntime()
        let client = InterviewCandidateConfirmationInboxClientSpy()
        let useCase = OwnerTruthInterviewCandidateConfirmationInboxUseCase(
            accountLease: lease,
            client: client,
            accountLeaseRuntime: runtime,
            releasePolicyAvailable: { false }
        )

        useCase.send(.refresh)

        XCTAssertEqual(useCase.viewState.phase, .unavailable)
        XCTAssertEqual(useCase.viewState.notice, .releasePolicyDisabled)
        XCTAssertEqual(client.requestCount, 0)
    }

    func testInterviewCandidateConfirmationInboxUseCaseBindsReadAndRejectsStaleAccountCompletion() throws {
        let (runtime, lease) = try makeActiveRuntime()
        let client = InterviewCandidateConfirmationInboxClientSpy()
        client.deferRead = true
        let useCase = OwnerTruthInterviewCandidateConfirmationInboxUseCase(
            accountLease: lease,
            client: client,
            accountLeaseRuntime: runtime,
            releasePolicyAvailable: { true }
        )

        useCase.send(.refresh)
        client.completeDeferredRead(.success(try interviewCandidateConfirmationInbox(
            vaultID: lease.vaultId,
            reviewBatchIDs: [recordID("00000000-0000-0000-0000-000000000073")]
        )))

        XCTAssertEqual(useCase.viewState.phase, .ready)
        XCTAssertTrue(try XCTUnwrap(useCase.viewState.inbox).isBound(to: lease))

        client.deferRead = true
        useCase.send(.refresh)
        runtime.publish(session: accountSession(
            subjectId: "owner-b",
            vaultId: "vault-b",
            generation: 2,
            generationID: UUID(uuidString: "00000000-0000-0000-0000-000000000102")!
        ))
        client.completeDeferredRead(.success(try interviewCandidateConfirmationInbox(
            vaultID: lease.vaultId,
            reviewBatchIDs: [recordID("00000000-0000-0000-0000-000000000074")]
        )))

        XCTAssertEqual(useCase.viewState.phase, .unavailable)
        XCTAssertEqual(useCase.viewState.notice, .staleAccountLease)
        XCTAssertNil(useCase.viewState.inbox)
    }

    func testInterviewCandidateMemoryActivationInboxDecodesOnlyOpaqueHandles() throws {
        let (_, lease) = try makeActiveRuntime()
        let reviewBatchID = recordID("00000000-0000-0000-0000-000000000075")
        let candidateID = recordID("00000000-0000-0000-0000-000000000076")

        let inbox = try interviewCandidateMemoryActivationInbox(
            vaultID: lease.vaultId,
            handles: [(reviewBatchID: reviewBatchID, candidateID: candidateID)]
        )

        XCTAssertEqual(inbox.vaultID.rawValue, lease.vaultId)
        XCTAssertEqual(inbox.items.map(\.reviewBatchID), [reviewBatchID])
        XCTAssertEqual(inbox.items.map(\.candidateID), [candidateID])
        XCTAssertThrowsError(
            try OwnerTruthInterviewCandidateMemoryActivationInbox(
                backendJSONObject: [
                    "schemaVersion": OwnerTruthInterviewCandidateMemoryActivationInbox.schemaVersion,
                    "vaultId": lease.vaultId,
                    "items": [[
                        "reviewBatchId": reviewBatchID.rawValue.uuidString,
                        "candidateId": candidateID.rawValue.uuidString,
                        "receiptId": "must-not-leave-the-server",
                    ]],
                ],
                expectedVaultID: try XCTUnwrap(OwnerTruthVaultID(lease.vaultId))
            )
        )
        XCTAssertThrowsError(
            try OwnerTruthInterviewCandidateMemoryActivationInbox(
                backendJSONObject: [
                    "schemaVersion": OwnerTruthInterviewCandidateMemoryActivationInbox.schemaVersion,
                    "vaultId": lease.vaultId,
                    "items": [
                        [
                            "reviewBatchId": reviewBatchID.rawValue.uuidString,
                            "candidateId": candidateID.rawValue.uuidString,
                        ],
                        [
                            "reviewBatchId": reviewBatchID.rawValue.uuidString,
                            "candidateId": candidateID.rawValue.uuidString,
                        ],
                    ],
                ],
                expectedVaultID: try XCTUnwrap(OwnerTruthVaultID(lease.vaultId))
            )
        )
    }

    func testInterviewCandidateMemoryActivationInboxBindsAndPermitsOnlyBoundRecoveryActivation() throws {
        let (runtime, lease) = try makeActiveRuntime()
        let reviewBatchID = recordID("00000000-0000-0000-0000-000000000077")
        let candidateID = recordID("00000000-0000-0000-0000-000000000078")
        let rawInbox = try interviewCandidateMemoryActivationInbox(
            vaultID: lease.vaultId,
            handles: [(reviewBatchID: reviewBatchID, candidateID: candidateID)]
        )
        let reader = InterviewCandidateMemoryActivationInboxClientSpy()
        reader.readResult = .success(rawInbox)
        let inboxUseCase = OwnerTruthInterviewCandidateMemoryActivationInboxUseCase(
            accountLease: lease,
            client: reader,
            accountLeaseRuntime: runtime,
            releasePolicyAvailable: { true }
        )

        inboxUseCase.send(.refresh)

        let boundInbox = try XCTUnwrap(inboxUseCase.viewState.inbox)
        let item = try XCTUnwrap(boundInbox.items.first)
        XCTAssertEqual(inboxUseCase.viewState.phase, .ready)
        XCTAssertTrue(boundInbox.isBound(to: lease))

        let activationClient = InterviewCandidateMemoryActivationClientSpy()
        let expectedCommand = try OwnerTruthInterviewCandidateMemoryActivationCommand(
            commandID: "recovery-activation-command",
            reviewBatchID: reviewBatchID,
            candidateID: candidateID
        )
        activationClient.result = .success(try interviewCandidateMemoryActivationResult(
            command: expectedCommand,
            outcome: .created
        ))
        let recoveryActivation = OwnerTruthInterviewCandidateMemoryActivationUseCase(
            accountLease: lease,
            activationInbox: boundInbox,
            item: item,
            client: activationClient,
            accountLeaseRuntime: runtime,
            releasePolicyAvailable: { true },
            commandIDFactory: { "recovery-activation-command" }
        )

        recoveryActivation.send(.activate)

        XCTAssertEqual(activationClient.requestedCommands, [expectedCommand])
        XCTAssertEqual(recoveryActivation.viewState.phase, .activated)
        XCTAssertEqual(recoveryActivation.viewState.notice, .activated)

        let unboundActivation = OwnerTruthInterviewCandidateMemoryActivationUseCase(
            accountLease: lease,
            activationInbox: rawInbox,
            item: item,
            client: activationClient,
            accountLeaseRuntime: runtime,
            releasePolicyAvailable: { true }
        )
        unboundActivation.send(.activate)

        XCTAssertEqual(unboundActivation.viewState.phase, .failed)
        XCTAssertEqual(unboundActivation.viewState.notice, .invalidEligibility)
        XCTAssertEqual(activationClient.requestedCommands, [expectedCommand])
    }

    func testInterviewCandidateMemoryProjectionRecoveryInboxDecodesOnlyRebuildingOpaqueHandles() throws {
        let (_, lease) = try makeActiveRuntime()
        let reviewBatchID = recordID("00000000-0000-0000-0000-000000000079")
        let candidateID = recordID("00000000-0000-0000-0000-000000000080")

        let inbox = try interviewCandidateMemoryProjectionRecoveryInbox(
            vaultID: lease.vaultId,
            handles: [(reviewBatchID: reviewBatchID, candidateID: candidateID)]
        )

        XCTAssertEqual(inbox.vaultID.rawValue, lease.vaultId)
        XCTAssertEqual(inbox.items.map(\.state), [.rebuilding])
        XCTAssertThrowsError(
            try OwnerTruthInterviewCandidateMemoryProjectionRecoveryInbox(
                backendJSONObject: [
                    "schemaVersion": OwnerTruthInterviewCandidateMemoryProjectionRecoveryInbox.schemaVersion,
                    "vaultId": lease.vaultId,
                    "items": [[
                        "reviewBatchId": reviewBatchID.rawValue.uuidString,
                        "candidateId": candidateID.rawValue.uuidString,
                        "state": "rebuilding",
                        "memoryVersionId": "must-not-leave-the-server",
                    ]],
                ],
                expectedVaultID: try XCTUnwrap(OwnerTruthVaultID(lease.vaultId))
            )
        )
        XCTAssertThrowsError(
            try OwnerTruthInterviewCandidateMemoryProjectionRecoveryInbox(
                backendJSONObject: [
                    "schemaVersion": OwnerTruthInterviewCandidateMemoryProjectionRecoveryInbox.schemaVersion,
                    "vaultId": lease.vaultId,
                    "items": [[
                        "reviewBatchId": reviewBatchID.rawValue.uuidString,
                        "candidateId": candidateID.rawValue.uuidString,
                        "state": "retryWait",
                    ]],
                ],
                expectedVaultID: try XCTUnwrap(OwnerTruthVaultID(lease.vaultId))
            )
        )
    }

    func testInterviewCandidateMemoryProjectionRecoveryInboxIsLeaseBoundAndFailsClosedWithoutReleasePolicy() throws {
        let (runtime, lease) = try makeActiveRuntime()
        let reviewBatchID = recordID("00000000-0000-0000-0000-000000000081")
        let candidateID = recordID("00000000-0000-0000-0000-000000000082")
        let client = InterviewCandidateMemoryProjectionRecoveryInboxClientSpy()
        client.readResult = .success(try interviewCandidateMemoryProjectionRecoveryInbox(
            vaultID: lease.vaultId,
            handles: [(reviewBatchID: reviewBatchID, candidateID: candidateID)]
        ))
        let useCase = OwnerTruthInterviewCandidateMemoryProjectionRecoveryInboxUseCase(
            accountLease: lease,
            client: client,
            accountLeaseRuntime: runtime,
            releasePolicyAvailable: { true }
        )

        useCase.send(.refresh)

        let boundInbox = try XCTUnwrap(useCase.viewState.inbox)
        XCTAssertEqual(useCase.viewState.phase, .ready)
        XCTAssertTrue(boundInbox.isBound(to: lease))
        XCTAssertEqual(boundInbox.items.count, 1)

        let deniedClient = InterviewCandidateMemoryProjectionRecoveryInboxClientSpy()
        let deniedUseCase = OwnerTruthInterviewCandidateMemoryProjectionRecoveryInboxUseCase(
            accountLease: lease,
            client: deniedClient,
            accountLeaseRuntime: runtime,
            releasePolicyAvailable: { false }
        )
        deniedUseCase.send(.refresh)

        XCTAssertEqual(deniedUseCase.viewState.phase, .unavailable)
        XCTAssertEqual(deniedUseCase.viewState.notice, .releasePolicyDisabled)
        XCTAssertEqual(deniedClient.requestCount, 0)
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

    func testInterviewCandidateConfirmationUseCaseBindsSuccessfulReadToAccountLease() throws {
        let (runtime, lease) = try makeActiveRuntime()
        let reviewBatchID = recordID("00000000-0000-0000-0000-000000000077")
        let client = InterviewCandidateConfirmationClientSpy()
        client.readResult = .success(try interviewCandidateConfirmation(
            vaultID: lease.vaultId,
            reviewBatchID: reviewBatchID,
            batchCandidateID: recordID("00000000-0000-0000-0000-000000000078"),
            singleCandidateID: recordID("00000000-0000-0000-0000-000000000079")
        ))
        let useCase = OwnerTruthInterviewCandidateConfirmationUseCase(
            accountLease: lease,
            reviewBatchID: reviewBatchID,
            client: client,
            accountLeaseRuntime: runtime,
            releasePolicyAvailable: { true }
        )

        useCase.send(.refresh)

        XCTAssertEqual(useCase.viewState.phase, .ready)
        XCTAssertTrue(try XCTUnwrap(useCase.viewState.confirmation).isBound(to: lease))
    }

    func testInterviewCandidateProposalStatusDecodesOnlyCoherentValueFreeContract() throws {
        let vaultID = "vault-owner-a"
        let reviewBatchID = recordID("00000000-0000-0000-0000-000000000118")
        let status = try OwnerTruthInterviewCandidateProposalStatus(
            backendJSONObject: interviewCandidateProposalStatusPayload(
                vaultID: vaultID,
                reviewBatchID: reviewBatchID
            ),
            expectedVaultID: try XCTUnwrap(OwnerTruthVaultID(vaultID)),
            expectedReviewBatchID: reviewBatchID
        )

        XCTAssertEqual(status.reviewBatchState, .acknowledged)
        XCTAssertEqual(status.candidateProposalState, .admitted)
        XCTAssertEqual(status.candidateExtractionState, .requested)
        XCTAssertEqual(status.candidateReviewState, .notReady)

        var privateFieldPayload = interviewCandidateProposalStatusPayload(
            vaultID: vaultID,
            reviewBatchID: reviewBatchID
        )
        privateFieldPayload["sourceId"] = "00000000-0000-0000-0000-000000000119"
        XCTAssertThrowsError(
            try OwnerTruthInterviewCandidateProposalStatus(
                backendJSONObject: privateFieldPayload,
                expectedVaultID: try XCTUnwrap(OwnerTruthVaultID(vaultID)),
                expectedReviewBatchID: reviewBatchID
            )
        )

        var incoherentPayload = interviewCandidateProposalStatusPayload(
            vaultID: vaultID,
            reviewBatchID: reviewBatchID
        )
        incoherentPayload["candidateReview"] = ["status": "reviewReady"]
        XCTAssertThrowsError(
            try OwnerTruthInterviewCandidateProposalStatus(
                backendJSONObject: incoherentPayload,
                expectedVaultID: try XCTUnwrap(OwnerTruthVaultID(vaultID)),
                expectedReviewBatchID: reviewBatchID
            )
        )
    }

    func testInterviewCandidateProposalStatusUseCaseFailsClosedWithoutReleasePolicy() throws {
        let (runtime, lease) = try makeActiveRuntime()
        let client = InterviewCandidateProposalStatusClientSpy()
        let useCase = OwnerTruthInterviewCandidateProposalStatusUseCase(
            accountLease: lease,
            reviewBatchID: recordID("00000000-0000-0000-0000-000000000120"),
            client: client,
            accountLeaseRuntime: runtime,
            releasePolicyAvailable: { false }
        )

        useCase.send(.refresh)

        XCTAssertEqual(useCase.viewState.phase, .unavailable)
        XCTAssertEqual(useCase.viewState.notice, .releasePolicyDisabled)
        XCTAssertEqual(client.requestCount, 0)
    }

    func testInterviewCandidateProposalStatusUseCaseDiscardsDeferredReadAfterAccountChange() throws {
        let (runtime, lease) = try makeActiveRuntime()
        let reviewBatchID = recordID("00000000-0000-0000-0000-000000000121")
        let client = InterviewCandidateProposalStatusClientSpy()
        client.deferRead = true
        let useCase = OwnerTruthInterviewCandidateProposalStatusUseCase(
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
        client.completeDeferredRead(.success(try interviewCandidateProposalStatus(
            vaultID: lease.vaultId,
            reviewBatchID: reviewBatchID
        )))

        XCTAssertEqual(useCase.viewState.phase, .unavailable)
        XCTAssertEqual(useCase.viewState.notice, .staleAccountLease)
        XCTAssertNil(useCase.viewState.status)
    }

    func testInterviewCandidateProposalStatusUseCaseBindsSuccessfulReadToAccountLease() throws {
        let (runtime, lease) = try makeActiveRuntime()
        let reviewBatchID = recordID("00000000-0000-0000-0000-000000000122")
        let client = InterviewCandidateProposalStatusClientSpy()
        client.readResult = .success(try interviewCandidateProposalStatus(
            vaultID: lease.vaultId,
            reviewBatchID: reviewBatchID
        ))
        let useCase = OwnerTruthInterviewCandidateProposalStatusUseCase(
            accountLease: lease,
            reviewBatchID: reviewBatchID,
            client: client,
            accountLeaseRuntime: runtime,
            releasePolicyAvailable: { true }
        )

        useCase.send(.refresh)

        XCTAssertEqual(useCase.viewState.phase, .ready)
        XCTAssertTrue(try XCTUnwrap(useCase.viewState.status).isBound(to: lease))
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
        ).bound(to: lease)
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
        ).bound(to: lease)
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
        ).bound(to: lease)
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
        ).bound(to: lease)
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

    func testInterviewCandidateConfirmationActionUseCaseRejectsDifferentLeaseWithSameVault() throws {
        let (runtime, originalLease) = try makeActiveRuntime()
        let reviewBatchID = recordID("00000000-0000-0000-0000-000000000093")
        let batchCandidateID = recordID("00000000-0000-0000-0000-000000000094")
        let confirmation = try interviewCandidateConfirmation(
            vaultID: originalLease.vaultId,
            reviewBatchID: reviewBatchID,
            batchCandidateID: batchCandidateID,
            singleCandidateID: recordID("00000000-0000-0000-0000-000000000095")
        ).bound(to: originalLease)
        runtime.publish(session: accountSession(
            subjectId: "owner-b",
            vaultId: originalLease.vaultId,
            generation: 2,
            generationID: UUID(uuidString: "00000000-0000-0000-0000-000000000102")!
        ))
        let replacementLease = try XCTUnwrap(runtime.capture(forSubjectId: "owner-b"))
        let client = InterviewCandidateConfirmationActionClientSpy()
        let useCase = OwnerTruthInterviewCandidateConfirmationActionUseCase(
            accountLease: replacementLease,
            confirmation: confirmation,
            client: client,
            confirmationReader: InterviewCandidateConfirmationClientSpy(),
            accountLeaseRuntime: runtime,
            releasePolicyAvailable: { true }
        )

        useCase.send(.confirmBatch(candidateIDs: [batchCandidateID]))

        XCTAssertEqual(useCase.viewState.phase, .unavailable)
        XCTAssertEqual(useCase.viewState.notice, .staleAccountLease)
        XCTAssertTrue(client.requestedCommands.isEmpty)
    }

    func testInterviewCandidateConfirmationActionUseCaseRejectsAuthorityCompositionDrift() throws {
        let (runtime, lease) = try makeActiveRuntime()
        let reviewBatchID = recordID("00000000-0000-0000-0000-000000000096")
        let batchCandidateID = recordID("00000000-0000-0000-0000-000000000097")
        let singleCandidateID = recordID("00000000-0000-0000-0000-000000000098")
        let confirmation = try interviewCandidateConfirmation(
            vaultID: lease.vaultId,
            reviewBatchID: reviewBatchID,
            batchCandidateID: batchCandidateID,
            singleCandidateID: singleCandidateID
        ).bound(to: lease)
        let client = InterviewCandidateConfirmationActionClientSpy()
        client.result = .success(try interviewCandidateConfirmationActionResult(
            reviewBatchID: reviewBatchID,
            candidateIDs: [batchCandidateID],
            commandID: "confirmation-authority-drift-command"
        ))
        let reader = InterviewCandidateConfirmationClientSpy()
        reader.readResult = .success(try reconciledInterviewCandidateConfirmation(
            vaultID: lease.vaultId,
            reviewBatchID: reviewBatchID,
            remainingSingleCandidateID: singleCandidateID,
            sourceVersion: 2
        ))
        let useCase = OwnerTruthInterviewCandidateConfirmationActionUseCase(
            accountLease: lease,
            confirmation: confirmation,
            client: client,
            confirmationReader: reader,
            accountLeaseRuntime: runtime,
            releasePolicyAvailable: { true },
            commandIDFactory: { "confirmation-authority-drift-command" }
        )

        useCase.send(.confirmBatch(candidateIDs: [batchCandidateID]))

        XCTAssertEqual(useCase.viewState.phase, .failed)
        XCTAssertEqual(useCase.viewState.notice, .reconciliationFailed)
        XCTAssertEqual(useCase.viewState.latestResult?.acceptedCandidateIDs, [batchCandidateID])
    }

    func testInterviewCandidateConfirmationSingleActionDecodesValueMinimizedResult() throws {
        let reviewBatchID = recordID("00000000-0000-0000-0000-000000000099")
        let candidateID = recordID("00000000-0000-0000-0000-000000000100")
        let command = try OwnerTruthInterviewCandidateConfirmationSingleCommand(
            commandID: "confirmation-single-action-ios-001",
            reviewBatchID: reviewBatchID,
            candidateID: candidateID,
            expectedCandidateVersion: 1,
            action: .accept
        )
        let result = try OwnerTruthInterviewCandidateConfirmationSingleResult(
            backendJSONObject: [
                "schemaVersion": OwnerTruthInterviewCandidateConfirmationSingleResult.schemaVersion,
                "status": OwnerTruthCommandOutcome.created.rawValue,
                "batchDecisionId": "00000000-0000-0000-0000-000000000101",
                "reviewBatchId": reviewBatchID.rawValue.uuidString,
                "candidateId": candidateID.rawValue.uuidString,
                "decision": OwnerTruthCandidateDecision.accepted.rawValue,
                "memoryActivation": [
                    "status": OwnerTruthMemoryActivationOutcome.notApplicable.rawValue,
                    "memoryVersionCreated": false,
                ],
            ],
            expectedCommand: command
        )

        XCTAssertEqual(result.candidateID, candidateID)
        XCTAssertEqual(result.decision, .accepted)
        XCTAssertFalse(result.memoryVersionCreated)
        XCTAssertThrowsError(
            try OwnerTruthInterviewCandidateConfirmationSingleResult(
                backendJSONObject: [
                    "schemaVersion": OwnerTruthInterviewCandidateConfirmationSingleResult.schemaVersion,
                    "status": OwnerTruthCommandOutcome.created.rawValue,
                    "batchDecisionId": "00000000-0000-0000-0000-000000000101",
                    "reviewBatchId": reviewBatchID.rawValue.uuidString,
                    "candidateId": candidateID.rawValue.uuidString,
                    "decision": OwnerTruthCandidateDecision.accepted.rawValue,
                    "receipt": ["mustNotAppear": true],
                    "memoryActivation": [
                        "status": OwnerTruthMemoryActivationOutcome.notApplicable.rawValue,
                        "memoryVersionCreated": false,
                    ],
                ],
                expectedCommand: command
            )
        )
    }

    func testInterviewCandidateConfirmationSingleActionUseCaseFailsClosedAndRejectsBatchCandidate() throws {
        let (runtime, lease) = try makeActiveRuntime()
        let reviewBatchID = recordID("00000000-0000-0000-0000-000000000102")
        let batchCandidateID = recordID("00000000-0000-0000-0000-000000000103")
        let singleCandidateID = recordID("00000000-0000-0000-0000-000000000104")
        let confirmation = try interviewCandidateConfirmation(
            vaultID: lease.vaultId,
            reviewBatchID: reviewBatchID,
            batchCandidateID: batchCandidateID,
            singleCandidateID: singleCandidateID
        ).bound(to: lease)
        let client = InterviewCandidateConfirmationSingleActionClientSpy()
        let reader = InterviewCandidateConfirmationClientSpy()
        let disabled = OwnerTruthInterviewCandidateConfirmationSingleActionUseCase(
            accountLease: lease,
            confirmation: confirmation,
            client: client,
            confirmationReader: reader,
            accountLeaseRuntime: runtime,
            releasePolicyAvailable: { false }
        )

        disabled.send(.accept(candidateID: singleCandidateID))

        XCTAssertEqual(disabled.viewState.phase, .unavailable)
        XCTAssertEqual(disabled.viewState.notice, .releasePolicyDisabled)
        XCTAssertTrue(client.requestedCommands.isEmpty)

        let enabled = OwnerTruthInterviewCandidateConfirmationSingleActionUseCase(
            accountLease: lease,
            confirmation: confirmation,
            client: client,
            confirmationReader: reader,
            accountLeaseRuntime: runtime,
            releasePolicyAvailable: { true }
        )
        enabled.send(.accept(candidateID: batchCandidateID))

        XCTAssertEqual(enabled.viewState.phase, .failed)
        XCTAssertEqual(enabled.viewState.notice, .invalidSelection)
        XCTAssertTrue(client.requestedCommands.isEmpty)
    }

    func testInterviewCandidateConfirmationSingleActionUseCaseReconcilesTerminalDecision() throws {
        let (runtime, lease) = try makeActiveRuntime()
        let reviewBatchID = recordID("00000000-0000-0000-0000-000000000105")
        let batchCandidateID = recordID("00000000-0000-0000-0000-000000000106")
        let singleCandidateID = recordID("00000000-0000-0000-0000-000000000107")
        let confirmation = try interviewCandidateConfirmation(
            vaultID: lease.vaultId,
            reviewBatchID: reviewBatchID,
            batchCandidateID: batchCandidateID,
            singleCandidateID: singleCandidateID
        ).bound(to: lease)
        let client = InterviewCandidateConfirmationSingleActionClientSpy()
        let expectedCommand = try OwnerTruthInterviewCandidateConfirmationSingleCommand(
            commandID: "confirmation-single-reconciliation-command",
            reviewBatchID: reviewBatchID,
            candidateID: singleCandidateID,
            expectedCandidateVersion: 1,
            action: .accept
        )
        client.result = .success(try OwnerTruthInterviewCandidateConfirmationSingleResult(
            backendJSONObject: [
                "schemaVersion": OwnerTruthInterviewCandidateConfirmationSingleResult.schemaVersion,
                "status": OwnerTruthCommandOutcome.created.rawValue,
                "batchDecisionId": "00000000-0000-0000-0000-000000000108",
                "reviewBatchId": reviewBatchID.rawValue.uuidString,
                "candidateId": singleCandidateID.rawValue.uuidString,
                "decision": OwnerTruthCandidateDecision.accepted.rawValue,
                "memoryActivation": [
                    "status": OwnerTruthMemoryActivationOutcome.notApplicable.rawValue,
                    "memoryVersionCreated": false,
                ],
            ],
            expectedCommand: expectedCommand
        ))
        let reader = InterviewCandidateConfirmationClientSpy()
        reader.readResult = .success(try interviewCandidateConfirmation(
            vaultID: lease.vaultId,
            reviewBatchID: reviewBatchID,
            batchCandidateID: batchCandidateID,
            singleCandidateID: recordID("00000000-0000-0000-0000-000000000109")
        ))
        let useCase = OwnerTruthInterviewCandidateConfirmationSingleActionUseCase(
            accountLease: lease,
            confirmation: confirmation,
            client: client,
            confirmationReader: reader,
            accountLeaseRuntime: runtime,
            releasePolicyAvailable: { true },
            commandIDFactory: { "confirmation-single-reconciliation-command" }
        )

        useCase.send(.accept(candidateID: singleCandidateID))

        XCTAssertEqual(client.requestedCommands.map(\.commandID), ["confirmation-single-reconciliation-command"])
        XCTAssertEqual(reader.requestCount, 1)
        XCTAssertEqual(useCase.viewState.phase, .confirmed)
        XCTAssertEqual(useCase.viewState.notice, .singleAccepted)
        XCTAssertEqual(useCase.viewState.latestResult?.candidateID, singleCandidateID)
    }

    func testInterviewCandidateMemoryActivationDecodesValueMinimizedResult() throws {
        let reviewBatchID = recordID("00000000-0000-0000-0000-000000000110")
        let candidateID = recordID("00000000-0000-0000-0000-000000000111")
        let command = try OwnerTruthInterviewCandidateMemoryActivationCommand(
            commandID: "confirmation-memory-activation-ios-001",
            reviewBatchID: reviewBatchID,
            candidateID: candidateID
        )
        XCTAssertEqual(command.backendPayload.keys.sorted(), ["commandId"])
        let result = try interviewCandidateMemoryActivationResult(
            command: command,
            outcome: .created
        )

        XCTAssertEqual(result.reviewBatchID, reviewBatchID)
        XCTAssertEqual(result.candidateID, candidateID)
        XCTAssertEqual(result.memoryActivationOutcome, .created)
        XCTAssertTrue(result.projectionRebuildRequested)
        XCTAssertThrowsError(
            try OwnerTruthInterviewCandidateMemoryActivationResult(
                backendJSONObject: [
                    "schemaVersion": OwnerTruthInterviewCandidateMemoryActivationResult.schemaVersion,
                    "status": OwnerTruthCommandOutcome.created.rawValue,
                    "reviewBatchId": reviewBatchID.rawValue.uuidString,
                    "candidateId": candidateID.rawValue.uuidString,
                    "memoryVersionId": "must-not-appear",
                    "memoryActivation": [
                        "status": OwnerTruthMemoryActivationOutcome.created.rawValue,
                        "memoryVersionCreated": true,
                    ],
                    "projectionRebuildRequested": true,
                ],
                expectedCommand: command
            )
        )
    }

    func testInterviewCandidateMemoryActivationUseCaseFailsClosedForPolicyAndEligibility() throws {
        let (runtime, lease) = try makeActiveRuntime()
        let reviewBatchID = recordID("00000000-0000-0000-0000-000000000112")
        let batchCandidateID = recordID("00000000-0000-0000-0000-000000000113")
        let singleCandidateID = recordID("00000000-0000-0000-0000-000000000114")
        let confirmation = try interviewCandidateConfirmation(
            vaultID: lease.vaultId,
            reviewBatchID: reviewBatchID,
            batchCandidateID: batchCandidateID,
            singleCandidateID: singleCandidateID
        ).bound(to: lease)
        let eligibility = OwnerTruthInterviewCandidateMemoryActivationEligibility.batchConfirmation(
            try interviewCandidateConfirmationActionResult(
                reviewBatchID: reviewBatchID,
                candidateIDs: [batchCandidateID],
                commandID: "confirmation-memory-activation-batch"
            )
        )
        let client = InterviewCandidateMemoryActivationClientSpy()
        let disabled = OwnerTruthInterviewCandidateMemoryActivationUseCase(
            accountLease: lease,
            confirmation: confirmation,
            eligibility: eligibility,
            candidateID: batchCandidateID,
            client: client,
            accountLeaseRuntime: runtime,
            releasePolicyAvailable: { false }
        )

        disabled.send(.activate)

        XCTAssertEqual(disabled.viewState.phase, .unavailable)
        XCTAssertEqual(disabled.viewState.notice, .releasePolicyDisabled)
        XCTAssertTrue(client.requestedCommands.isEmpty)

        let invalid = OwnerTruthInterviewCandidateMemoryActivationUseCase(
            accountLease: lease,
            confirmation: confirmation,
            eligibility: eligibility,
            candidateID: singleCandidateID,
            client: client,
            accountLeaseRuntime: runtime,
            releasePolicyAvailable: { true }
        )
        invalid.send(.activate)

        XCTAssertEqual(invalid.viewState.phase, .failed)
        XCTAssertEqual(invalid.viewState.notice, .invalidEligibility)
        XCTAssertTrue(client.requestedCommands.isEmpty)
    }

    func testInterviewCandidateMemoryActivationUseCaseRetriesWithStableCommandID() throws {
        let (runtime, lease) = try makeActiveRuntime()
        let reviewBatchID = recordID("00000000-0000-0000-0000-000000000115")
        let batchCandidateID = recordID("00000000-0000-0000-0000-000000000116")
        let singleCandidateID = recordID("00000000-0000-0000-0000-000000000117")
        let confirmation = try interviewCandidateConfirmation(
            vaultID: lease.vaultId,
            reviewBatchID: reviewBatchID,
            batchCandidateID: batchCandidateID,
            singleCandidateID: singleCandidateID
        ).bound(to: lease)
        let eligibility = OwnerTruthInterviewCandidateMemoryActivationEligibility.batchConfirmation(
            try interviewCandidateConfirmationActionResult(
                reviewBatchID: reviewBatchID,
                candidateIDs: [batchCandidateID],
                commandID: "confirmation-memory-activation-result"
            )
        )
        let client = InterviewCandidateMemoryActivationClientSpy()
        client.result = .failure(InterviewCandidateMemoryActivationClientSpyError.missingActivationResult)
        let useCase = OwnerTruthInterviewCandidateMemoryActivationUseCase(
            accountLease: lease,
            confirmation: confirmation,
            eligibility: eligibility,
            candidateID: batchCandidateID,
            client: client,
            accountLeaseRuntime: runtime,
            releasePolicyAvailable: { true },
            commandIDFactory: { "stable-memory-activation-command" }
        )

        useCase.send(.activate)
        XCTAssertEqual(useCase.viewState.phase, .failed)
        client.result = .success(try interviewCandidateMemoryActivationResult(
            command: try OwnerTruthInterviewCandidateMemoryActivationCommand(
                commandID: "stable-memory-activation-command",
                reviewBatchID: reviewBatchID,
                candidateID: batchCandidateID
            ),
            outcome: .deduplicated
        ))

        useCase.send(.activate)

        XCTAssertEqual(client.requestedCommands.map(\.commandID), [
            "stable-memory-activation-command",
            "stable-memory-activation-command",
        ])
        XCTAssertEqual(useCase.viewState.phase, .activated)
        XCTAssertEqual(useCase.viewState.notice, .activated)
        XCTAssertEqual(useCase.viewState.latestResult?.outcome, .deduplicated)
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

    func testInterviewOrchestrationDecodesExactValueFreeEnvelopeAndSignalPayload() throws {
        let (_, lease) = try makeActiveRuntime()
        let orchestration = try interviewOrchestration(
            vaultID: lease.vaultId,
            action: .pause,
            reasonCode: "topicChanged",
            nextSessionState: .paused
        )
        let signals = OwnerTruthInterviewOrchestrationSignals(
            topicIncomplete: true,
            needsClarification: true,
            userChangedTopic: false,
            userReopenedDoNotAskTopic: true,
            isSensitive: false,
            acceptedBroadenRecommendation: true
        )

        XCTAssertEqual(orchestration.vaultID.rawValue, lease.vaultId)
        XCTAssertEqual(orchestration.decision.action, .pause)
        XCTAssertEqual(orchestration.decision.reasonCode, "topicChanged")
        XCTAssertEqual(orchestration.decision.nextSessionState, .paused)
        XCTAssertEqual(orchestration.persistedSession.lifecycle, .active)
        XCTAssertEqual(orchestration.persistedSession.ownerTurnCount, 3)
        XCTAssertEqual(
            Set(signals.backendPayload.keys),
            Set([
                "topicIncomplete",
                "needsClarification",
                "userChangedTopic",
                "userReopenedDoNotAskTopic",
                "isSensitive",
                "acceptedBroadenRecommendation",
            ])
        )
        XCTAssertNil(signals.backendPayload["topicId"])
        XCTAssertNil(signals.backendPayload["topicText"])
        XCTAssertEqual(signals.backendPayload["userReopenedDoNotAskTopic"] as? Bool, true)

        XCTAssertThrowsError(
            try OwnerTruthInterviewOrchestrationRead(
                backendJSONObject: [
                    "schemaVersion": OwnerTruthInterviewOrchestrationRead.schemaVersion,
                    "vaultId": lease.vaultId,
                    "orchestration": [
                        "schemaVersion": OwnerTruthInterviewOrchestrationRead.orchestrationSchemaVersion,
                        "policySchemaVersion": OwnerTruthInterviewOrchestrationRead.policySchemaVersion,
                        "decision": [:],
                        "persistedSession": [:],
                        "transientSignals": OwnerTruthInterviewOrchestrationRead.transientSignalsDescriptor,
                        "privateTopicText": "不能进入 QA 读取合同",
                    ],
                ],
                expectedVaultID: try XCTUnwrap(OwnerTruthVaultID(lease.vaultId))
            )
        )
    }

    func testInterviewOrchestrationUseCaseDiscardsDeferredReadAfterAccountChange() throws {
        let (runtime, lease) = try makeActiveRuntime()
        let client = InterviewOrchestrationClientSpy()
        client.deferRead = true
        let useCase = OwnerTruthInterviewOrchestrationUseCase(
            accountLease: lease,
            sessionID: recordID("00000000-0000-0000-0000-000000000068"),
            client: client,
            accountLeaseRuntime: runtime,
            qaGateEnabled: { true }
        )
        let signals = OwnerTruthInterviewOrchestrationSignals(userChangedTopic: true)

        useCase.send(.refresh(signals))
        runtime.publish(session: accountSession(
            subjectId: "owner-b",
            vaultId: "vault-b",
            generation: 2,
            generationID: UUID(uuidString: "00000000-0000-0000-0000-000000000102")!
        ))
        client.completeDeferredRead(.success(try interviewOrchestration(
            vaultID: lease.vaultId,
            action: .pause,
            reasonCode: "topicChanged",
            nextSessionState: .paused
        )))

        XCTAssertEqual(client.requestCount, 1)
        XCTAssertEqual(client.lastSignals, signals)
        XCTAssertEqual(useCase.viewState.phase, .unavailable)
        XCTAssertEqual(useCase.viewState.notice, .staleAccountLease)
        XCTAssertNil(useCase.viewState.orchestration)
    }

    func testInterviewOrchestrationUseCaseFailsClosedWhenQAGateIsDisabled() throws {
        let (runtime, lease) = try makeActiveRuntime()
        let client = InterviewOrchestrationClientSpy()
        let useCase = OwnerTruthInterviewOrchestrationUseCase(
            accountLease: lease,
            sessionID: recordID("00000000-0000-0000-0000-000000000069"),
            client: client,
            accountLeaseRuntime: runtime,
            qaGateEnabled: { false }
        )

        useCase.send(.refresh(OwnerTruthInterviewOrchestrationSignals()))

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

    func testInterviewBoundaryCommandUsesBoundedPayloadAndMatchesValueMinimizedReceipt() throws {
        let (_, lease) = try makeActiveRuntime()
        let vaultID = try XCTUnwrap(OwnerTruthVaultID(lease.vaultId))
        let command = try OwnerTruthInterviewBoundaryCommand(
            commandID: "natural-input-boundary",
            threadID: recordID("00000000-0000-0000-0000-000000000074"),
            sessionID: recordID("00000000-0000-0000-0000-000000000075"),
            expectedSessionVersion: 1,
            boundary: .cooldown
        )

        let payload = command.backendPayload
        XCTAssertEqual(Set(payload.keys), [
            "commandId",
            "threadId",
            "expectedSessionVersion",
            "boundary",
        ])
        XCTAssertEqual(payload["commandId"] as? String, command.commandID)
        XCTAssertEqual(payload["threadId"] as? String, command.threadID.rawValue.uuidString.lowercased())
        XCTAssertEqual(payload["expectedSessionVersion"] as? Int, 1)
        XCTAssertEqual(payload["boundary"] as? String, OwnerTruthInterviewSessionBoundary.cooldown.rawValue)

        let receipt = try interviewNaturalInputReceipt(vaultID: vaultID, boundary: command)
        XCTAssertTrue(receipt.matches(command))
        XCTAssertNil(receipt.messageID)
        XCTAssertNil(receipt.messageSequence)
        XCTAssertFalse(String(describing: receipt).contains("text"))

        let skipOnce = try OwnerTruthInterviewBoundaryCommand(
            commandID: "natural-input-boundary-skip-once",
            threadID: command.threadID,
            sessionID: command.sessionID,
            expectedSessionVersion: 2,
            boundary: .skipOnce
        )
        let skipOnceReceipt = try interviewNaturalInputReceipt(vaultID: vaultID, boundary: skipOnce)
        XCTAssertEqual(skipOnceReceipt.lifecycle, .active)
        XCTAssertTrue(skipOnceReceipt.matches(skipOnce))

        XCTAssertThrowsError(
            try OwnerTruthInterviewBoundaryCommand(
                commandID: "must-not-reopen",
                threadID: command.threadID,
                sessionID: command.sessionID,
                expectedSessionVersion: 1,
                boundary: .open
            )
        )
    }

    func testInterviewTopicSwitchCommandUsesValueFreePayloadAndMatchesPausedReceipt() throws {
        let (_, lease) = try makeActiveRuntime()
        let vaultID = try XCTUnwrap(OwnerTruthVaultID(lease.vaultId))
        let command = try OwnerTruthInterviewPauseForTopicSwitchCommand(
            commandID: "natural-input-topic-switch",
            threadID: recordID("00000000-0000-0000-0000-000000000078"),
            sessionID: recordID("00000000-0000-0000-0000-000000000079"),
            expectedThreadVersion: 2,
            expectedSessionVersion: 3
        )

        XCTAssertEqual(Set(command.backendPayload.keys), [
            "commandId",
            "threadId",
            "expectedThreadVersion",
            "expectedSessionVersion",
        ])
        XCTAssertEqual(command.backendPayload["commandId"] as? String, command.commandID)
        XCTAssertEqual(
            command.backendPayload["threadId"] as? String,
            command.threadID.rawValue.uuidString.lowercased()
        )
        XCTAssertEqual(command.backendPayload["expectedThreadVersion"] as? Int, 2)
        XCTAssertEqual(command.backendPayload["expectedSessionVersion"] as? Int, 3)
        XCTAssertFalse(String(describing: command.backendPayload).contains("topicId"))
        XCTAssertFalse(String(describing: command.backendPayload).contains("text"))

        let receipt = try interviewNaturalInputReceipt(vaultID: vaultID, topicSwitch: command)
        XCTAssertTrue(receipt.matches(command))
        XCTAssertEqual(receipt.lifecycle, .paused)
        XCTAssertEqual(receipt.boundary, .open)
        XCTAssertNil(receipt.messageID)
        XCTAssertNil(receipt.messageSequence)
    }

    func testInterviewRestoreCooldownCommandUsesValueFreePayloadAndMatchesActiveReceipt() throws {
        let (_, lease) = try makeActiveRuntime()
        let vaultID = try XCTUnwrap(OwnerTruthVaultID(lease.vaultId))
        let command = try OwnerTruthInterviewRestoreCooldownCommand(
            commandID: "natural-input-restore-cooldown",
            threadID: recordID("00000000-0000-0000-0000-000000000076"),
            sessionID: recordID("00000000-0000-0000-0000-000000000077"),
            expectedSessionVersion: 2
        )

        XCTAssertEqual(Set(command.backendPayload.keys), [
            "commandId",
            "threadId",
            "expectedSessionVersion",
        ])
        XCTAssertEqual(command.backendPayload["commandId"] as? String, command.commandID)
        XCTAssertEqual(
            command.backendPayload["threadId"] as? String,
            command.threadID.rawValue.uuidString.lowercased()
        )
        XCTAssertEqual(command.backendPayload["expectedSessionVersion"] as? Int, 2)
        XCTAssertFalse(String(describing: command.backendPayload).contains("cooldownUntil"))

        let receipt = try interviewNaturalInputReceipt(vaultID: vaultID, restoreCooldown: command)
        XCTAssertTrue(receipt.matches(command))
        XCTAssertEqual(receipt.lifecycle, .active)
        XCTAssertEqual(receipt.boundary, .open)
    }

    func testInterviewPacingCommandUsesValueFreePayloadAndMatchesActiveReceipt() throws {
        let (_, lease) = try makeActiveRuntime()
        let vaultID = try XCTUnwrap(OwnerTruthVaultID(lease.vaultId))
        let command = try OwnerTruthInterviewPacingCommand(
            commandID: "natural-input-pacing",
            threadID: recordID("00000000-0000-0000-0000-000000000080"),
            sessionID: recordID("00000000-0000-0000-0000-000000000081"),
            expectedSessionVersion: 2,
            event: .deepeningCompleted
        )

        XCTAssertEqual(Set(command.backendPayload.keys), [
            "commandId",
            "threadId",
            "expectedSessionVersion",
            "event",
        ])
        XCTAssertEqual(command.backendPayload["commandId"] as? String, command.commandID)
        XCTAssertEqual(
            command.backendPayload["threadId"] as? String,
            command.threadID.rawValue.uuidString.lowercased()
        )
        XCTAssertEqual(command.backendPayload["expectedSessionVersion"] as? Int, 2)
        XCTAssertEqual(command.backendPayload["event"] as? String, "deepeningCompleted")
        XCTAssertFalse(String(describing: command.backendPayload).contains("text"))
        XCTAssertFalse(String(describing: command.backendPayload).contains("topic"))

        let receipt = try interviewNaturalInputReceipt(vaultID: vaultID, pacing: command)
        XCTAssertTrue(receipt.matches(command))
        XCTAssertEqual(receipt.lifecycle, .active)
        XCTAssertEqual(receipt.boundary, .open)
        XCTAssertNil(receipt.messageID)
        XCTAssertNil(receipt.messageSequence)
    }

    func testInterviewNaturalInputUseCaseRecordsPacingWithLeaseFence() throws {
        let (runtime, lease) = try makeActiveRuntime()
        let vaultID = try XCTUnwrap(OwnerTruthVaultID(lease.vaultId))
        let client = InterviewNaturalInputClientSpy()
        client.startHandler = { command in
            Result { try self.interviewNaturalInputReceipt(vaultID: vaultID, start: command) }
        }
        client.pacingHandler = { command in
            Result { try self.interviewNaturalInputReceipt(vaultID: vaultID, pacing: command) }
        }
        let useCase = OwnerTruthInterviewNaturalInputUseCase(
            accountLease: lease,
            client: client,
            accountLeaseRuntime: runtime,
            qaGateEnabled: { true }
        )

        useCase.send(.start)
        let initialReceipt = try XCTUnwrap(useCase.viewState.latestReceipt)
        useCase.send(.recordPacing(.deepeningCompleted))

        let command = try XCTUnwrap(client.pacingCommand)
        XCTAssertEqual(command.threadID, initialReceipt.threadID)
        XCTAssertEqual(command.sessionID, initialReceipt.sessionID)
        XCTAssertEqual(command.expectedSessionVersion, initialReceipt.sessionVersion)
        XCTAssertEqual(command.event, .deepeningCompleted)
        XCTAssertEqual(useCase.viewState.phase, .ready)
        XCTAssertTrue(try XCTUnwrap(useCase.viewState.latestReceipt).matches(command))
    }

    func testInterviewNaturalInputUseCaseDiscardsDeferredPacingAfterAccountChange() throws {
        let (runtime, lease) = try makeActiveRuntime()
        let vaultID = try XCTUnwrap(OwnerTruthVaultID(lease.vaultId))
        let client = InterviewNaturalInputClientSpy()
        client.startHandler = { command in
            Result { try self.interviewNaturalInputReceipt(vaultID: vaultID, start: command) }
        }
        client.deferPacing = true
        let useCase = OwnerTruthInterviewNaturalInputUseCase(
            accountLease: lease,
            client: client,
            accountLeaseRuntime: runtime,
            qaGateEnabled: { true }
        )

        useCase.send(.start)
        useCase.send(.recordPacing(.deepeningCompleted))
        let command = try XCTUnwrap(client.pacingCommand)
        runtime.publish(session: accountSession(
            subjectId: "owner-b",
            vaultId: "vault-b",
            generation: 2,
            generationID: UUID(uuidString: "00000000-0000-0000-0000-000000000102")!
        ))
        client.completeDeferredPacing(.success(try interviewNaturalInputReceipt(
            vaultID: vaultID,
            pacing: command
        )))

        XCTAssertEqual(useCase.viewState.phase, .unavailable)
        XCTAssertEqual(useCase.viewState.notice, .staleAccountLease)
        XCTAssertNil(useCase.viewState.latestReceipt)
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

    func testInterviewNaturalInputUseCasePausesOldThreadAndStartsNewSession() throws {
        let (runtime, lease) = try makeActiveRuntime()
        let vaultID = try XCTUnwrap(OwnerTruthVaultID(lease.vaultId))
        let client = InterviewNaturalInputClientSpy()
        client.startHandler = { command in
            Result { try self.interviewNaturalInputReceipt(vaultID: vaultID, start: command) }
        }
        client.topicSwitchHandler = { command in
            Result { try self.interviewNaturalInputReceipt(vaultID: vaultID, topicSwitch: command) }
        }
        let useCase = OwnerTruthInterviewNaturalInputUseCase(
            accountLease: lease,
            client: client,
            accountLeaseRuntime: runtime,
            qaGateEnabled: { true }
        )

        useCase.send(.start)
        let oldReceipt = try XCTUnwrap(useCase.viewState.latestReceipt)
        useCase.send(.pauseForTopicSwitch)

        let pauseCommand = try XCTUnwrap(client.topicSwitchCommand)
        let newReceipt = try XCTUnwrap(useCase.viewState.latestReceipt)
        XCTAssertEqual(pauseCommand.threadID, oldReceipt.threadID)
        XCTAssertEqual(pauseCommand.sessionID, oldReceipt.sessionID)
        XCTAssertEqual(pauseCommand.expectedThreadVersion, oldReceipt.threadVersion)
        XCTAssertEqual(pauseCommand.expectedSessionVersion, oldReceipt.sessionVersion)
        XCTAssertEqual(client.startCommands.count, 2)
        XCTAssertNotEqual(newReceipt.threadID, oldReceipt.threadID)
        XCTAssertNotEqual(newReceipt.sessionID, oldReceipt.sessionID)
        XCTAssertEqual(newReceipt.lifecycle, .active)
        XCTAssertEqual(newReceipt.boundary, .open)
        XCTAssertEqual(useCase.viewState.phase, .ready)
    }

    func testInterviewNaturalInputUseCaseDiscardsDeferredTopicSwitchAfterAccountChange() throws {
        let (runtime, lease) = try makeActiveRuntime()
        let vaultID = try XCTUnwrap(OwnerTruthVaultID(lease.vaultId))
        let client = InterviewNaturalInputClientSpy()
        client.startHandler = { command in
            Result { try self.interviewNaturalInputReceipt(vaultID: vaultID, start: command) }
        }
        client.deferTopicSwitch = true
        let useCase = OwnerTruthInterviewNaturalInputUseCase(
            accountLease: lease,
            client: client,
            accountLeaseRuntime: runtime,
            qaGateEnabled: { true }
        )

        useCase.send(.start)
        useCase.send(.pauseForTopicSwitch)
        let command = try XCTUnwrap(client.topicSwitchCommand)
        runtime.publish(session: accountSession(
            subjectId: "owner-b",
            vaultId: "vault-b",
            generation: 2,
            generationID: UUID(uuidString: "00000000-0000-0000-0000-000000000102")!
        ))
        client.completeDeferredTopicSwitch(.success(try interviewNaturalInputReceipt(
            vaultID: vaultID,
            topicSwitch: command
        )))

        XCTAssertEqual(useCase.viewState.phase, .unavailable)
        XCTAssertEqual(useCase.viewState.notice, .staleAccountLease)
        XCTAssertNil(useCase.viewState.latestReceipt)
        XCTAssertEqual(client.startCommands.count, 1)
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

    func testInterviewNaturalInputUseCasePersistsBoundaryAndRefreshesPausedContinuation() throws {
        let (runtime, lease) = try makeActiveRuntime()
        let vaultID = try XCTUnwrap(OwnerTruthVaultID(lease.vaultId))
        let client = InterviewNaturalInputClientSpy()
        client.startHandler = { command in
            Result { try self.interviewNaturalInputReceipt(vaultID: vaultID, start: command) }
        }
        client.boundaryHandler = { command in
            Result { try self.interviewNaturalInputReceipt(vaultID: vaultID, boundary: command) }
        }
        client.continuationHandler = { _ in
            Result {
                try self.interviewNaturalInputContinuation(
                    vaultID: vaultID,
                    state: .paused,
                    canContinue: false,
                    canContinueLater: true
                )
            }
        }
        let useCase = OwnerTruthInterviewNaturalInputUseCase(
            accountLease: lease,
            client: client,
            accountLeaseRuntime: runtime,
            qaGateEnabled: { true }
        )

        useCase.send(.start)
        useCase.send(.setBoundary(.cooldown))

        XCTAssertEqual(client.boundaryCommand?.boundary, .cooldown)
        XCTAssertEqual(useCase.viewState.phase, .ready)
        XCTAssertEqual(useCase.viewState.latestReceipt?.boundary, .cooldown)
        XCTAssertEqual(useCase.viewState.latestReceipt?.lifecycle, .paused)
        XCTAssertEqual(useCase.viewState.continuation?.state, .paused)
        XCTAssertEqual(useCase.viewState.continuation?.canContinue, false)
        XCTAssertEqual(useCase.viewState.continuation?.canContinueLater, true)
    }

    func testInterviewNaturalInputUseCaseRestoresCooldownWithLeaseFence() throws {
        let (runtime, lease) = try makeActiveRuntime()
        let vaultID = try XCTUnwrap(OwnerTruthVaultID(lease.vaultId))
        let client = InterviewNaturalInputClientSpy()
        client.startHandler = { command in
            Result { try self.interviewNaturalInputReceipt(vaultID: vaultID, start: command) }
        }
        client.boundaryHandler = { command in
            Result { try self.interviewNaturalInputReceipt(vaultID: vaultID, boundary: command) }
        }
        client.restoreCooldownHandler = { command in
            Result { try self.interviewNaturalInputReceipt(vaultID: vaultID, restoreCooldown: command) }
        }
        client.continuationHandler = { _ in
            Result {
                try self.interviewNaturalInputContinuation(
                    vaultID: vaultID,
                    state: client.restoreCooldownCommand == nil ? .paused : .readyForNarrative,
                    canContinue: client.restoreCooldownCommand != nil,
                    canContinueLater: true
                )
            }
        }
        let useCase = OwnerTruthInterviewNaturalInputUseCase(
            accountLease: lease,
            client: client,
            accountLeaseRuntime: runtime,
            qaGateEnabled: { true }
        )

        useCase.send(.start)
        useCase.send(.setBoundary(.cooldown))
        XCTAssertEqual(useCase.viewState.latestReceipt?.boundary, .cooldown)

        useCase.send(.restoreCooldown)

        XCTAssertNotNil(client.restoreCooldownCommand)
        XCTAssertEqual(useCase.viewState.phase, .ready)
        XCTAssertEqual(useCase.viewState.latestReceipt?.boundary, .open)
        XCTAssertEqual(useCase.viewState.latestReceipt?.lifecycle, .active)
        XCTAssertTrue(useCase.viewState.continuation?.canContinue ?? false)
    }

    func testInterviewNaturalInputUseCaseDiscardsDeferredCooldownRestoreAfterAccountChange() throws {
        let (runtime, lease) = try makeActiveRuntime()
        let vaultID = try XCTUnwrap(OwnerTruthVaultID(lease.vaultId))
        let client = InterviewNaturalInputClientSpy()
        client.startHandler = { command in
            Result { try self.interviewNaturalInputReceipt(vaultID: vaultID, start: command) }
        }
        client.boundaryHandler = { command in
            Result { try self.interviewNaturalInputReceipt(vaultID: vaultID, boundary: command) }
        }
        client.deferRestoreCooldown = true
        let useCase = OwnerTruthInterviewNaturalInputUseCase(
            accountLease: lease,
            client: client,
            accountLeaseRuntime: runtime,
            qaGateEnabled: { true }
        )

        useCase.send(.start)
        useCase.send(.setBoundary(.cooldown))
        useCase.send(.restoreCooldown)
        let command = try XCTUnwrap(client.restoreCooldownCommand)
        runtime.publish(session: accountSession(
            subjectId: "owner-b",
            vaultId: "vault-b",
            generation: 2,
            generationID: UUID(uuidString: "00000000-0000-0000-0000-000000000102")!
        ))
        client.completeDeferredRestoreCooldown(.success(try interviewNaturalInputReceipt(
            vaultID: vaultID,
            restoreCooldown: command
        )))

        XCTAssertEqual(useCase.viewState.phase, .unavailable)
        XCTAssertEqual(useCase.viewState.notice, .staleAccountLease)
        XCTAssertNil(useCase.viewState.latestReceipt)
    }

    func testInterviewNaturalInputUseCaseBoundaryFailsClosedForOpenMismatchAndStaleCompletion() throws {
        let (runtime, lease) = try makeActiveRuntime()
        let vaultID = try XCTUnwrap(OwnerTruthVaultID(lease.vaultId))
        let client = InterviewNaturalInputClientSpy()
        client.startHandler = { command in
            Result { try self.interviewNaturalInputReceipt(vaultID: vaultID, start: command) }
        }
        let useCase = OwnerTruthInterviewNaturalInputUseCase(
            accountLease: lease,
            client: client,
            accountLeaseRuntime: runtime,
            qaGateEnabled: { true }
        )

        useCase.send(.start)
        let initialReceipt = try XCTUnwrap(useCase.viewState.latestReceipt)
        useCase.send(.setBoundary(.open))
        XCTAssertEqual(useCase.viewState.phase, .ready)
        XCTAssertEqual(useCase.viewState.notice, .invalidInput)
        XCTAssertEqual(useCase.viewState.latestReceipt, initialReceipt)
        XCTAssertNil(client.boundaryCommand)

        client.boundaryHandler = { command in
            Result {
                let mismatched = try OwnerTruthInterviewBoundaryCommand(
                    commandID: command.commandID,
                    threadID: command.threadID,
                    sessionID: command.sessionID,
                    expectedSessionVersion: command.expectedSessionVersion,
                    boundary: .doNotAsk
                )
                return try self.interviewNaturalInputReceipt(vaultID: vaultID, boundary: mismatched)
            }
        }
        useCase.send(.setBoundary(.cooldown))
        XCTAssertEqual(useCase.viewState.phase, .failed)
        XCTAssertEqual(useCase.viewState.notice, .contractMismatch)

        let retryClient = InterviewNaturalInputClientSpy()
        retryClient.startHandler = { command in
            Result { try self.interviewNaturalInputReceipt(vaultID: vaultID, start: command) }
        }
        retryClient.deferBoundary = true
        let retryUseCase = OwnerTruthInterviewNaturalInputUseCase(
            accountLease: lease,
            client: retryClient,
            accountLeaseRuntime: runtime,
            qaGateEnabled: { true }
        )
        retryUseCase.send(.start)
        retryUseCase.send(.setBoundary(.cooldown))
        runtime.publish(session: accountSession(
            subjectId: "owner-b",
            vaultId: "vault-b",
            generation: 2,
            generationID: UUID(uuidString: "00000000-0000-0000-0000-000000000102")!
        ))
        let deferredCommand = try XCTUnwrap(retryClient.boundaryCommand)
        retryClient.completeDeferredBoundary(.success(try interviewNaturalInputReceipt(
            vaultID: vaultID,
            boundary: deferredCommand
        )))

        XCTAssertEqual(retryUseCase.viewState.phase, .unavailable)
        XCTAssertEqual(retryUseCase.viewState.notice, .staleAccountLease)
        XCTAssertNil(retryUseCase.viewState.latestReceipt)
    }

    func testInterviewNaturalInputUseCaseRejectsSameLeaseReceiptFromDifferentThreadAndSession() throws {
        let (runtime, lease) = try makeActiveRuntime()
        let vaultID = try XCTUnwrap(OwnerTruthVaultID(lease.vaultId))
        let firstClient = InterviewNaturalInputClientSpy()
        let secondClient = InterviewNaturalInputClientSpy()
        firstClient.startHandler = { command in
            Result { try self.interviewNaturalInputReceipt(vaultID: vaultID, start: command) }
        }
        firstClient.boundaryHandler = { command in
            Result { try self.interviewNaturalInputReceipt(vaultID: vaultID, boundary: command) }
        }
        secondClient.startHandler = { command in
            Result { try self.interviewNaturalInputReceipt(vaultID: vaultID, start: command) }
        }
        let firstUseCase = OwnerTruthInterviewNaturalInputUseCase(
            accountLease: lease,
            client: firstClient,
            accountLeaseRuntime: runtime,
            qaGateEnabled: { true }
        )
        let secondUseCase = OwnerTruthInterviewNaturalInputUseCase(
            accountLease: lease,
            client: secondClient,
            accountLeaseRuntime: runtime,
            qaGateEnabled: { true }
        )

        firstUseCase.send(.start)
        secondUseCase.send(.start)
        let firstStartReceipt = try XCTUnwrap(firstUseCase.viewState.latestReceipt)
        let secondStartReceipt = try XCTUnwrap(secondUseCase.viewState.latestReceipt)
        XCTAssertEqual(firstStartReceipt.vaultID, secondStartReceipt.vaultID)
        XCTAssertNotEqual(firstStartReceipt.threadID, secondStartReceipt.threadID)
        XCTAssertNotEqual(firstStartReceipt.sessionID, secondStartReceipt.sessionID)

        firstUseCase.send(.setBoundary(.cooldown))
        let firstCooldownReceipt = try XCTUnwrap(firstUseCase.viewState.latestReceipt)
        XCTAssertEqual(firstCooldownReceipt.boundary, .cooldown)
        secondClient.boundaryHandler = { _ in .success(firstCooldownReceipt) }

        secondUseCase.send(.setBoundary(.cooldown))

        let secondBoundaryCommand = try XCTUnwrap(secondClient.boundaryCommand)
        XCTAssertFalse(firstCooldownReceipt.matches(secondBoundaryCommand))
        XCTAssertEqual(secondUseCase.viewState.phase, .failed)
        XCTAssertEqual(secondUseCase.viewState.notice, .contractMismatch)
        XCTAssertNil(secondUseCase.viewState.latestReceipt)
        XCTAssertNil(secondUseCase.viewState.continuation)
        XCTAssertEqual(firstUseCase.viewState.phase, .ready)
        XCTAssertEqual(firstUseCase.viewState.latestReceipt, firstCooldownReceipt)
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

    func testContextShadowBuildAcceptsDeterministicTextFallbackSelectionMode() throws {
        let (_, lease) = try makeActiveRuntime()
        let query = "自行车"
        var response = try contextShadowBuildResponse(for: lease, query: query)
        var shadow = try XCTUnwrap(response["contextShadow"] as? [String: Any])
        var request = try XCTUnwrap(shadow["request"] as? [String: Any])
        request["selectionMode"] = "deterministicTextFallback"
        shadow["request"] = request

        var selected = try XCTUnwrap(shadow["selectedContext"] as? [[String: Any]])
        selected[0]["reason"] = "confirmed_current_memory_version_query_match"
        var selectedRank = try XCTUnwrap(selected[0]["rank"] as? [String: Any])
        selectedRank["strategy"] = "deterministicTextFallback"
        selected[0]["rank"] = selectedRank
        shadow["selectedContext"] = selected

        var ranking = try XCTUnwrap(shadow["rankingTrace"] as? [[String: Any]])
        ranking[0]["reason"] = "confirmed_current_memory_version_query_match"
        var rankingRank = try XCTUnwrap(ranking[0]["rank"] as? [String: Any])
        rankingRank["strategy"] = "deterministicTextFallback"
        ranking[0]["rank"] = rankingRank
        shadow["rankingTrace"] = ranking
        response["contextShadow"] = shadow

        let build = try OwnerTruthContextShadowBuild(
            backendJSONObject: response,
            expectedVaultID: try XCTUnwrap(OwnerTruthVaultID(lease.vaultId)),
            expectedIntent: "echo_chat",
            expectedQuery: query,
            expectedSelectionMode: .deterministicTextFallback
        )

        XCTAssertEqual(build.request.selectionMode, .deterministicTextFallback)
        XCTAssertEqual(build.selectedContext[0].rank?.strategy, "deterministicTextFallback")
        XCTAssertEqual(build.traceSummary().selectionMode, .deterministicTextFallback)
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

    func testCorrectionResolutionCommandBindsPendingRequestAndReceiptIsValueFree() throws {
        let (_, lease) = try makeActiveRuntime()
        let answer = "纠正处理回执不得回显原回答。"
        let correctionText = "人物应更正为外祖父。"
        let correctedSummary = "小时候在院子里听外祖父讲故事"
        let answerReceipt = try verifiedAnswerCitationReceipt(
            for: lease,
            query: "请仅基于已确认记忆回答",
            answer: answer,
            commandID: "owner-truth-answer-citation-resolution-001"
        )
        let requestCommand = try OwnerTruthCorrectionRequestCommand(
            commandID: "owner-truth-correction-request-resolution-001",
            receipt: answerReceipt,
            citationID: try XCTUnwrap(answerReceipt.citations.first).citationID,
            correctionText: correctionText,
            reasonCode: "ownerReportedCorrection"
        )
        let requestReceipt = try OwnerTruthCorrectionRequestReceipt(
            backendJSONObject: correctionRequestReceiptResponse(for: requestCommand),
            expectedCommand: requestCommand
        )
        let command = try OwnerTruthCorrectionResolutionCommand(
            commandID: "owner-truth-correction-resolution-001",
            correctionRequestReceipt: requestReceipt,
            action: .correct,
            correctedValue: ["summary": .string(correctedSummary)],
            correctedValueSchemaVersion: "owner-truth-v1",
            reasonCode: "ownerConfirmedCorrection"
        )

        XCTAssertEqual(command.vaultID, try XCTUnwrap(OwnerTruthVaultID(lease.vaultId)))
        XCTAssertEqual(command.correctionRequestID, requestReceipt.correctionRequestID)
        XCTAssertEqual(command.candidateID, requestReceipt.candidateID)
        XCTAssertEqual(command.expectedCandidateVersion, requestReceipt.candidateVersion)
        XCTAssertEqual(command.expectedMemoryVersionID, requestReceipt.expectedMemoryVersionID)
        XCTAssertEqual(command.backendPayload["action"] as? String, "correct")
        XCTAssertEqual(
            (command.backendPayload["correctedValue"] as? [String: Any])?["summary"] as? String,
            correctedSummary
        )

        let receipt = try OwnerTruthCorrectionResolutionReceipt(
            backendJSONObject: correctionResolutionReceiptResponse(for: command),
            expectedCommand: command
        )

        XCTAssertEqual(receipt.outcome, .created)
        XCTAssertEqual(receipt.decision, .corrected)
        XCTAssertEqual(receipt.correctionRequestID, requestReceipt.correctionRequestID)
        XCTAssertEqual(receipt.candidateID, requestReceipt.candidateID)
        XCTAssertEqual(receipt.supersededMemoryVersionID, requestReceipt.expectedMemoryVersionID)
        XCTAssertNotNil(receipt.replacementMemoryVersionID)
        XCTAssertNotNil(receipt.answerOutdatedEventID)

        let text = String(decoding: try JSONEncoder().encode(receipt), as: UTF8.self)
        XCTAssertFalse(text.contains(correctedSummary))
        XCTAssertFalse(text.contains(correctionText))
        XCTAssertFalse(text.contains(answer))
    }

    func testCorrectionResolutionReceiptRejectsRawContentAndMismatchedTerminalState() throws {
        let (_, lease) = try makeActiveRuntime()
        let answerReceipt = try verifiedAnswerCitationReceipt(
            for: lease,
            query: "纠正处理必须绑定待审核候选",
            answer: "任何处理结果都不能回显原始内容。",
            commandID: "owner-truth-answer-citation-resolution-invalid"
        )
        let requestCommand = try OwnerTruthCorrectionRequestCommand(
            commandID: "owner-truth-correction-request-resolution-invalid",
            receipt: answerReceipt,
            citationID: try XCTUnwrap(answerReceipt.citations.first).citationID,
            correctionText: "地点应更正为院子。",
            reasonCode: "ownerReportedCorrection"
        )
        let requestReceipt = try OwnerTruthCorrectionRequestReceipt(
            backendJSONObject: correctionRequestReceiptResponse(for: requestCommand),
            expectedCommand: requestCommand
        )
        let command = try OwnerTruthCorrectionResolutionCommand(
            commandID: "owner-truth-correction-resolution-invalid",
            correctionRequestReceipt: requestReceipt,
            action: .correct,
            correctedValue: ["summary": .string("已更正的私密摘要")],
            correctedValueSchemaVersion: "owner-truth-v1",
            reasonCode: "ownerConfirmedCorrection"
        )

        var rawResponse = correctionResolutionReceiptResponse(for: command)
        var rawResolution = try XCTUnwrap(rawResponse["correctionResolution"] as? [String: Any])
        rawResolution["content"] = ["summary": "不得进入处理回执"]
        rawResponse["correctionResolution"] = rawResolution
        XCTAssertThrowsError(
            try OwnerTruthCorrectionResolutionReceipt(
                backendJSONObject: rawResponse,
                expectedCommand: command
            )
        ) { error in
            guard case .invalidCorrectionResolutionReceipt = error as? OwnerTruthRemoteContractError else {
                return XCTFail("expected raw correction resolution rejection, got \(error)")
            }
        }

        var mismatchResponse = correctionResolutionReceiptResponse(for: command)
        var mismatchResolution = try XCTUnwrap(mismatchResponse["correctionResolution"] as? [String: Any])
        mismatchResolution["candidateId"] = "00000000-0000-0000-0000-000000000399"
        mismatchResponse["correctionResolution"] = mismatchResolution
        XCTAssertThrowsError(
            try OwnerTruthCorrectionResolutionReceipt(
                backendJSONObject: mismatchResponse,
                expectedCommand: command
            )
        ) { error in
            guard case .invalidCorrectionResolutionReceipt = error as? OwnerTruthRemoteContractError else {
                return XCTFail("expected correction resolution identity rejection, got \(error)")
            }
        }
    }

    func testCorrectionResolutionUseCaseUsesDedicatedResolverAndDropsStaleCompletion() throws {
        let (runtime, lease) = try makeActiveRuntime()
        let answerReceipt = try verifiedAnswerCitationReceipt(
            for: lease,
            query: "处理纠正后不得让旧账户接收结果",
            answer: "异步处理必须绑定当前账户租约。",
            commandID: "owner-truth-answer-citation-resolution-stale"
        )
        let requestCommand = try OwnerTruthCorrectionRequestCommand(
            commandID: "owner-truth-correction-request-resolution-stale",
            receipt: answerReceipt,
            citationID: try XCTUnwrap(answerReceipt.citations.first).citationID,
            correctionText: "账户切换后应丢弃处理结果。",
            reasonCode: "ownerReportedCorrection"
        )
        let requestReceipt = try OwnerTruthCorrectionRequestReceipt(
            backendJSONObject: correctionRequestReceiptResponse(for: requestCommand),
            expectedCommand: requestCommand
        )
        let expectedCommand = try OwnerTruthCorrectionResolutionCommand(
            commandID: "owner-truth-correction-resolution-stale",
            correctionRequestReceipt: requestReceipt,
            action: .reject,
            reasonCode: "ownerRejectedCorrection"
        )
        let client = CorrectionResolutionClientSpy()
        client.deferResolution = true
        let useCase = OwnerTruthCorrectionResolutionUseCase(
            accountLease: lease,
            correctionRequestReceipt: requestReceipt,
            client: client,
            accountLeaseRuntime: runtime,
            qaGateEnabled: { true },
            commandIDFactory: { expectedCommand.commandID }
        )

        useCase.send(.resolve(
            action: .reject,
            correctedValue: nil,
            correctedValueSchemaVersion: nil,
            reasonCode: expectedCommand.reasonCode
        ))
        XCTAssertEqual(useCase.viewState.phase, .resolving(requestReceipt.correctionRequestID))
        XCTAssertEqual(client.requestedCommands, [expectedCommand])

        runtime.publish(session: accountSession(
            subjectId: "owner-b",
            vaultId: "vault-b",
            generation: 2,
            generationID: UUID(uuidString: "00000000-0000-0000-0000-000000000102")!
        ))
        client.completeDeferredResolution(.success(try OwnerTruthCorrectionResolutionReceipt(
            backendJSONObject: correctionResolutionReceiptResponse(for: expectedCommand),
            expectedCommand: expectedCommand
        )))

        XCTAssertEqual(useCase.viewState.phase, .unavailable)
        XCTAssertEqual(useCase.viewState.notice, .staleAccountLease)
        XCTAssertNil(useCase.viewState.latestReceipt)
    }

    func testCorrectionResolutionUseCaseFailsClosedWhenQAGateIsDisabled() throws {
        let (runtime, lease) = try makeActiveRuntime()
        let answerReceipt = try verifiedAnswerCitationReceipt(
            for: lease,
            query: "关闭 QA gate 时不得处理纠正候选",
            answer: "处理路径必须默认关闭。",
            commandID: "owner-truth-answer-citation-resolution-gate"
        )
        let requestCommand = try OwnerTruthCorrectionRequestCommand(
            commandID: "owner-truth-correction-request-resolution-gate",
            receipt: answerReceipt,
            citationID: try XCTUnwrap(answerReceipt.citations.first).citationID,
            correctionText: "此请求不得在关闭 gate 时被处理。",
            reasonCode: "ownerReportedCorrection"
        )
        let requestReceipt = try OwnerTruthCorrectionRequestReceipt(
            backendJSONObject: correctionRequestReceiptResponse(for: requestCommand),
            expectedCommand: requestCommand
        )
        let client = CorrectionResolutionClientSpy()
        let useCase = OwnerTruthCorrectionResolutionUseCase(
            accountLease: lease,
            correctionRequestReceipt: requestReceipt,
            client: client,
            accountLeaseRuntime: runtime,
            qaGateEnabled: { false },
            commandIDFactory: { "owner-truth-correction-resolution-gate" }
        )

        useCase.send(.resolve(
            action: .reject,
            correctedValue: nil,
            correctedValueSchemaVersion: nil,
            reasonCode: "ownerRejectedCorrection"
        ))

        XCTAssertEqual(useCase.viewState.phase, .unavailable)
        XCTAssertEqual(useCase.viewState.notice, .qaOnlyDisabled)
        XCTAssertTrue(client.requestedCommands.isEmpty)
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

    func testCorrectionCandidateHandoffRefreshesExistingInboxWithoutExposingGenericTerminalReview() throws {
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
                "selectionMode": "projectionCitationOrder",
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

    private func correctionResolutionReceiptResponse(
        for command: OwnerTruthCorrectionResolutionCommand,
        outcome: OwnerTruthCorrectionResolutionOutcome = .created
    ) -> [String: Any] {
        let isCorrected = command.action == .correct
        return [
            "schemaVersion": "owner-truth-correction-resolution-response-v1",
            "status": outcome.rawValue,
            "correctionResolution": [
                "schemaVersion": "owner-truth-correction-resolution-v1",
                "outcome": outcome.rawValue,
                "correctionRequestId": command.correctionRequestID.rawValue.uuidString.lowercased(),
                "candidateId": command.candidateID.rawValue.uuidString.lowercased(),
                "candidateVersion": command.expectedCandidateVersion,
                "receiptId": "00000000-0000-0000-0000-000000000353",
                "decision": command.action.terminalDecision.rawValue,
                "supersededMemoryVersionId": isCorrected
                    ? command.expectedMemoryVersionID.rawValue.uuidString.lowercased()
                    : NSNull(),
                "replacementMemoryVersionId": isCorrected
                    ? "00000000-0000-0000-0000-000000000354"
                    : NSNull(),
                "replacementMemoryVersion": isCorrected ? 2 : NSNull(),
                "answerOutdatedEventId": isCorrected
                    ? "00000000-0000-0000-0000-000000000355"
                    : NSNull(),
                "authorityEpoch": isCorrected ? 7 : NSNull(),
                "contentHash": isCorrected ? digest("correction-resolution-content") : NSNull(),
                "projectionEffect": NSNull(),
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
                    "selectedExtractionId": extractionID,
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
                    "selectedExtractionId": extractionID,
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

    private func interviewCandidateProposalStatus(
        vaultID: String,
        reviewBatchID: OwnerTruthRecordID,
        reviewBatchState: OwnerTruthInterviewCandidateProposalReviewBatchState = .acknowledged,
        candidateProposalState: OwnerTruthInterviewCandidateProposalAdmissionState = .admitted,
        sourceState: OwnerTruthInterviewCandidateProposalSourceState = .admitted,
        candidateExtractionState: OwnerTruthInterviewCandidateProposalExtractionState = .requested,
        effectExecutionState: OwnerTruthInterviewCandidateProposalEffectState = .disabled,
        candidateReviewState: OwnerTruthInterviewCandidateProposalReviewState = .notReady
    ) throws -> OwnerTruthInterviewCandidateProposalStatus {
        try OwnerTruthInterviewCandidateProposalStatus(
            backendJSONObject: interviewCandidateProposalStatusPayload(
                vaultID: vaultID,
                reviewBatchID: reviewBatchID,
                reviewBatchState: reviewBatchState,
                candidateProposalState: candidateProposalState,
                sourceState: sourceState,
                candidateExtractionState: candidateExtractionState,
                effectExecutionState: effectExecutionState,
                candidateReviewState: candidateReviewState
            ),
            expectedVaultID: try XCTUnwrap(OwnerTruthVaultID(vaultID)),
            expectedReviewBatchID: reviewBatchID
        )
    }

    private func interviewCandidateProposalStatusPayload(
        vaultID: String,
        reviewBatchID: OwnerTruthRecordID,
        reviewBatchState: OwnerTruthInterviewCandidateProposalReviewBatchState = .acknowledged,
        candidateProposalState: OwnerTruthInterviewCandidateProposalAdmissionState = .admitted,
        sourceState: OwnerTruthInterviewCandidateProposalSourceState = .admitted,
        candidateExtractionState: OwnerTruthInterviewCandidateProposalExtractionState = .requested,
        effectExecutionState: OwnerTruthInterviewCandidateProposalEffectState = .disabled,
        candidateReviewState: OwnerTruthInterviewCandidateProposalReviewState = .notReady
    ) -> [String: Any] {
        [
            "schemaVersion": OwnerTruthInterviewCandidateProposalStatus.schemaVersion,
            "vaultId": vaultID,
            "reviewBatch": [
                "reviewBatchId": reviewBatchID.rawValue.uuidString,
                "state": reviewBatchState.rawValue,
            ],
            "candidateProposal": ["status": candidateProposalState.rawValue],
            "source": ["status": sourceState.rawValue],
            "candidateExtraction": ["status": candidateExtractionState.rawValue],
            "effectExecution": ["status": effectExecutionState.rawValue],
            "candidateReview": ["status": candidateReviewState.rawValue],
        ]
    }

    private func interviewCandidateConfirmationInbox(
        vaultID: String,
        reviewBatchIDs: [OwnerTruthRecordID]
    ) throws -> OwnerTruthInterviewCandidateConfirmationInbox {
        try OwnerTruthInterviewCandidateConfirmationInbox(
            backendJSONObject: [
                "schemaVersion": OwnerTruthInterviewCandidateConfirmationInbox.schemaVersion,
                "vaultId": vaultID,
                "confirmations": reviewBatchIDs.map { reviewBatchID in
                    [
                        "reviewBatchId": reviewBatchID.rawValue.uuidString,
                        "readiness": OwnerTruthInterviewCandidateReviewReadiness.reviewReady.rawValue,
                        "batchCandidateCount": 1,
                        "singleCandidateCount": 1,
                    ]
                },
            ],
            expectedVaultID: try XCTUnwrap(OwnerTruthVaultID(vaultID))
        )
    }

    private func interviewCandidateMemoryActivationInbox(
        vaultID: String,
        handles: [(reviewBatchID: OwnerTruthRecordID, candidateID: OwnerTruthRecordID)]
    ) throws -> OwnerTruthInterviewCandidateMemoryActivationInbox {
        try OwnerTruthInterviewCandidateMemoryActivationInbox(
            backendJSONObject: [
                "schemaVersion": OwnerTruthInterviewCandidateMemoryActivationInbox.schemaVersion,
                "vaultId": vaultID,
                "items": handles.map { handle -> [String: Any] in
                    [
                        "reviewBatchId": handle.reviewBatchID.rawValue.uuidString,
                        "candidateId": handle.candidateID.rawValue.uuidString,
                    ]
                },
            ],
            expectedVaultID: try XCTUnwrap(OwnerTruthVaultID(vaultID))
        )
    }

    private func interviewCandidateMemoryProjectionRecoveryInbox(
        vaultID: String,
        handles: [(reviewBatchID: OwnerTruthRecordID, candidateID: OwnerTruthRecordID)]
    ) throws -> OwnerTruthInterviewCandidateMemoryProjectionRecoveryInbox {
        try OwnerTruthInterviewCandidateMemoryProjectionRecoveryInbox(
            backendJSONObject: [
                "schemaVersion": OwnerTruthInterviewCandidateMemoryProjectionRecoveryInbox.schemaVersion,
                "vaultId": vaultID,
                "items": handles.map { handle -> [String: Any] in
                    [
                        "reviewBatchId": handle.reviewBatchID.rawValue.uuidString,
                        "candidateId": handle.candidateID.rawValue.uuidString,
                        "state": "rebuilding",
                    ]
                },
            ],
            expectedVaultID: try XCTUnwrap(OwnerTruthVaultID(vaultID))
        )
    }

    private func reconciledInterviewCandidateConfirmation(
        vaultID: String,
        reviewBatchID: OwnerTruthRecordID,
        remainingSingleCandidateID: OwnerTruthRecordID,
        admissionID: String = "00000000-0000-0000-0000-000000000153",
        sourceID: String = "00000000-0000-0000-0000-000000000151",
        sourceVersion: Int = 1,
        authorityEpoch: Int = 0
    ) throws -> OwnerTruthInterviewCandidateConfirmation {
        let extractionID = "00000000-0000-0000-0000-000000000162"
        return try OwnerTruthInterviewCandidateConfirmation(
            backendJSONObject: [
                "schemaVersion": OwnerTruthInterviewCandidateConfirmation.schemaVersion,
                "vaultId": vaultID,
                "confirmation": [
                    "schemaVersion": OwnerTruthInterviewCandidateConfirmation.compositionSchemaVersion,
                    "reviewBatchId": reviewBatchID.rawValue.uuidString,
                    "admissionId": admissionID,
                    "sourceId": sourceID,
                    "sourceVersion": sourceVersion,
                    "authorityEpoch": authorityEpoch,
                    "readiness": OwnerTruthInterviewCandidateReviewReadiness.reviewReady.rawValue,
                    "latestExtractionStatus": "succeeded",
                    "selectedExtractionId": extractionID,
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
                    "sourceRefs": [["sourceId": sourceID, "sourceVersion": sourceVersion]],
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

    private func interviewOrchestration(
        vaultID: String,
        action: OwnerTruthInterviewOrchestrationAction = .listen,
        reasonCode: String = "noSafePrimaryQuestion",
        nextSessionState: OwnerTruthInterviewOrchestrationNextSessionState = .active,
        maxFollowupsRemaining: Int = 3,
        reviewBatchDue: Bool = false,
        consumesOneShotBoundary: Bool = false
    ) throws -> OwnerTruthInterviewOrchestrationRead {
        try OwnerTruthInterviewOrchestrationRead(
            backendJSONObject: [
                "schemaVersion": OwnerTruthInterviewOrchestrationRead.schemaVersion,
                "vaultId": vaultID,
                "orchestration": [
                    "schemaVersion": OwnerTruthInterviewOrchestrationRead.orchestrationSchemaVersion,
                    "policySchemaVersion": OwnerTruthInterviewOrchestrationRead.policySchemaVersion,
                    "decision": [
                        "action": action.rawValue,
                        "consumesOneShotBoundary": consumesOneShotBoundary,
                        "maxFollowupsRemaining": maxFollowupsRemaining,
                        "nextSessionState": nextSessionState.rawValue,
                        "reasonCode": reasonCode,
                        "reviewBatchDue": reviewBatchDue,
                        "schemaVersion": OwnerTruthInterviewOrchestrationRead.policySchemaVersion,
                    ],
                    "persistedSession": [
                        "boundary": OwnerTruthInterviewSessionBoundary.open.rawValue,
                        "candidateBatchTurnCount": 1,
                        "deepeningTurnCount": 1,
                        "fatigue": OwnerTruthInterviewSessionFatigue.normal.rawValue,
                        "ownerTurnCount": 3,
                        "state": OwnerTruthInterviewSessionLifecycle.active.rawValue,
                    ],
                    "transientSignals": OwnerTruthInterviewOrchestrationRead.transientSignalsDescriptor,
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

    private func interviewNaturalInputReceipt(
        vaultID: OwnerTruthVaultID,
        boundary: OwnerTruthInterviewBoundaryCommand
    ) throws -> OwnerTruthInterviewNaturalInputReceipt {
        let lifecycle: OwnerTruthInterviewSessionLifecycle =
            boundary.boundary == .skipOnce ? .active : .paused
        return try OwnerTruthInterviewNaturalInputReceipt(
            backendJSONObject: [
                "schemaVersion": OwnerTruthInterviewNaturalInputReceipt.schemaVersion,
                "vaultId": vaultID.rawValue,
                "receipt": [
                    "status": OwnerTruthCommandOutcome.created.rawValue,
                    "threadId": boundary.threadID.rawValue.uuidString,
                    "sessionId": boundary.sessionID.rawValue.uuidString,
                    "threadVersion": 1,
                    "sessionVersion": boundary.expectedSessionVersion + 1,
                    "state": lifecycle.rawValue,
                    "boundary": boundary.boundary.rawValue,
                ],
            ],
            expectedVaultID: vaultID
        )
    }

    private func interviewNaturalInputReceipt(
        vaultID: OwnerTruthVaultID,
        pacing: OwnerTruthInterviewPacingCommand
    ) throws -> OwnerTruthInterviewNaturalInputReceipt {
        try OwnerTruthInterviewNaturalInputReceipt(
            backendJSONObject: [
                "schemaVersion": OwnerTruthInterviewNaturalInputReceipt.schemaVersion,
                "vaultId": vaultID.rawValue,
                "receipt": [
                    "status": OwnerTruthCommandOutcome.created.rawValue,
                    "threadId": pacing.threadID.rawValue.uuidString,
                    "sessionId": pacing.sessionID.rawValue.uuidString,
                    "threadVersion": 1,
                    "sessionVersion": pacing.expectedSessionVersion + 1,
                    "state": OwnerTruthInterviewSessionLifecycle.active.rawValue,
                    "boundary": OwnerTruthInterviewSessionBoundary.open.rawValue,
                ],
            ],
            expectedVaultID: vaultID
        )
    }

    private func interviewNaturalInputReceipt(
        vaultID: OwnerTruthVaultID,
        topicSwitch: OwnerTruthInterviewPauseForTopicSwitchCommand
    ) throws -> OwnerTruthInterviewNaturalInputReceipt {
        try OwnerTruthInterviewNaturalInputReceipt(
            backendJSONObject: [
                "schemaVersion": OwnerTruthInterviewNaturalInputReceipt.schemaVersion,
                "vaultId": vaultID.rawValue,
                "receipt": [
                    "status": OwnerTruthCommandOutcome.created.rawValue,
                    "threadId": topicSwitch.threadID.rawValue.uuidString,
                    "sessionId": topicSwitch.sessionID.rawValue.uuidString,
                    "threadVersion": topicSwitch.expectedThreadVersion + 1,
                    "sessionVersion": topicSwitch.expectedSessionVersion + 1,
                    "state": OwnerTruthInterviewSessionLifecycle.paused.rawValue,
                    "boundary": OwnerTruthInterviewSessionBoundary.open.rawValue,
                ],
            ],
            expectedVaultID: vaultID
        )
    }

    private func interviewNaturalInputReceipt(
        vaultID: OwnerTruthVaultID,
        restoreCooldown: OwnerTruthInterviewRestoreCooldownCommand
    ) throws -> OwnerTruthInterviewNaturalInputReceipt {
        try OwnerTruthInterviewNaturalInputReceipt(
            backendJSONObject: [
                "schemaVersion": OwnerTruthInterviewNaturalInputReceipt.schemaVersion,
                "vaultId": vaultID.rawValue,
                "receipt": [
                    "status": OwnerTruthCommandOutcome.created.rawValue,
                    "threadId": restoreCooldown.threadID.rawValue.uuidString,
                    "sessionId": restoreCooldown.sessionID.rawValue.uuidString,
                    "threadVersion": 1,
                    "sessionVersion": restoreCooldown.expectedSessionVersion + 1,
                    "state": OwnerTruthInterviewSessionLifecycle.active.rawValue,
                    "boundary": OwnerTruthInterviewSessionBoundary.open.rawValue,
                ],
            ],
            expectedVaultID: vaultID
        )
    }

    private func interviewNaturalInputContinuation(
        vaultID: OwnerTruthVaultID,
        state: OwnerTruthInterviewNaturalInputContinuationState,
        canContinue: Bool,
        canContinueLater: Bool
    ) throws -> OwnerTruthInterviewNaturalInputContinuation {
        try OwnerTruthInterviewNaturalInputContinuation(
            backendJSONObject: [
                "schemaVersion": OwnerTruthInterviewNaturalInputContinuation.schemaVersion,
                "vaultId": vaultID.rawValue,
                "presentation": [
                    "state": state.rawValue,
                    "canContinue": canContinue,
                    "canContinueLater": canContinueLater,
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

    private func interviewCandidateMemoryActivationResult(
        command: OwnerTruthInterviewCandidateMemoryActivationCommand,
        outcome: OwnerTruthCommandOutcome
    ) throws -> OwnerTruthInterviewCandidateMemoryActivationResult {
        try OwnerTruthInterviewCandidateMemoryActivationResult(
            backendJSONObject: [
                "schemaVersion": OwnerTruthInterviewCandidateMemoryActivationResult.schemaVersion,
                "status": outcome.rawValue,
                "reviewBatchId": command.reviewBatchID.rawValue.uuidString,
                "candidateId": command.candidateID.rawValue.uuidString,
                "memoryActivation": [
                    "status": outcome.rawValue,
                    "memoryVersionCreated": true,
                ],
                "projectionRebuildRequested": true,
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

    func testMigrationViewStateParityMatchesEquivalentLegacyAndV4Read() throws {
        let legacy = migrationParitySnapshot(source: .legacy)
        let v4 = migrationParitySnapshot(source: .v4)

        let report = try OwnerTruthMigrationParityViewStateComparator.compare(
            legacy: legacy,
            v4: v4,
            qaGateEnabled: true
        )

        XCTAssertEqual(report.schemaVersion, "owner-truth-migration-view-state-parity-v1")
        XCTAssertTrue(report.mismatches.isEmpty)
        XCTAssertEqual(report.blockerCount, 0)
        XCTAssertEqual(report.unresolvedM08Count, 0)
        XCTAssertTrue(report.isEligibleForApprovedWindow)
    }

    func testMigrationViewStateParityClassifiesAllBlockingDimensions() throws {
        let legacy = migrationParitySnapshot(source: .legacy)
        let differentAuthority = OwnerTruthMigrationParityAuthorityBinding(
            ownerSubjectHash: migrationDigest("owner-b"),
            vaultHash: migrationDigest("vault-b"),
            authorityEpochHash: migrationDigest("epoch-v2")
        )
        let v4 = OwnerTruthMigrationParityViewStateSnapshot(
            source: .v4,
            surface: .context,
            intentHash: migrationDigest("intent-b"),
            authority: differentAuthority,
            routeDecision: .denied,
            visibility: .hidden,
            phase: .failed,
            cacheState: .stale,
            viewStateHash: migrationDigest("view-state-b"),
            citationSetHash: migrationDigest("citations-b"),
            projectionCheckpointHash: migrationDigest("checkpoint-b"),
            presentationHash: migrationDigest("presentation-b")
        )

        let report = try OwnerTruthMigrationParityViewStateComparator.compare(
            legacy: legacy,
            v4: v4,
            qaGateEnabled: true
        )

        XCTAssertEqual(
            Set(report.mismatches.map(\.code)),
            [
                .m01AuthorityBinding,
                .m02IntentOrRoute,
                .m03Visibility,
                .m04AuthorityEpoch,
                .m05ViewState,
                .m06Citation,
                .m07CacheOrCheckpoint,
                .m08Presentation,
            ]
        )
        XCTAssertGreaterThan(report.blockerCount, 0)
        XCTAssertEqual(report.unresolvedM08Count, 1)
        XCTAssertFalse(report.isEligibleForApprovedWindow)
    }

    func testMigrationViewStateParityAllowsOnlyScopedUnexpiredM08PresentationDisposition() throws {
        let legacy = migrationParitySnapshot(source: .legacy)
        let v4 = migrationParitySnapshot(
            source: .v4,
            presentationHash: migrationDigest("presentation-v4")
        )
        let activeDate = Date(timeIntervalSince1970: 1_750_000_000)
        let disposition = OwnerTruthMigrationParityM08Disposition(
            surface: .context,
            legacyPresentationHash: try XCTUnwrap(legacy.presentationHash),
            v4PresentationHash: try XCTUnwrap(v4.presentationHash),
            approvalReferenceHash: migrationDigest("product-data-approval"),
            expiresAt: activeDate.addingTimeInterval(60)
        )

        let report = try OwnerTruthMigrationParityViewStateComparator.compare(
            legacy: legacy,
            v4: v4,
            m08Dispositions: [disposition],
            at: activeDate,
            qaGateEnabled: true
        )

        XCTAssertEqual(report.mismatches.count, 1)
        XCTAssertEqual(report.mismatches[0].code, .m08Presentation)
        XCTAssertEqual(report.mismatches[0].m08DispositionStatus, .approved)
        XCTAssertEqual(report.blockerCount, 0)
        XCTAssertTrue(report.isEligibleForApprovedWindow)

        let expiredReport = try OwnerTruthMigrationParityViewStateComparator.compare(
            legacy: legacy,
            v4: v4,
            m08Dispositions: [disposition],
            at: activeDate.addingTimeInterval(61),
            qaGateEnabled: true
        )
        XCTAssertEqual(expiredReport.mismatches[0].m08DispositionStatus, .expired)
        XCTAssertEqual(expiredReport.blockerCount, 1)
        XCTAssertFalse(expiredReport.isEligibleForApprovedWindow)
    }

    func testMigrationViewStateParityRejectsDisabledGateAndInvalidSourcePairs() throws {
        let legacy = migrationParitySnapshot(source: .legacy)
        let v4 = migrationParitySnapshot(source: .v4)

        XCTAssertThrowsError(
            try OwnerTruthMigrationParityViewStateComparator.compare(
                legacy: legacy,
                v4: v4,
                qaGateEnabled: false
            )
        ) { error in
            XCTAssertEqual(
                error as? OwnerTruthMigrationParityViewStateComparisonError,
                .qaDisabled
            )
        }

        XCTAssertThrowsError(
            try OwnerTruthMigrationParityViewStateComparator.compare(
                legacy: legacy,
                v4: migrationParitySnapshot(source: .legacy),
                qaGateEnabled: true
            )
        ) { error in
            XCTAssertEqual(
                error as? OwnerTruthMigrationParityViewStateComparisonError,
                .invalidSourcePair
            )
        }
    }

    func testMigrationViewStateParitySnapshotRejectsRawOrMalformedDigest() throws {
        XCTAssertNil(OwnerTruthMigrationParityDigest("not-a-digest"))
        XCTAssertNil(OwnerTruthMigrationParityDigest("sha256:ABCDEF"))

        let digest = migrationDigest("opaque-only")
        let decoded = try JSONDecoder().decode(
            OwnerTruthMigrationParityDigest.self,
            from: JSONEncoder().encode(digest)
        )
        XCTAssertEqual(decoded, digest)
    }

    func testGuidedRecommendationPresentationStrictlyKeepsOnlyDisplaySafePrompts() throws {
        let vaultID = try XCTUnwrap(OwnerTruthVaultID("vault-a"))
        let presentation = try OwnerTruthGuidedRecommendationPresentation(
            backendJSONObject: [
                "schemaVersion": OwnerTruthGuidedRecommendationPresentation.schemaVersion,
                "vaultId": vaultID.rawValue,
                "state": "ready",
                "recommendationSetId": String(repeating: "a", count: 64),
                "recommendations": [
                    [
                        "slot": "continuity",
                        "label": "继续聊聊",
                        "question": "那件事后来有什么变化？",
                    ],
                    [
                        "slot": "breadth",
                        "label": "换个角度",
                        "question": "还有什么想分享的经历？",
                    ],
                ],
            ],
            expectedVaultID: vaultID
        )

        XCTAssertEqual(presentation.state, .ready)
        XCTAssertEqual(presentation.prompts.map(\.slot), [.continuity, .breadth])
        XCTAssertEqual(presentation.prompts[0].label, "继续聊聊")
        XCTAssertEqual(presentation.prompts[1].question, "还有什么想分享的经历？")
        XCTAssertEqual(presentation.recommendationSetID, String(repeating: "a", count: 64))

        XCTAssertThrowsError(
            try OwnerTruthGuidedRecommendationPresentation(
                backendJSONObject: [
                    "schemaVersion": OwnerTruthGuidedRecommendationPresentation.schemaVersion,
                    "vaultId": vaultID.rawValue,
                    "state": "ready",
                    "recommendationSetId": String(repeating: "a", count: 64),
                    "recommendations": [[
                        "slot": "continuity",
                        "label": "继续聊聊",
                        "question": "那件事后来有什么变化？",
                        "candidateId": "must-not-cross-ui-boundary",
                    ]],
                ],
                expectedVaultID: vaultID
            )
        ) { error in
            guard case OwnerTruthRemoteContractError.invalidGuidedRecommendationPresentation = error else {
                return XCTFail("unexpected error: \(error)")
            }
        }

        XCTAssertThrowsError(
            try OwnerTruthGuidedRecommendationPresentation(
                backendJSONObject: [
                    "schemaVersion": OwnerTruthGuidedRecommendationPresentation.schemaVersion,
                    "vaultId": vaultID.rawValue,
                    "state": "ready",
                    "recommendationSetId": String(repeating: "５", count: 64),
                    "recommendations": [[
                        "slot": "continuity",
                        "label": "继续聊聊",
                        "question": "那件事后来有什么变化？",
                    ]],
                ],
                expectedVaultID: vaultID
            )
        )
    }

    func testGuidedRecommendationPresentationUseCaseDoesNotRequestWhenPolicyIsClosed() throws {
        let (runtime, lease) = try makeActiveRuntime()
        let client = GuidedRecommendationPresentationClientSpy()
        let useCase = OwnerTruthGuidedRecommendationPresentationUseCase(
            accountLease: lease,
            client: client,
            accountLeaseRuntime: runtime,
            releasePolicyAvailable: { false }
        )

        useCase.refresh()

        XCTAssertEqual(client.requestCount, 0)
        XCTAssertEqual(useCase.viewState.phase, .unavailable)
        XCTAssertEqual(useCase.viewState.notice, .releasePolicyDisabled)
        XCTAssertTrue(useCase.viewState.prompts.isEmpty)
    }

    func testGuidedRecommendationPresentationUseCasePublishesOnlyCurrentAccountPrompts() throws {
        let (runtime, lease) = try makeActiveRuntime()
        let vaultID = try XCTUnwrap(OwnerTruthVaultID(lease.vaultId))
        let client = GuidedRecommendationPresentationClientSpy()
        client.result = .success(try OwnerTruthGuidedRecommendationPresentation(
            backendJSONObject: [
                "schemaVersion": OwnerTruthGuidedRecommendationPresentation.schemaVersion,
                "vaultId": vaultID.rawValue,
                "state": "ready",
                "recommendationSetId": String(repeating: "b", count: 64),
                "recommendations": [[
                    "slot": "continuity",
                    "label": "继续聊聊",
                    "question": "那件事后来有什么变化？",
                ]],
            ],
            expectedVaultID: vaultID
        ))
        let useCase = OwnerTruthGuidedRecommendationPresentationUseCase(
            accountLease: lease,
            client: client,
            accountLeaseRuntime: runtime,
            releasePolicyAvailable: { true }
        )

        useCase.refresh()

        XCTAssertEqual(client.requestCount, 1)
        XCTAssertEqual(useCase.viewState.phase, .ready)
        XCTAssertEqual(useCase.viewState.prompts.map(\.slot), [.continuity])
        XCTAssertNil(useCase.viewState.notice)
    }

    func testGuidedRecommendationPresentationUseCaseDiscardsDeferredReadAfterAccountSwitch() throws {
        let (runtime, lease) = try makeActiveRuntime()
        let vaultID = try XCTUnwrap(OwnerTruthVaultID(lease.vaultId))
        let client = GuidedRecommendationPresentationClientSpy()
        client.deferRead = true
        let useCase = OwnerTruthGuidedRecommendationPresentationUseCase(
            accountLease: lease,
            client: client,
            accountLeaseRuntime: runtime,
            releasePolicyAvailable: { true }
        )

        useCase.refresh()
        runtime.publish(session: accountSession(
            subjectId: "owner-b",
            vaultId: "vault-b",
            generation: 2,
            generationID: UUID(uuidString: "00000000-0000-0000-0000-000000000102")!
        ))
        client.completeDeferred(.success(try OwnerTruthGuidedRecommendationPresentation(
            backendJSONObject: [
                "schemaVersion": OwnerTruthGuidedRecommendationPresentation.schemaVersion,
                "vaultId": vaultID.rawValue,
                "state": "ready",
                "recommendationSetId": String(repeating: "c", count: 64),
                "recommendations": [[
                    "slot": "continuity",
                    "label": "继续聊聊",
                    "question": "那件事后来有什么变化？",
                ]],
            ],
            expectedVaultID: vaultID
        )))

        XCTAssertEqual(useCase.viewState.phase, .unavailable)
        XCTAssertEqual(useCase.viewState.notice, .staleAccountLease)
        XCTAssertTrue(useCase.viewState.prompts.isEmpty)
    }

    func testGuidedRecommendationPresentationPathUsesItsOwnFeatureGate() {
        XCTAssertEqual(
            FeatureGateService.shared.featureForRequest(
                path: "/v2/vaults/vault-a/guided-recommendations",
                method: .get,
                payload: nil
            ),
            .echoGuidedRecommendations
        )
        XCTAssertEqual(
            FeatureGateService.shared.featureForRequest(
                path: "/v2/vaults/vault-a/guided-recommendations/feedback",
                method: .post,
                payload: nil
            ),
            .echoGuidedRecommendations
        )
    }

    func testGuidedRecommendationFeedbackContractKeepsOnlyValueFreeStatus() throws {
        let vaultID = try XCTUnwrap(OwnerTruthVaultID("vault-a"))
        let receipt = try OwnerTruthGuidedRecommendationFeedbackReceipt(
            backendJSONObject: [
                "schemaVersion": OwnerTruthGuidedRecommendationFeedbackReceipt.schemaVersion,
                "vaultId": vaultID.rawValue,
                "feedback": ["status": "created"],
            ],
            expectedVaultID: vaultID
        )

        XCTAssertEqual(receipt.status, .created)
        XCTAssertThrowsError(
            try OwnerTruthGuidedRecommendationFeedbackReceipt(
                backendJSONObject: [
                    "schemaVersion": OwnerTruthGuidedRecommendationFeedbackReceipt.schemaVersion,
                    "vaultId": vaultID.rawValue,
                    "feedback": [
                        "status": "created",
                        "candidateId": "must-not-cross-ui-boundary",
                    ],
                ],
                expectedVaultID: vaultID
            )
        )
    }

    func testGuidedRecommendationFeedbackRefreshesPromptsAfterValueFreeReceipt() throws {
        let (runtime, lease) = try makeActiveRuntime()
        let vaultID = try XCTUnwrap(OwnerTruthVaultID(lease.vaultId))
        let client = GuidedRecommendationPresentationClientSpy()
        client.result = .success(try OwnerTruthGuidedRecommendationPresentation(
            backendJSONObject: [
                "schemaVersion": OwnerTruthGuidedRecommendationPresentation.schemaVersion,
                "vaultId": vaultID.rawValue,
                "state": "ready",
                "recommendationSetId": String(repeating: "d", count: 64),
                "recommendations": [[
                    "slot": "breadth",
                    "label": "换个角度",
                    "question": "还有什么想分享的经历？",
                ]],
            ],
            expectedVaultID: vaultID
        ))
        client.feedbackResult = .success(try OwnerTruthGuidedRecommendationFeedbackReceipt(
            backendJSONObject: [
                "schemaVersion": OwnerTruthGuidedRecommendationFeedbackReceipt.schemaVersion,
                "vaultId": vaultID.rawValue,
                "feedback": ["status": "created"],
            ],
            expectedVaultID: vaultID
        ))
        let useCase = OwnerTruthGuidedRecommendationPresentationUseCase(
            accountLease: lease,
            client: client,
            accountLeaseRuntime: runtime,
            releasePolicyAvailable: { true }
        )

        useCase.refresh()
        useCase.submitFeedback(
            slot: .breadth,
            action: .replace,
            reason: .questionWording
        )

        XCTAssertEqual(client.requestCount, 2)
        XCTAssertEqual(client.feedbackCommands.count, 1)
        XCTAssertEqual(client.feedbackCommands[0].recommendationSetID, String(repeating: "d", count: 64))
        XCTAssertEqual(client.feedbackCommands[0].slot, .breadth)
        XCTAssertEqual(client.feedbackCommands[0].action, .replace)
        XCTAssertEqual(useCase.viewState.phase, .ready)
        XCTAssertEqual(useCase.viewState.prompts.map(\.slot), [.breadth])
    }

    func testGuidedRecommendationTimingFeedbackRefreshesPromptsAfterValueFreeReceipt() throws {
        let (runtime, lease) = try makeActiveRuntime()
        let vaultID = try XCTUnwrap(OwnerTruthVaultID(lease.vaultId))
        let client = GuidedRecommendationPresentationClientSpy()
        client.result = .success(try OwnerTruthGuidedRecommendationPresentation(
            backendJSONObject: [
                "schemaVersion": OwnerTruthGuidedRecommendationPresentation.schemaVersion,
                "vaultId": vaultID.rawValue,
                "state": "ready",
                "recommendationSetId": String(repeating: "a", count: 64),
                "recommendations": [[
                    "slot": "continuity",
                    "label": "继续聊聊",
                    "question": "那件事后来有什么变化？",
                ]],
            ],
            expectedVaultID: vaultID
        ))
        client.feedbackResult = .success(try OwnerTruthGuidedRecommendationFeedbackReceipt(
            backendJSONObject: [
                "schemaVersion": OwnerTruthGuidedRecommendationFeedbackReceipt.schemaVersion,
                "vaultId": vaultID.rawValue,
                "feedback": ["status": "created"],
            ],
            expectedVaultID: vaultID
        ))
        let useCase = OwnerTruthGuidedRecommendationPresentationUseCase(
            accountLease: lease,
            client: client,
            accountLeaseRuntime: runtime,
            releasePolicyAvailable: { true }
        )

        useCase.refresh()
        useCase.submitFeedback(
            slot: .continuity,
            action: .defer,
            reason: .timing
        )

        XCTAssertEqual(client.requestCount, 2)
        XCTAssertEqual(client.feedbackCommands.count, 1)
        XCTAssertEqual(client.feedbackCommands[0].recommendationSetID, String(repeating: "a", count: 64))
        XCTAssertEqual(client.feedbackCommands[0].slot, .continuity)
        XCTAssertEqual(client.feedbackCommands[0].action, .defer)
        XCTAssertEqual(client.feedbackCommands[0].reason, .timing)
        XCTAssertEqual(client.feedbackCommands[0].backendPayload["feedbackAction"] as? String, "defer")
        XCTAssertEqual(client.feedbackCommands[0].backendPayload["feedbackReason"] as? String, "timing")
        XCTAssertEqual(useCase.viewState.phase, .ready)
        XCTAssertEqual(useCase.viewState.prompts.map(\.slot), [.continuity])
    }

    func testGuidedRecommendationFeedbackFailurePreservesPromptsForRetry() throws {
        let (runtime, lease) = try makeActiveRuntime()
        let vaultID = try XCTUnwrap(OwnerTruthVaultID(lease.vaultId))
        let client = GuidedRecommendationPresentationClientSpy()
        client.result = .success(try OwnerTruthGuidedRecommendationPresentation(
            backendJSONObject: [
                "schemaVersion": OwnerTruthGuidedRecommendationPresentation.schemaVersion,
                "vaultId": vaultID.rawValue,
                "state": "ready",
                "recommendationSetId": String(repeating: "e", count: 64),
                "recommendations": [[
                    "slot": "continuity",
                    "label": "继续聊聊",
                    "question": "那件事后来有什么变化？",
                ]],
            ],
            expectedVaultID: vaultID
        ))
        client.feedbackResult = .failure(GuidedRecommendationPresentationClientSpyError.missingFeedbackResult)
        let useCase = OwnerTruthGuidedRecommendationPresentationUseCase(
            accountLease: lease,
            client: client,
            accountLeaseRuntime: runtime,
            releasePolicyAvailable: { true }
        )

        useCase.refresh()
        useCase.submitFeedback(
            slot: .continuity,
            action: .notInterested,
            reason: .topicPreference
        )

        XCTAssertEqual(useCase.viewState.phase, .ready)
        XCTAssertEqual(useCase.viewState.notice, .feedbackRequestFailed)
        XCTAssertEqual(useCase.viewState.prompts.map(\.slot), [.continuity])
        XCTAssertEqual(useCase.viewState.recommendationSetID, String(repeating: "e", count: 64))
    }

    @MainActor
    func testGuidedRecommendationProductSheetRendersPromptAndAdjustmentControl() throws {
        let (runtime, lease) = try makeActiveRuntime()
        let vaultID = try XCTUnwrap(OwnerTruthVaultID(lease.vaultId))
        let naturalInputClient = InterviewNaturalInputClientSpy()
        naturalInputClient.startHandler = { command in
            Result { try self.interviewNaturalInputReceipt(vaultID: vaultID, start: command) }
        }
        let guidedClient = GuidedRecommendationPresentationClientSpy()
        guidedClient.result = .success(try OwnerTruthGuidedRecommendationPresentation(
            backendJSONObject: [
                "schemaVersion": OwnerTruthGuidedRecommendationPresentation.schemaVersion,
                "vaultId": vaultID.rawValue,
                "state": "ready",
                "recommendationSetId": String(repeating: "f", count: 64),
                "recommendations": [[
                    "slot": "continuity",
                    "label": "继续聊聊",
                    "question": "那件事后来有什么变化？",
                ]],
            ],
            expectedVaultID: vaultID
        ))
        let controller = OwnerTruthInterviewNaturalInputViewController(
            accountLease: lease,
            client: naturalInputClient,
            accountLeaseRuntime: runtime,
            presentation: .product,
            guidedRecommendationClient: guidedClient,
            guidedRecommendationPolicyAvailable: { true },
            lifeMapPolicyAvailable: { true },
            memorySearchPolicyAvailable: { true },
            qaGateEnabled: { true }
        )

        controller.loadViewIfNeeded()

        XCTAssertNotNil(
            findView(
                in: controller.view,
                accessibilityIdentifier: "owner-truth-guided-recommendation-continuity"
            )
        )
        XCTAssertNotNil(
            findView(
                in: controller.view,
                accessibilityIdentifier: "owner-truth-guided-recommendation-actions-continuity"
            )
        )
        XCTAssertNotNil(
            findView(
                in: controller.view,
                accessibilityIdentifier: "owner-truth-life-map-entry"
            )
        )
        XCTAssertNotNil(
            findView(
                in: controller.view,
                accessibilityIdentifier: "owner-truth-memory-search-entry"
            )
        )
    }

    @MainActor
    func testNaturalInputProductSheetExposesOnlyProductBoundaryControlsWithConfirmedRestore() throws {
        let (runtime, lease) = try makeActiveRuntime()
        let vaultID = try XCTUnwrap(OwnerTruthVaultID(lease.vaultId))
        let client = InterviewNaturalInputClientSpy()
        client.startHandler = { command in
            Result { try self.interviewNaturalInputReceipt(vaultID: vaultID, start: command) }
        }
        client.boundaryHandler = { command in
            Result { try self.interviewNaturalInputReceipt(vaultID: vaultID, boundary: command) }
        }
        client.continuationHandler = { _ in
            Result {
                let isDoNotAsk = client.boundaryCommand?.boundary == .doNotAsk
                return try self.interviewNaturalInputContinuation(
                    vaultID: vaultID,
                    state: isDoNotAsk ? .paused : .readyForNarrative,
                    canContinue: !isDoNotAsk,
                    canContinueLater: !isDoNotAsk
                )
            }
        }
        let controller = OwnerTruthInterviewNaturalInputViewController(
            accountLease: lease,
            client: client,
            accountLeaseRuntime: runtime,
            presentation: .product,
            guidedRecommendationPolicyAvailable: { false },
            lifeMapPolicyAvailable: { false },
            memorySearchPolicyAvailable: { false },
            interviewOutcomePolicyAvailable: { false },
            qaGateEnabled: { true }
        )

        controller.loadViewIfNeeded()

        let skipOnce = try XCTUnwrap(findView(
            in: controller.view,
            accessibilityIdentifier: "owner-truth-interview-boundary-skip-once"
        ) as? UIButton)
        let cooldown = try XCTUnwrap(findView(
            in: controller.view,
            accessibilityIdentifier: "owner-truth-interview-boundary-cooldown"
        ) as? UIButton)
        let doNotAsk = try XCTUnwrap(findView(
            in: controller.view,
            accessibilityIdentifier: "owner-truth-interview-boundary-do-not-ask"
        ) as? UIButton)
        XCTAssertFalse(skipOnce.isHidden)
        XCTAssertFalse(cooldown.isHidden)
        XCTAssertFalse(doNotAsk.isHidden)
        XCTAssertTrue(skipOnce.isEnabled)
        XCTAssertTrue(cooldown.isEnabled)
        XCTAssertTrue(doNotAsk.isEnabled)
        XCTAssertNil(findView(
            in: controller.view,
            accessibilityIdentifier: "owner-truth-interview-topic-switch"
        ))
        XCTAssertNil(findView(
            in: controller.view,
            accessibilityIdentifier: "owner-truth-interview-pacing-deepening-completed"
        ))
        XCTAssertNil(findView(
            in: controller.view,
            accessibilityIdentifier: "owner-truth-interview-boundary-restore-cooldown"
        ))

        doNotAsk.sendActions(for: .touchUpInside)

        XCTAssertEqual(client.boundaryCommand?.boundary, .doNotAsk)
        let restore = try XCTUnwrap(findView(
            in: controller.view,
            accessibilityIdentifier: "owner-truth-interview-boundary-restore-do-not-ask"
        ) as? UIButton)
        XCTAssertFalse(restore.isHidden)
        XCTAssertNil(client.restoreDoNotAskCommand)
    }

    @MainActor
    func testMemorySearchProductEntryStaysHiddenWithoutItsPolicy() throws {
        let (runtime, lease) = try makeActiveRuntime()
        let controller = OwnerTruthInterviewNaturalInputViewController(
            accountLease: lease,
            client: InterviewNaturalInputClientSpy(),
            accountLeaseRuntime: runtime,
            presentation: .product,
            guidedRecommendationPolicyAvailable: { false },
            lifeMapPolicyAvailable: { false },
            memorySearchPolicyAvailable: { false },
            qaGateEnabled: { true }
        )

        controller.loadViewIfNeeded()

        let entry = try XCTUnwrap(findView(
            in: controller.view,
            accessibilityIdentifier: "owner-truth-memory-search-entry"
        ))
        XCTAssertTrue(entry.isHidden)
    }

    func testLifeMapPresentationDecodesOnlyDisplaySafeFields() throws {
        let vaultID = try XCTUnwrap(OwnerTruthVaultID("vault-life-map-a"))
        let presentation = try OwnerTruthLifeMapPresentation(
            backendJSONObject: lifeMapPresentationJSON(vaultID: vaultID),
            expectedVaultID: vaultID
        )

        XCTAssertEqual(presentation.vaultID, vaultID)
        XCTAssertEqual(presentation.state, .ready)
        XCTAssertEqual(presentation.storyCount, 2)
        XCTAssertEqual(presentation.associatedStoryCount, 1)
        XCTAssertEqual(presentation.dimensions.count, OwnerTruthKnowledgeRecommendationDimension.allCases.count)
        XCTAssertEqual(
            presentation.dimensions.first(where: { $0.dimension == .keyDecisions })?.confirmedEvidenceCount,
            1
        )

        var unsafe = lifeMapPresentationJSON(vaultID: vaultID)
        var map = try XCTUnwrap(unsafe["lifeMap"] as? [String: Any])
        map["threadId"] = "internal-thread-id"
        unsafe["lifeMap"] = map
        XCTAssertThrowsError(
            try OwnerTruthLifeMapPresentation(
                backendJSONObject: unsafe,
                expectedVaultID: vaultID
            )
        ) { error in
            XCTAssertEqual(
                error as? OwnerTruthRemoteContractError,
                .invalidLifeMapPresentation("response contains unsupported fields")
            )
        }
    }

    func testLifeMapPresentationUseCaseDoesNotRequestWhenPolicyIsClosed() throws {
        let (runtime, lease) = try makeActiveRuntime()
        let client = LifeMapPresentationClientSpy()
        let useCase = OwnerTruthLifeMapPresentationUseCase(
            accountLease: lease,
            client: client,
            accountLeaseRuntime: runtime,
            releasePolicyAvailable: { false }
        )

        useCase.refresh()

        XCTAssertEqual(client.requestCount, 0)
        XCTAssertEqual(useCase.viewState.phase, .unavailable)
        XCTAssertEqual(useCase.viewState.notice, .releasePolicyDisabled)
        XCTAssertNil(useCase.viewState.presentation)
    }

    func testLifeMapPresentationUseCasePublishesOnlyCurrentAccountResult() throws {
        let (runtime, lease) = try makeActiveRuntime()
        let vaultID = try XCTUnwrap(OwnerTruthVaultID(lease.vaultId))
        let client = LifeMapPresentationClientSpy()
        client.result = .success(try OwnerTruthLifeMapPresentation(
            backendJSONObject: lifeMapPresentationJSON(vaultID: vaultID),
            expectedVaultID: vaultID
        ))
        let useCase = OwnerTruthLifeMapPresentationUseCase(
            accountLease: lease,
            client: client,
            accountLeaseRuntime: runtime,
            releasePolicyAvailable: { true }
        )

        useCase.refresh()

        XCTAssertEqual(client.requestCount, 1)
        XCTAssertEqual(useCase.viewState.phase, .ready)
        XCTAssertEqual(useCase.viewState.presentation?.storyCount, 2)
    }

    func testLifeMapPresentationUseCaseDiscardsDeferredReadAfterAccountSwitch() throws {
        let (runtime, lease) = try makeActiveRuntime()
        let vaultID = try XCTUnwrap(OwnerTruthVaultID(lease.vaultId))
        let client = LifeMapPresentationClientSpy()
        client.deferRead = true
        let useCase = OwnerTruthLifeMapPresentationUseCase(
            accountLease: lease,
            client: client,
            accountLeaseRuntime: runtime,
            releasePolicyAvailable: { true }
        )

        useCase.refresh()
        runtime.publish(session: accountSession(
            subjectId: "owner-b",
            vaultId: "vault-b",
            generation: 2,
            generationID: UUID(uuidString: "00000000-0000-0000-0000-000000000112")!
        ))
        client.completeDeferred(.success(try OwnerTruthLifeMapPresentation(
            backendJSONObject: lifeMapPresentationJSON(vaultID: vaultID),
            expectedVaultID: vaultID
        )))

        XCTAssertEqual(useCase.viewState.phase, .unavailable)
        XCTAssertEqual(useCase.viewState.notice, .staleAccountLease)
        XCTAssertNil(useCase.viewState.presentation)
    }

    func testLifeMapPresentationPathUsesItsOwnFeatureGate() {
        XCTAssertEqual(
            FeatureGateService.shared.featureForRequest(
                path: "/v2/vaults/vault-a/life-map",
                method: .get,
                payload: nil
            ),
            .ownerTruthLifeMap
        )
    }

    func testMemorySearchPresentationDecodesOnlyProductFields() throws {
        let vaultID = try XCTUnwrap(OwnerTruthVaultID("vault-memory-search-a"))
        let presentation = try OwnerTruthMemorySearchPresentation(
            backendJSONObject: memorySearchPresentationJSON(vaultID: vaultID),
            expectedVaultID: vaultID
        )

        XCTAssertEqual(presentation.vaultID, vaultID)
        XCTAssertEqual(presentation.state, .ready)
        XCTAssertEqual(presentation.retrievalMode, .deterministicTextFallback)
        XCTAssertEqual(presentation.results.count, 1)
        XCTAssertEqual(presentation.results[0].preview, "小时候在院子里听外婆讲故事。")

        var unsafe = memorySearchPresentationJSON(vaultID: vaultID)
        var search = try XCTUnwrap(unsafe["memorySearch"] as? [String: Any])
        var results = try XCTUnwrap(search["results"] as? [[String: Any]])
        results[0]["memoryVersionId"] = "internal-memory-version"
        search["results"] = results
        unsafe["memorySearch"] = search
        XCTAssertThrowsError(
            try OwnerTruthMemorySearchPresentation(
                backendJSONObject: unsafe,
                expectedVaultID: vaultID
            )
        ) { error in
            XCTAssertEqual(
                error as? OwnerTruthRemoteContractError,
                .invalidMemorySearchPresentation("result contains unsupported fields")
            )
        }
    }

    func testMemorySearchPresentationUseCaseDoesNotRequestWhenPolicyIsClosed() throws {
        let (runtime, lease) = try makeActiveRuntime()
        let client = MemorySearchPresentationClientSpy()
        let useCase = OwnerTruthMemorySearchPresentationUseCase(
            accountLease: lease,
            client: client,
            accountLeaseRuntime: runtime,
            releasePolicyAvailable: { false }
        )

        useCase.search(query: "童年")

        XCTAssertEqual(client.requestCount, 0)
        XCTAssertEqual(useCase.viewState.phase, .unavailable)
        XCTAssertEqual(useCase.viewState.notice, .releasePolicyDisabled)
        XCTAssertNil(useCase.viewState.presentation)
    }

    func testMemorySearchPresentationUseCaseDiscardsDeferredReadAfterAccountSwitch() throws {
        let (runtime, lease) = try makeActiveRuntime()
        let vaultID = try XCTUnwrap(OwnerTruthVaultID(lease.vaultId))
        let client = MemorySearchPresentationClientSpy()
        client.deferRead = true
        let useCase = OwnerTruthMemorySearchPresentationUseCase(
            accountLease: lease,
            client: client,
            accountLeaseRuntime: runtime,
            releasePolicyAvailable: { true }
        )

        useCase.search(query: "童年")
        runtime.publish(session: accountSession(
            subjectId: "owner-b",
            vaultId: "vault-b",
            generation: 2,
            generationID: UUID(uuidString: "00000000-0000-0000-0000-000000000113")!
        ))
        client.completeDeferred(.success(try OwnerTruthMemorySearchPresentation(
            backendJSONObject: memorySearchPresentationJSON(vaultID: vaultID),
            expectedVaultID: vaultID
        )))

        XCTAssertEqual(useCase.viewState.phase, .unavailable)
        XCTAssertEqual(useCase.viewState.notice, .staleAccountLease)
        XCTAssertNil(useCase.viewState.presentation)
    }

    func testMemorySearchPresentationPathUsesItsOwnFeatureGate() {
        XCTAssertEqual(
            FeatureGateService.shared.featureForRequest(
                path: "/v2/vaults/vault-a/memory-search",
                method: .post,
                payload: ["query": "童年"]
            ),
            .ownerTruthMemorySearch
        )
    }

    func testInterviewOutcomePresentationDecodesOnlyProductFields() throws {
        let vaultID = try XCTUnwrap(OwnerTruthVaultID("vault-interview-outcome-a"))
        let presentation = try OwnerTruthInterviewOutcomePresentation(
            backendJSONObject: interviewOutcomePresentationJSON(vaultID: vaultID),
            expectedVaultID: vaultID
        )

        XCTAssertEqual(presentation.vaultID, vaultID)
        XCTAssertEqual(presentation.state, .ready)
        XCTAssertEqual(presentation.confirmedMemoryCount, 2)
        XCTAssertEqual(presentation.pendingReviewBatchCount, 1)
        XCTAssertTrue(presentation.canContinueLater)
        XCTAssertEqual(presentation.eligibleCueCount, 1)

        var unsafe = interviewOutcomePresentationJSON(vaultID: vaultID)
        var outcome = try XCTUnwrap(unsafe["sessionOutcome"] as? [String: Any])
        outcome["sessionId"] = "internal-session-id"
        unsafe["sessionOutcome"] = outcome
        XCTAssertThrowsError(
            try OwnerTruthInterviewOutcomePresentation(
                backendJSONObject: unsafe,
                expectedVaultID: vaultID
            )
        ) { error in
            XCTAssertEqual(
                error as? OwnerTruthRemoteContractError,
                .invalidInterviewOutcomePresentation("response contains unsupported fields")
            )
        }
    }

    func testInterviewOutcomePresentationUseCaseDoesNotRequestWhenPolicyIsClosed() throws {
        let (runtime, lease) = try makeActiveRuntime()
        let sessionID = OwnerTruthRecordID(
            rawValue: UUID(uuidString: "00000000-0000-0000-0000-000000000402")!
        )
        let client = InterviewOutcomePresentationClientSpy()
        let useCase = OwnerTruthInterviewOutcomePresentationUseCase(
            accountLease: lease,
            sessionID: sessionID,
            client: client,
            accountLeaseRuntime: runtime,
            releasePolicyAvailable: { false }
        )

        useCase.refresh()

        XCTAssertEqual(client.requestCount, 0)
        XCTAssertEqual(useCase.viewState.phase, .unavailable)
        XCTAssertEqual(useCase.viewState.notice, .releasePolicyDisabled)
        XCTAssertNil(useCase.viewState.presentation)
    }

    func testInterviewOutcomePresentationUseCaseDiscardsDeferredReadAfterAccountSwitch() throws {
        let (runtime, lease) = try makeActiveRuntime()
        let vaultID = try XCTUnwrap(OwnerTruthVaultID(lease.vaultId))
        let sessionID = OwnerTruthRecordID(
            rawValue: UUID(uuidString: "00000000-0000-0000-0000-000000000403")!
        )
        let client = InterviewOutcomePresentationClientSpy()
        client.deferRead = true
        let useCase = OwnerTruthInterviewOutcomePresentationUseCase(
            accountLease: lease,
            sessionID: sessionID,
            client: client,
            accountLeaseRuntime: runtime,
            releasePolicyAvailable: { true }
        )

        useCase.refresh()
        runtime.publish(session: accountSession(
            subjectId: "owner-b",
            vaultId: "vault-b",
            generation: 2,
            generationID: UUID(uuidString: "00000000-0000-0000-0000-000000000114")!
        ))
        client.completeDeferred(.success(try OwnerTruthInterviewOutcomePresentation(
            backendJSONObject: interviewOutcomePresentationJSON(vaultID: vaultID),
            expectedVaultID: vaultID
        )))

        XCTAssertEqual(useCase.viewState.phase, .unavailable)
        XCTAssertEqual(useCase.viewState.notice, .staleAccountLease)
        XCTAssertNil(useCase.viewState.presentation)
    }

    func testInterviewOutcomePresentationPathUsesItsOwnFeatureGate() {
        XCTAssertEqual(
            FeatureGateService.shared.featureForRequest(
                path: "/v2/vaults/vault-a/interview-sessions/session-a/outcome",
                method: .get,
                payload: nil
            ),
            .ownerTruthInterviewOutcome
        )
    }

    private func lifeMapPresentationJSON(vaultID: OwnerTruthVaultID) -> [String: Any] {
        [
            "schemaVersion": OwnerTruthLifeMapPresentation.schemaVersion,
            "vaultId": vaultID.rawValue,
            "lifeMap": [
                "state": "ready",
                "storyCount": 2,
                "associatedStoryCount": 1,
                "dimensions": OwnerTruthKnowledgeRecommendationDimension.allCases.enumerated().map {
                    index,
                    dimension in
                    [
                        "dimension": dimension.rawValue,
                        "confirmedEvidenceCount": dimension == .keyDecisions ? 1 : 0,
                        "coveredFacetCount": index == 0 ? 1 : 0,
                        "unfilledFacetCount": max(0, dimension.facetOrder.count - (index == 0 ? 1 : 0)),
                        "relatedStoryCount": index == 0 ? 1 : 0,
                    ]
                },
            ],
        ]
    }

    private func memorySearchPresentationJSON(vaultID: OwnerTruthVaultID) -> [String: Any] {
        [
            "schemaVersion": OwnerTruthMemorySearchPresentation.schemaVersion,
            "vaultId": vaultID.rawValue,
            "memorySearch": [
                "state": "ready",
                "retrievalMode": "deterministicTextFallback",
                "resultCount": 1,
                "results": [[
                    "rank": 1,
                    "preview": "小时候在院子里听外婆讲故事。",
                    "memoryKind": "knowledge",
                    "perspectiveType": "firstPerson",
                    "sensitivity": "standard",
                    "matchKind": "searchText",
                ]],
            ],
        ]
    }

    private func interviewOutcomePresentationJSON(vaultID: OwnerTruthVaultID) -> [String: Any] {
        [
            "schemaVersion": OwnerTruthInterviewOutcomePresentation.schemaVersion,
            "vaultId": vaultID.rawValue,
            "sessionOutcome": [
                "state": "ready",
                "thisSession": [
                    "confirmedMemoryCount": 2,
                    "pendingReviewBatchCount": 1,
                ],
                "laterContinue": [
                    "canContinueLater": true,
                    "eligibleCueCount": 1,
                ],
            ],
        ]
    }

    private func migrationParitySnapshot(
        source: OwnerTruthMigrationParityClientGeneration,
        presentationHash: OwnerTruthMigrationParityDigest? = nil
    ) -> OwnerTruthMigrationParityViewStateSnapshot {
        OwnerTruthMigrationParityViewStateSnapshot(
            source: source,
            surface: .context,
            intentHash: migrationDigest("same-intent"),
            authority: OwnerTruthMigrationParityAuthorityBinding(
                ownerSubjectHash: migrationDigest("owner-a"),
                vaultHash: migrationDigest("vault-a"),
                authorityEpochHash: migrationDigest("epoch-v1")
            ),
            routeDecision: .allowed,
            visibility: .visible,
            phase: .ready,
            cacheState: .fresh,
            viewStateHash: migrationDigest("same-view-state"),
            citationSetHash: migrationDigest("same-citations"),
            projectionCheckpointHash: migrationDigest("same-checkpoint"),
            presentationHash: presentationHash ?? migrationDigest("presentation-legacy")
        )
    }

    private func migrationDigest(_ value: String) -> OwnerTruthMigrationParityDigest {
        OwnerTruthMigrationParityDigest.make("test|\(value)")
    }

    private func findView(
        in root: UIView,
        accessibilityIdentifier: String
    ) -> UIView? {
        if root.accessibilityIdentifier == accessibilityIdentifier {
            return root
        }
        for subview in root.subviews {
            if let match = findView(in: subview, accessibilityIdentifier: accessibilityIdentifier) {
                return match
            }
        }
        return nil
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

private final class GuidedRecommendationPresentationClientSpy:
    OwnerTruthGuidedRecommendationPresentationClient {
    var result: Result<OwnerTruthGuidedRecommendationPresentation, Error>?
    var feedbackResult: Result<OwnerTruthGuidedRecommendationFeedbackReceipt, Error>?
    var deferRead = false
    private var deferredCompletion: ((Result<OwnerTruthGuidedRecommendationPresentation, Error>) -> Void)?
    private(set) var requestCount = 0
    private(set) var feedbackCommands: [OwnerTruthGuidedRecommendationFeedbackCommand] = []

    func fetchOwnerTruthGuidedRecommendationPresentation(
        vaultID: OwnerTruthVaultID,
        completion: @escaping (Result<OwnerTruthGuidedRecommendationPresentation, Error>) -> Void
    ) {
        requestCount += 1
        if deferRead {
            deferredCompletion = completion
            return
        }
        completion(result ?? .failure(GuidedRecommendationPresentationClientSpyError.missingResult))
    }

    func submitOwnerTruthGuidedRecommendationFeedback(
        vaultID: OwnerTruthVaultID,
        command: OwnerTruthGuidedRecommendationFeedbackCommand,
        completion: @escaping (Result<OwnerTruthGuidedRecommendationFeedbackReceipt, Error>) -> Void
    ) {
        feedbackCommands.append(command)
        completion(feedbackResult ?? .failure(GuidedRecommendationPresentationClientSpyError.missingFeedbackResult))
    }

    func completeDeferred(_ result: Result<OwnerTruthGuidedRecommendationPresentation, Error>) {
        let completion = deferredCompletion
        deferredCompletion = nil
        completion?(result)
    }
}

private final class LifeMapPresentationClientSpy: OwnerTruthLifeMapPresentationClient {
    var result: Result<OwnerTruthLifeMapPresentation, Error>?
    var deferRead = false
    private var deferredCompletion: ((Result<OwnerTruthLifeMapPresentation, Error>) -> Void)?
    private(set) var requestCount = 0

    func fetchOwnerTruthLifeMapPresentation(
        vaultID: OwnerTruthVaultID,
        completion: @escaping (Result<OwnerTruthLifeMapPresentation, Error>) -> Void
    ) {
        requestCount += 1
        if deferRead {
            deferredCompletion = completion
            return
        }
        completion(result ?? .failure(LifeMapPresentationClientSpyError.missingResult))
    }

    func completeDeferred(_ result: Result<OwnerTruthLifeMapPresentation, Error>) {
        let completion = deferredCompletion
        deferredCompletion = nil
        completion?(result)
    }
}

private enum LifeMapPresentationClientSpyError: Error {
    case missingResult
}

private final class MemorySearchPresentationClientSpy: OwnerTruthMemorySearchPresentationClient {
    var result: Result<OwnerTruthMemorySearchPresentation, Error>?
    var deferRead = false
    private var deferredCompletion: ((Result<OwnerTruthMemorySearchPresentation, Error>) -> Void)?
    private(set) var requestCount = 0

    func searchOwnerTruthMemoryPresentation(
        vaultID: OwnerTruthVaultID,
        query: String,
        completion: @escaping (Result<OwnerTruthMemorySearchPresentation, Error>) -> Void
    ) {
        requestCount += 1
        if deferRead {
            deferredCompletion = completion
            return
        }
        completion(result ?? .failure(MemorySearchPresentationClientSpyError.missingResult))
    }

    func completeDeferred(_ result: Result<OwnerTruthMemorySearchPresentation, Error>) {
        let completion = deferredCompletion
        deferredCompletion = nil
        completion?(result)
    }
}

private enum MemorySearchPresentationClientSpyError: Error {
    case missingResult
}

private final class InterviewOutcomePresentationClientSpy:
    OwnerTruthInterviewOutcomePresentationClient {
    var result: Result<OwnerTruthInterviewOutcomePresentation, Error>?
    var deferRead = false
    private var deferredCompletion: ((Result<OwnerTruthInterviewOutcomePresentation, Error>) -> Void)?
    private(set) var requestCount = 0

    func fetchOwnerTruthInterviewOutcomePresentation(
        vaultID: OwnerTruthVaultID,
        sessionID: OwnerTruthRecordID,
        completion: @escaping (Result<OwnerTruthInterviewOutcomePresentation, Error>) -> Void
    ) {
        requestCount += 1
        if deferRead {
            deferredCompletion = completion
            return
        }
        completion(result ?? .failure(InterviewOutcomePresentationClientSpyError.missingResult))
    }

    func completeDeferred(_ result: Result<OwnerTruthInterviewOutcomePresentation, Error>) {
        let completion = deferredCompletion
        deferredCompletion = nil
        completion?(result)
    }
}

private enum InterviewOutcomePresentationClientSpyError: Error {
    case missingResult
}

private enum GuidedRecommendationPresentationClientSpyError: Error {
    case missingResult
    case missingFeedbackResult
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

private final class InterviewCandidateProposalStatusClientSpy: OwnerTruthInterviewCandidateProposalStatusClient {
    var readResult: Result<OwnerTruthInterviewCandidateProposalStatus, Error>?
    var deferRead = false
    private var deferredReadCompletion: ((Result<OwnerTruthInterviewCandidateProposalStatus, Error>) -> Void)?
    private(set) var requestCount = 0

    func fetchOwnerTruthInterviewCandidateProposalStatus(
        vaultID: OwnerTruthVaultID,
        reviewBatchID: OwnerTruthRecordID,
        completion: @escaping (Result<OwnerTruthInterviewCandidateProposalStatus, Error>) -> Void
    ) {
        requestCount += 1
        if deferRead {
            deferredReadCompletion = completion
            return
        }
        completion(readResult ?? .failure(InterviewCandidateProposalStatusClientSpyError.missingReadResult))
    }

    func completeDeferredRead(_ result: Result<OwnerTruthInterviewCandidateProposalStatus, Error>) {
        let completion = deferredReadCompletion
        deferredReadCompletion = nil
        completion?(result)
    }
}

private enum InterviewCandidateProposalStatusClientSpyError: Error {
    case missingReadResult
}

private final class InterviewCandidateConfirmationInboxClientSpy: OwnerTruthInterviewCandidateConfirmationInboxClient {
    var readResult: Result<OwnerTruthInterviewCandidateConfirmationInbox, Error>?
    var deferRead = false
    private var deferredReadCompletion: ((Result<OwnerTruthInterviewCandidateConfirmationInbox, Error>) -> Void)?
    private(set) var requestCount = 0

    func fetchOwnerTruthInterviewCandidateConfirmationInbox(
        vaultID: OwnerTruthVaultID,
        completion: @escaping (Result<OwnerTruthInterviewCandidateConfirmationInbox, Error>) -> Void
    ) {
        requestCount += 1
        if deferRead {
            deferredReadCompletion = completion
            return
        }
        completion(readResult ?? .failure(InterviewCandidateConfirmationInboxClientSpyError.missingReadResult))
    }

    func completeDeferredRead(_ result: Result<OwnerTruthInterviewCandidateConfirmationInbox, Error>) {
        let completion = deferredReadCompletion
        deferredReadCompletion = nil
        completion?(result)
    }
}

private enum InterviewCandidateConfirmationInboxClientSpyError: Error {
    case missingReadResult
}

private final class InterviewCandidateMemoryActivationInboxClientSpy: OwnerTruthInterviewCandidateMemoryActivationInboxClient {
    var readResult: Result<OwnerTruthInterviewCandidateMemoryActivationInbox, Error>?
    var deferRead = false
    private var deferredReadCompletion: ((Result<OwnerTruthInterviewCandidateMemoryActivationInbox, Error>) -> Void)?
    private(set) var requestCount = 0

    func fetchOwnerTruthInterviewCandidateMemoryActivationInbox(
        vaultID: OwnerTruthVaultID,
        completion: @escaping (Result<OwnerTruthInterviewCandidateMemoryActivationInbox, Error>) -> Void
    ) {
        requestCount += 1
        if deferRead {
            deferredReadCompletion = completion
            return
        }
        completion(readResult ?? .failure(InterviewCandidateMemoryActivationInboxClientSpyError.missingReadResult))
    }

    func completeDeferredRead(_ result: Result<OwnerTruthInterviewCandidateMemoryActivationInbox, Error>) {
        let completion = deferredReadCompletion
        deferredReadCompletion = nil
        completion?(result)
    }
}

private enum InterviewCandidateMemoryActivationInboxClientSpyError: Error {
    case missingReadResult
}

private final class InterviewCandidateMemoryProjectionRecoveryInboxClientSpy: OwnerTruthInterviewCandidateMemoryProjectionRecoveryInboxClient {
    var readResult: Result<OwnerTruthInterviewCandidateMemoryProjectionRecoveryInbox, Error>?
    private(set) var requestCount = 0

    func fetchOwnerTruthInterviewCandidateMemoryProjectionRecoveryInbox(
        vaultID: OwnerTruthVaultID,
        completion: @escaping (Result<OwnerTruthInterviewCandidateMemoryProjectionRecoveryInbox, Error>) -> Void
    ) {
        requestCount += 1
        completion(readResult ?? .failure(InterviewCandidateMemoryProjectionRecoveryInboxClientSpyError.missingReadResult))
    }
}

private enum InterviewCandidateMemoryProjectionRecoveryInboxClientSpyError: Error {
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

private final class InterviewCandidateConfirmationSingleActionClientSpy: OwnerTruthInterviewCandidateConfirmationSingleActionClient {
    var result: Result<OwnerTruthInterviewCandidateConfirmationSingleResult, Error>?
    private(set) var requestedCommands: [OwnerTruthInterviewCandidateConfirmationSingleCommand] = []

    func confirmOwnerTruthInterviewCandidateSingle(
        vaultID: OwnerTruthVaultID,
        command: OwnerTruthInterviewCandidateConfirmationSingleCommand,
        completion: @escaping (Result<OwnerTruthInterviewCandidateConfirmationSingleResult, Error>) -> Void
    ) {
        requestedCommands.append(command)
        completion(result ?? .failure(InterviewCandidateConfirmationSingleActionClientSpyError.missingActionResult))
    }
}

private enum InterviewCandidateConfirmationSingleActionClientSpyError: Error {
    case missingActionResult
}

private final class InterviewCandidateMemoryActivationClientSpy: OwnerTruthInterviewCandidateMemoryActivationClient {
    var result: Result<OwnerTruthInterviewCandidateMemoryActivationResult, Error>?
    private(set) var requestedCommands: [OwnerTruthInterviewCandidateMemoryActivationCommand] = []

    func activateOwnerTruthInterviewCandidateMemory(
        vaultID: OwnerTruthVaultID,
        command: OwnerTruthInterviewCandidateMemoryActivationCommand,
        completion: @escaping (Result<OwnerTruthInterviewCandidateMemoryActivationResult, Error>) -> Void
    ) {
        requestedCommands.append(command)
        completion(result ?? .failure(InterviewCandidateMemoryActivationClientSpyError.missingActivationResult))
    }
}

private enum InterviewCandidateMemoryActivationClientSpyError: Error {
    case missingActivationResult
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

private final class InterviewOrchestrationClientSpy: OwnerTruthInterviewOrchestrationClient {
    var readResult: Result<OwnerTruthInterviewOrchestrationRead, Error>?
    var deferRead = false
    private var deferredReadCompletion: ((Result<OwnerTruthInterviewOrchestrationRead, Error>) -> Void)?
    private(set) var requestCount = 0
    private(set) var lastSignals: OwnerTruthInterviewOrchestrationSignals?

    func fetchOwnerTruthInterviewOrchestration(
        vaultID: OwnerTruthVaultID,
        sessionID: OwnerTruthRecordID,
        signals: OwnerTruthInterviewOrchestrationSignals,
        completion: @escaping (Result<OwnerTruthInterviewOrchestrationRead, Error>) -> Void
    ) {
        requestCount += 1
        lastSignals = signals
        if deferRead {
            deferredReadCompletion = completion
            return
        }
        completion(readResult ?? .failure(InterviewOrchestrationClientSpyError.missingReadResult))
    }

    func completeDeferredRead(_ result: Result<OwnerTruthInterviewOrchestrationRead, Error>) {
        let completion = deferredReadCompletion
        deferredReadCompletion = nil
        completion?(result)
    }
}

private enum InterviewOrchestrationClientSpyError: Error {
    case missingReadResult
}

private final class InterviewNaturalInputClientSpy: OwnerTruthInterviewNaturalInputClient {
    var currentSessionHandler: ((OwnerTruthVaultID) -> Result<OwnerTruthInterviewNaturalInputCurrentSession, Error>)?
    var startHandler: ((OwnerTruthInterviewNaturalInputStartCommand) -> Result<OwnerTruthInterviewNaturalInputReceipt, Error>)?
    var appendHandler: ((OwnerTruthInterviewNaturalInputAppendCommand) -> Result<OwnerTruthInterviewNaturalInputReceipt, Error>)?
    var boundaryHandler: ((OwnerTruthInterviewBoundaryCommand) -> Result<OwnerTruthInterviewNaturalInputReceipt, Error>)?
    var pacingHandler: ((OwnerTruthInterviewPacingCommand) -> Result<OwnerTruthInterviewNaturalInputReceipt, Error>)?
    var topicSwitchHandler: ((OwnerTruthInterviewPauseForTopicSwitchCommand) -> Result<OwnerTruthInterviewNaturalInputReceipt, Error>)?
    var restoreDoNotAskHandler: ((OwnerTruthInterviewRestoreDoNotAskCommand) -> Result<OwnerTruthInterviewNaturalInputReceipt, Error>)?
    var restoreCooldownHandler: ((OwnerTruthInterviewRestoreCooldownCommand) -> Result<OwnerTruthInterviewNaturalInputReceipt, Error>)?
    var continuationHandler: ((OwnerTruthRecordID) -> Result<OwnerTruthInterviewNaturalInputContinuation, Error>)?
    var deferAppend = false
    var deferBoundary = false
    var deferPacing = false
    var deferTopicSwitch = false
    var deferRestoreCooldown = false
    private var deferredAppendCompletion: ((Result<OwnerTruthInterviewNaturalInputReceipt, Error>) -> Void)?
    private var deferredBoundaryCompletion: ((Result<OwnerTruthInterviewNaturalInputReceipt, Error>) -> Void)?
    private var deferredPacingCompletion: ((Result<OwnerTruthInterviewNaturalInputReceipt, Error>) -> Void)?
    private var deferredTopicSwitchCompletion: ((Result<OwnerTruthInterviewNaturalInputReceipt, Error>) -> Void)?
    private var deferredRestoreCooldownCompletion: ((Result<OwnerTruthInterviewNaturalInputReceipt, Error>) -> Void)?

    private(set) var startCommand: OwnerTruthInterviewNaturalInputStartCommand?
    private(set) var startCommands: [OwnerTruthInterviewNaturalInputStartCommand] = []
    private(set) var appendCommand: OwnerTruthInterviewNaturalInputAppendCommand?
    private(set) var boundaryCommand: OwnerTruthInterviewBoundaryCommand?
    private(set) var pacingCommand: OwnerTruthInterviewPacingCommand?
    private(set) var topicSwitchCommand: OwnerTruthInterviewPauseForTopicSwitchCommand?
    private(set) var restoreDoNotAskCommand: OwnerTruthInterviewRestoreDoNotAskCommand?
    private(set) var restoreCooldownCommand: OwnerTruthInterviewRestoreCooldownCommand?

    func fetchOwnerTruthInterviewNaturalInputCurrentSession(
        vaultID: OwnerTruthVaultID,
        completion: @escaping (Result<OwnerTruthInterviewNaturalInputCurrentSession, Error>) -> Void
    ) {
        if let currentSessionHandler {
            completion(currentSessionHandler(vaultID))
            return
        }
        do {
            completion(.success(try OwnerTruthInterviewNaturalInputCurrentSession(
                backendJSONObject: [
                    "schemaVersion": OwnerTruthInterviewNaturalInputCurrentSession.schemaVersion,
                    "vaultId": vaultID.rawValue,
                    "currentSession": NSNull(),
                ],
                expectedVaultID: vaultID
            )))
        } catch {
            completion(.failure(error))
        }
    }

    func startOwnerTruthInterviewNaturalInput(
        vaultID: OwnerTruthVaultID,
        command: OwnerTruthInterviewNaturalInputStartCommand,
        completion: @escaping (Result<OwnerTruthInterviewNaturalInputReceipt, Error>) -> Void
    ) {
        startCommand = command
        startCommands.append(command)
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

    func setOwnerTruthInterviewBoundary(
        vaultID: OwnerTruthVaultID,
        command: OwnerTruthInterviewBoundaryCommand,
        completion: @escaping (Result<OwnerTruthInterviewNaturalInputReceipt, Error>) -> Void
    ) {
        boundaryCommand = command
        if deferBoundary {
            deferredBoundaryCompletion = completion
            return
        }
        completion(boundaryHandler?(command) ?? .failure(
            InterviewNaturalInputClientSpyError.missingBoundaryResult
        ))
    }

    func recordOwnerTruthInterviewPacing(
        vaultID: OwnerTruthVaultID,
        command: OwnerTruthInterviewPacingCommand,
        completion: @escaping (Result<OwnerTruthInterviewNaturalInputReceipt, Error>) -> Void
    ) {
        pacingCommand = command
        if deferPacing {
            deferredPacingCompletion = completion
            return
        }
        completion(pacingHandler?(command) ?? .failure(
            InterviewNaturalInputClientSpyError.missingPacingResult
        ))
    }

    func restoreOwnerTruthInterviewDoNotAsk(
        vaultID: OwnerTruthVaultID,
        command: OwnerTruthInterviewRestoreDoNotAskCommand,
        completion: @escaping (Result<OwnerTruthInterviewNaturalInputReceipt, Error>) -> Void
    ) {
        restoreDoNotAskCommand = command
        completion(restoreDoNotAskHandler?(command) ?? .failure(
            InterviewNaturalInputClientSpyError.missingRestoreDoNotAskResult
        ))
    }

    func pauseOwnerTruthInterviewForTopicSwitch(
        vaultID: OwnerTruthVaultID,
        command: OwnerTruthInterviewPauseForTopicSwitchCommand,
        completion: @escaping (Result<OwnerTruthInterviewNaturalInputReceipt, Error>) -> Void
    ) {
        topicSwitchCommand = command
        if deferTopicSwitch {
            deferredTopicSwitchCompletion = completion
            return
        }
        completion(topicSwitchHandler?(command) ?? .failure(
            InterviewNaturalInputClientSpyError.missingTopicSwitchResult
        ))
    }

    func restoreOwnerTruthInterviewCooldown(
        vaultID: OwnerTruthVaultID,
        command: OwnerTruthInterviewRestoreCooldownCommand,
        completion: @escaping (Result<OwnerTruthInterviewNaturalInputReceipt, Error>) -> Void
    ) {
        restoreCooldownCommand = command
        if deferRestoreCooldown {
            deferredRestoreCooldownCompletion = completion
            return
        }
        completion(restoreCooldownHandler?(command) ?? .failure(
            InterviewNaturalInputClientSpyError.missingRestoreCooldownResult
        ))
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

    func completeDeferredBoundary(_ result: Result<OwnerTruthInterviewNaturalInputReceipt, Error>) {
        let completion = deferredBoundaryCompletion
        deferredBoundaryCompletion = nil
        completion?(result)
    }

    func completeDeferredPacing(_ result: Result<OwnerTruthInterviewNaturalInputReceipt, Error>) {
        let completion = deferredPacingCompletion
        deferredPacingCompletion = nil
        completion?(result)
    }

    func completeDeferredTopicSwitch(_ result: Result<OwnerTruthInterviewNaturalInputReceipt, Error>) {
        let completion = deferredTopicSwitchCompletion
        deferredTopicSwitchCompletion = nil
        completion?(result)
    }

    func completeDeferredRestoreCooldown(_ result: Result<OwnerTruthInterviewNaturalInputReceipt, Error>) {
        let completion = deferredRestoreCooldownCompletion
        deferredRestoreCooldownCompletion = nil
        completion?(result)
    }
}

private enum InterviewNaturalInputClientSpyError: Error {
    case missingStartResult
    case missingAppendResult
    case missingBoundaryResult
    case missingPacingResult
    case missingTopicSwitchResult
    case missingRestoreDoNotAskResult
    case missingRestoreCooldownResult
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

private final class CorrectionResolutionClientSpy: OwnerTruthCorrectionResolutionClient {
    var resolutionResult: Result<OwnerTruthCorrectionResolutionReceipt, Error>?
    var deferResolution = false
    private var deferredResolutionCompletion: ((Result<OwnerTruthCorrectionResolutionReceipt, Error>) -> Void)?
    private(set) var requestedCommands: [OwnerTruthCorrectionResolutionCommand] = []

    func resolveOwnerTruthCorrection(
        vaultID: OwnerTruthVaultID,
        expectedOwnerSubjectID: String,
        command: OwnerTruthCorrectionResolutionCommand,
        completion: @escaping (Result<OwnerTruthCorrectionResolutionReceipt, Error>) -> Void
    ) {
        requestedCommands.append(command)
        if deferResolution {
            deferredResolutionCompletion = completion
            return
        }
        completion(resolutionResult ?? .failure(CorrectionResolutionClientSpyError.missingResolutionResult))
    }

    func completeDeferredResolution(_ result: Result<OwnerTruthCorrectionResolutionReceipt, Error>) {
        let completion = deferredResolutionCompletion
        deferredResolutionCompletion = nil
        completion?(result)
    }
}

private enum CorrectionResolutionClientSpyError: Error {
    case missingResolutionResult
}

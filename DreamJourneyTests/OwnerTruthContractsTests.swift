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
}

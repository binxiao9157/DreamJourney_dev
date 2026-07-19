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

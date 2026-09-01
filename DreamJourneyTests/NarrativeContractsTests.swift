import Foundation
import XCTest

@testable import DreamJourneyCore

final class NarrativeContractsTests: XCTestCase {
    func testFixtureFreezesCrossPlatformWireVocabulary() throws {
        let fixture = try loadFixture()
        XCTAssertEqual(fixture.schemaVersion, narrativeFixtureSchemaVersion)
        XCTAssertEqual(fixture.enums.projectTypes, BookProjectType.allCases.map(\.rawValue))
        XCTAssertEqual(fixture.enums.narratorTypes, NarrativeNarratorType.allCases.map(\.rawValue))
        XCTAssertEqual(fixture.enums.bookProjectStates, BookProjectState.allCases.map(\.rawValue))
        XCTAssertEqual(fixture.enums.artifactTypes, NarrativeArtifactType.allCases.map(\.rawValue))
        XCTAssertEqual(fixture.enums.artifactStates, NarrativeArtifactState.allCases.map(\.rawValue))
        XCTAssertEqual(fixture.enums.commandTypes, NarrativeCommandType.allCases.map(\.rawValue))
        XCTAssertEqual(fixture.enums.jobStates, NarrativeJobState.allCases.map(\.rawValue))
        XCTAssertEqual(fixture.enums.errorCodes, NarrativeErrorCode.allCases.map(\.rawValue))
    }

    func testCommandAndErrorSamplesDecodeToTypedContracts() throws {
        let data = try fixtureData()
        let root = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let sample = try XCTUnwrap(root?["sample"] as? [String: Any])
        let decoder = JSONDecoder()

        let commandData = try JSONSerialization.data(withJSONObject: try XCTUnwrap(sample["command"]))
        let command = try decoder.decode(NarrativeCommandEnvelope.self, from: commandData)
        XCTAssertEqual(command.commandType, .generateAuditions)
        XCTAssertEqual(command.expectedProjectVersion, 7)
        XCTAssertTrue(command.confirmed)

        let errorData = try JSONSerialization.data(withJSONObject: try XCTUnwrap(sample["error"]))
        let error = try decoder.decode(NarrativeErrorEnvelope.self, from: errorData)
        XCTAssertEqual(error.errorCode, .projectVersionConflict)
        XCTAssertEqual(error.currentProjectVersion, 8)
        XCTAssertTrue(error.retryable)
    }

    func testFixtureIdentifiersTimestampsAndVersionsAreStrict() throws {
        let fixture = try loadFixture()
        XCTAssertNotNil(UUID(uuidString: fixture.sample.project.projectID))
        XCTAssertNotNil(UUID(uuidString: fixture.sample.artifact.artifactVersionID))
        XCTAssertNotNil(UUID(uuidString: fixture.sample.artifact.memorySnapshotID))
        XCTAssertNotNil(UUID(uuidString: fixture.sample.job.jobID))
        XCTAssertNotNil(UUID(uuidString: fixture.sample.job.commandID))
        let formatter = ISO8601DateFormatter()
        XCTAssertNotNil(formatter.date(from: fixture.sample.project.updatedAt))
        XCTAssertNotNil(formatter.date(from: fixture.sample.artifact.createdAt))
        XCTAssertNotNil(formatter.date(from: fixture.sample.job.createdAt))
        XCTAssertGreaterThanOrEqual(fixture.sample.project.projectVersion, 0)
        XCTAssertGreaterThanOrEqual(fixture.sample.artifact.versionNumber, 1)
    }

    func testUnknownAndMalformedValuesFailClosed() throws {
        var command = try XCTUnwrap(
            (try JSONSerialization.jsonObject(with: fixtureData()) as? [String: Any])?["sample"] as? [String: Any]
        )["command"] as? [String: Any] ?? [:]
        command["commandType"] = "generateAudioBook"
        XCTAssertThrowsError(
            try JSONDecoder().decode(
                NarrativeCommandEnvelope.self,
                from: JSONSerialization.data(withJSONObject: command)
            )
        )

        var error = try XCTUnwrap(
            (try JSONSerialization.jsonObject(with: fixtureData()) as? [String: Any])?["sample"] as? [String: Any]
        )["error"] as? [String: Any] ?? [:]
        error["currentProjectVersion"] = -1
        XCTAssertThrowsError(
            try JSONDecoder().decode(
                NarrativeErrorEnvelope.self,
                from: JSONSerialization.data(withJSONObject: error)
            )
        )
    }

    func testTransitionExamplesUseOnlyFrozenStates() throws {
        let fixture = try loadFixture()
        try assertTransitions(fixture.transitionCases.bookProject, enumType: BookProjectState.self)
        try assertTransitions(fixture.transitionCases.artifact, enumType: NarrativeArtifactState.self)
        try assertTransitions(fixture.transitionCases.job, enumType: NarrativeJobState.self)
    }

    func testFixtureContainsNoOutOfScopeAuthorityOrMediaContract() throws {
        let text = String(decoding: try fixtureData(), as: UTF8.self)
        for forbidden in ["audio", "voiceId", "publication", "providerKey", "localBodyAuthority"] {
            XCTAssertFalse(text.contains(forbidden), "Fixture contains out-of-scope field \(forbidden)")
        }
    }

    func testClientStateMachineRequiresTwoExplicitStyleConfirmations() {
        XCTAssertTrue(NarrativeStateMachine.allows(.selectAudition, from: .auditionsReady))
        XCTAssertFalse(NarrativeStateMachine.allows(.confirmGoldenSample, from: .auditionsReady))
        XCTAssertTrue(NarrativeStateMachine.allows(.confirmGoldenSample, from: .goldenSampleReview))
        XCTAssertFalse(NarrativeStateMachine.allows(.generateOutline, from: .goldenSampleReview))
        XCTAssertTrue(NarrativeStateMachine.allows(.generateOutline, from: .toneConfirmed))
    }

    func testStoryClusterDecodesCanonicalAndLegacyReadinessFields() throws {
        let canonical = try decodeStoryCluster([
            "clusterKey": "education",
            "title": "求学经历",
            "memoryVersionIds": ["memory-version-1"],
            "itemCount": 1,
        ])
        XCTAssertEqual(canonical.clusterKey, "education")
        XCTAssertEqual(canonical.itemCount, 1)

        let legacy = try decodeStoryCluster([
            "clusterId": "education",
            "title": "求学经历",
            "memoryVersionIds": ["memory-version-1"],
            "memoryCount": 1,
            "recommended": true,
        ])
        XCTAssertEqual(legacy, canonical)
    }

    func testNarrativeRequestRefreshesOnlyRecoverablePolicyFailures() {
        for reason in [
            "capturedPolicyExpired",
            "policyVersionChanged",
            "missingPolicyCache",
            "expiredPolicyCache",
        ] {
            XCTAssertTrue(NarrativeWritingPolicyRefreshPolicy.shouldRefresh(after: reason))
        }
        for reason in [
            "accountGenerationChanged",
            "emergencyDisabled",
            "featureDisabled",
            "productClosed",
        ] {
            XCTAssertFalse(NarrativeWritingPolicyRefreshPolicy.shouldRefresh(after: reason))
        }
    }

    func testArtifactVersionCommandsAreLimitedToReviewableWritingStates() {
        XCTAssertTrue(NarrativeStateMachine.allows(.editArtifact, from: .outlineReview))
        XCTAssertTrue(NarrativeStateMachine.allows(.restoreArtifactVersion, from: .writing))
        XCTAssertFalse(NarrativeStateMachine.allows(.editArtifact, from: .auditionsReady))
        XCTAssertFalse(NarrativeStateMachine.allows(.restoreArtifactVersion, from: .archived))
    }

    func testProgressiveAuditionArtifactExposesItsGenerationJob() throws {
        let jobId = UUID().uuidString
        let artifact = NarrativeArtifact(
            schemaVersion: narrativeArtifactSchemaVersion,
            artifactVersionId: UUID().uuidString,
            projectId: UUID().uuidString,
            artifactType: .writingAudition,
            artifactKey: "documentary",
            versionNumber: 1,
            parentVersionId: nil,
            memorySnapshotId: UUID().uuidString,
            state: .readyForReview,
            contentText: "一段试镜稿",
            payload: ["generationJobId": .string(jobId)],
            contentHash: String(repeating: "a", count: 64),
            origin: "generated",
            modelId: "deepseek-chat",
            promptVersion: "narrative-writing-v3-progressive-auditions",
            pipelineVersion: "selection-manifest-progressive-artifact-repair-v3",
            createdAt: "2026-09-01T00:00:00+00:00"
        )

        XCTAssertEqual(try artifact.validated().generationJobId, jobId)
    }

    func testPausedProjectCanOnlyResumeOrArchive() {
        XCTAssertTrue(NarrativeStateMachine.allows(.resumeProject, from: .paused))
        XCTAssertTrue(NarrativeStateMachine.allows(.archiveProject, from: .paused))
        XCTAssertFalse(NarrativeStateMachine.allows(.pauseProject, from: .paused))
        XCTAssertFalse(NarrativeStateMachine.allows(.pauseProject, from: .generatingAuditions))
        XCTAssertFalse(NarrativeStateMachine.allows(.pauseProject, from: .generatingGoldenSample))
        XCTAssertFalse(NarrativeStateMachine.allows(.generateChapter, from: .paused))
    }

    func testWritingAccessUsesFreshAuthorizationWithoutRefreshing() throws {
        var refreshCount = 0
        let preflight = NarrativeWritingAccessPreflight(
            isAuthorized: { true },
            refreshPolicy: { completion in
                refreshCount += 1
                completion(true)
            }
        )

        var result: Result<Void, NarrativeWritingAccessPreflightError>?
        preflight.authorize { result = $0 }

        XCTAssertNoThrow(try XCTUnwrap(result).get())
        XCTAssertEqual(refreshCount, 0)
    }

    func testWritingAccessRefreshesColdPolicyBeforeAllowingEntry() throws {
        var authorized = false
        var refreshCount = 0
        let preflight = NarrativeWritingAccessPreflight(
            isAuthorized: { authorized },
            refreshPolicy: { completion in
                refreshCount += 1
                authorized = true
                completion(true)
            }
        )

        var result: Result<Void, NarrativeWritingAccessPreflightError>?
        preflight.authorize { result = $0 }

        XCTAssertNoThrow(try XCTUnwrap(result).get())
        XCTAssertEqual(refreshCount, 1)
    }

    func testWritingAccessFailsClosedWhenRefreshCannotAuthorize() throws {
        let preflight = NarrativeWritingAccessPreflight(
            isAuthorized: { false },
            refreshPolicy: { completion in completion(true) }
        )

        var result: Result<Void, NarrativeWritingAccessPreflightError>?
        preflight.authorize { result = $0 }

        XCTAssertThrowsError(try XCTUnwrap(result).get()) { error in
            XCTAssertEqual(error as? NarrativeWritingAccessPreflightError, .unavailable)
        }
    }

    private func assertTransitions<T>(
        _ cases: TransitionCases,
        enumType: T.Type
    ) throws where T: RawRepresentable, T.RawValue == String {
        XCTAssertFalse(cases.allowed.isEmpty)
        XCTAssertFalse(cases.rejected.isEmpty)
        let allowed = Set(cases.allowed.map { $0.joined(separator: "->") })
        let rejected = Set(cases.rejected.map { $0.joined(separator: "->") })
        XCTAssertTrue(allowed.isDisjoint(with: rejected))
        for pair in cases.allowed + cases.rejected {
            XCTAssertEqual(pair.count, 2)
            XCTAssertNotNil(T(rawValue: pair[0]))
            XCTAssertNotNil(T(rawValue: pair[1]))
        }
    }

    private func loadFixture() throws -> ContractFixture {
        try JSONDecoder().decode(ContractFixture.self, from: fixtureData())
    }

    private func fixtureData() throws -> Data {
#if SWIFT_PACKAGE
        let bundle = Bundle.module
#else
        let bundle = Bundle(for: NarrativeContractsTests.self)
#endif
        let url = try XCTUnwrap(
            bundle.url(forResource: "contract_v1", withExtension: "json")
        )
        return try Data(contentsOf: url)
    }

    private func decodeStoryCluster(_ object: [String: Any]) throws -> NarrativeStoryCluster {
        try JSONDecoder().decode(
            NarrativeStoryCluster.self,
            from: JSONSerialization.data(withJSONObject: object)
        )
    }
}

private struct ContractFixture: Decodable {
    let schemaVersion: String
    let enums: FixtureEnums
    let sample: FixtureSample
    let transitionCases: FixtureTransitions
}

private struct FixtureEnums: Decodable {
    let projectTypes: [String]
    let narratorTypes: [String]
    let bookProjectStates: [String]
    let artifactTypes: [String]
    let artifactStates: [String]
    let commandTypes: [String]
    let jobStates: [String]
    let errorCodes: [String]
}

private struct FixtureSample: Decodable {
    let project: FixtureProject
    let artifact: FixtureArtifact
    let job: FixtureJob
}

private struct FixtureProject: Decodable {
    let projectID: String
    let projectVersion: Int
    let updatedAt: String

    enum CodingKeys: String, CodingKey {
        case projectID = "projectId"
        case projectVersion
        case updatedAt
    }
}

private struct FixtureArtifact: Decodable {
    let artifactVersionID: String
    let versionNumber: Int
    let memorySnapshotID: String
    let createdAt: String

    enum CodingKeys: String, CodingKey {
        case artifactVersionID = "artifactVersionId"
        case versionNumber
        case memorySnapshotID = "memorySnapshotId"
        case createdAt
    }
}

private struct FixtureJob: Decodable {
    let jobID: String
    let commandID: String
    let createdAt: String

    enum CodingKeys: String, CodingKey {
        case jobID = "jobId"
        case commandID = "commandId"
        case createdAt
    }
}

private struct FixtureTransitions: Decodable {
    let bookProject: TransitionCases
    let artifact: TransitionCases
    let job: TransitionCases
}

private struct TransitionCases: Decodable {
    let allowed: [[String]]
    let rejected: [[String]]
}

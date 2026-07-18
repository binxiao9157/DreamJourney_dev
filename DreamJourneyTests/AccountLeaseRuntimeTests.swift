import XCTest
#if canImport(DreamJourney)
@testable import DreamJourney
#elseif canImport(DreamJourneyCore)
@testable import DreamJourneyCore
#endif

final class AccountLeaseRuntimeTests: XCTestCase {
    func testStaleAccountCallbackIsRejectedAfterAccountSwitch() throws {
        let runtime = AccountLeaseRuntime(authorityEpoch: "epoch-v1")
        runtime.publish(session: session(
            subjectId: "owner-a",
            vaultId: "vault-a",
            generation: 7,
            generationId: UUID(uuidString: "00000000-0000-0000-0000-000000000007")!
        ))
        let staleLease = try XCTUnwrap(runtime.capture(forSubjectId: "owner-a"))

        runtime.publish(session: session(
            subjectId: "owner-b",
            vaultId: "vault-b",
            generation: 8,
            generationId: UUID(uuidString: "00000000-0000-0000-0000-000000000008")!
        ))

        let result = runtime.validate(staleLease, at: .ui)

        XCTAssertFalse(result.allowed)
        XCTAssertEqual(result.checkpoint, .ui)
        XCTAssertEqual(result.reason, .subjectMismatch)
        XCTAssertEqual(runtime.diagnosticsSnapshot().rejectedByCheckpoint["ui"], 1)
    }

    func testStaleGenerationIsRejectedWhenSameOwnerSessionRefreshes() throws {
        let runtime = AccountLeaseRuntime(authorityEpoch: "epoch-v1")
        runtime.publish(session: session(
            subjectId: "owner-a",
            vaultId: "vault-a",
            generation: 7,
            generationId: UUID(uuidString: "00000000-0000-0000-0000-000000000007")!
        ))
        let staleLease = try XCTUnwrap(runtime.capture(forSubjectId: "owner-a"))

        runtime.publish(session: session(
            subjectId: "owner-a",
            vaultId: "vault-a",
            generation: 8,
            generationId: UUID(uuidString: "00000000-0000-0000-0000-000000000008")!
        ))

        let result = runtime.validate(staleLease, at: .runtime)

        XCTAssertFalse(result.allowed)
        XCTAssertEqual(result.reason, .generationMismatch)
    }

    private func session(
        subjectId: String,
        vaultId: String,
        generation: UInt64,
        generationId: UUID
    ) -> AccountSession {
        AccountSession(
            subjectId: subjectId,
            vaultId: vaultId,
            sessionId: "session-\(generation)",
            tokenFamilyId: "family-\(generation)",
            sessionVersion: Int(generation),
            generation: generation,
            generationId: generationId,
            state: .active,
            activatedAt: Date(timeIntervalSince1970: 1_700_000_000)
        )
    }
}

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

    func testFeatureRuntimeContextRejectsMismatchedLifecycleOrPolicyAuthority() throws {
        let lease = AccountLease(
            subjectId: "owner-a",
            vaultId: "vault-a",
            sessionId: "session-a",
            generation: 7,
            generationId: UUID(uuidString: "00000000-0000-0000-0000-000000000007")!,
            authorityEpoch: "epoch-v1"
        )

        XCTAssertNil(AppFeatureRuntimeContext(
            accountLease: lease,
            lifecycleGeneration: 8,
            releasePolicyAuthorityEpoch: "epoch-v1"
        ))
        XCTAssertNil(AppFeatureRuntimeContext(
            accountLease: lease,
            lifecycleGeneration: 7,
            releasePolicyAuthorityEpoch: "epoch-v2"
        ))

        let context = try XCTUnwrap(AppFeatureRuntimeContext(
            accountLease: lease,
            lifecycleGeneration: 7,
            releasePolicyAuthorityEpoch: "epoch-v1"
        ))
        XCTAssertEqual(context.accountLease, lease)
        XCTAssertEqual(context.lifecycleGeneration, lease.generation)
        XCTAssertEqual(context.releasePolicyAuthorityEpoch, lease.authorityEpoch)
    }

    func testLifecycleEventReceiptMinimizesActiveRuntimeContext() throws {
        let lease = AccountLease(
            subjectId: "owner-a",
            vaultId: "vault-a",
            sessionId: "session-a",
            generation: 7,
            generationId: UUID(uuidString: "00000000-0000-0000-0000-000000000007")!,
            authorityEpoch: "epoch-v1"
        )
        let context = try XCTUnwrap(AppFeatureRuntimeContext(
            accountLease: lease,
            lifecycleGeneration: 7,
            releasePolicyAuthorityEpoch: "epoch-v1"
        ))

        let foregroundReceipt = AppLifecycleEventReceipt(
            event: .willEnterForeground,
            sequence: 3,
            runtimeContext: context
        )
        XCTAssertEqual(foregroundReceipt.runtimeDisposition, .activeRuntime)
        XCTAssertEqual(foregroundReceipt.lifecycleGeneration, 7)
        XCTAssertTrue(foregroundReceipt.hasReleasePolicyAuthority)
        XCTAssertTrue(foregroundReceipt.canRunPrivateForegroundRefresh)

        let backgroundReceipt = AppLifecycleEventReceipt(
            event: .didEnterBackground,
            sequence: 4,
            runtimeContext: nil
        )
        XCTAssertEqual(backgroundReceipt.runtimeDisposition, .noActiveRuntime)
        XCTAssertNil(backgroundReceipt.lifecycleGeneration)
        XCTAssertFalse(backgroundReceipt.hasReleasePolicyAuthority)
        XCTAssertFalse(backgroundReceipt.canRunPrivateForegroundRefresh)
    }

    func testLifecycleEventNotificationOnlyCarriesRoutingMetadata() throws {
        let receipt = AppLifecycleEventReceipt(
            event: .willEnterForeground,
            sequence: 9,
            runtimeContext: nil
        )
        let userInfo = AppLifecycleEventNotification.userInfo(for: receipt)

        XCTAssertEqual(
            AppLifecycleEventNotification.event(from: userInfo),
            .willEnterForeground
        )
        XCTAssertEqual(userInfo[AppLifecycleEventNotification.sequenceKey] as? NSNumber, 9)
        XCTAssertEqual(
            userInfo[AppLifecycleEventNotification.runtimeDispositionKey] as? String,
            AppLifecycleRuntimeDisposition.noActiveRuntime.rawValue
        )
        XCTAssertNil(userInfo[AppLifecycleEventNotification.lifecycleGenerationKey])
        XCTAssertNil(userInfo["subjectId"])
        XCTAssertNil(userInfo["vaultId"])
        XCTAssertNil(userInfo["sessionId"])
        XCTAssertNil(userInfo["authorityEpoch"])
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

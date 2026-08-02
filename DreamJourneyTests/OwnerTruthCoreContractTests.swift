import XCTest

@testable import DreamJourneyCore

final class OwnerTruthCoreContractTests: XCTestCase {
    func testTextSourceCaptureCommandRemainsPureDomainContract() throws {
        let command = try OwnerTruthTextSourceCaptureCommand(
            commandID: UUID(uuidString: "00000000-0000-0000-0000-000000000401")!,
            expectedAuthorityEpoch: 3,
            text: "  我记得那天傍晚一起散步。  ",
            purpose: "memoryCapture",
            clientCreatedAt: Date(timeIntervalSince1970: 1_775_000_000)
        )

        XCTAssertEqual(command.backendPayload["content"] as? String, "我记得那天傍晚一起散步。")
        XCTAssertEqual(command.backendPayload["expectedAuthorityEpoch"] as? Int, 3)
        XCTAssertEqual(command.backendPayload["purpose"] as? String, "memoryCapture")
    }

    func testCompatibilityRuntimeAcceptsAnInjectedCoreClient() {
        let runtime = OwnerTruthKBLiteCompatibilityProjectionRuntime(
            client: CoreKBLiteCompatibilityClient(),
            qaGateEnabled: { false }
        )

        XCTAssertEqual(runtime.viewState, .idle)
    }

    func testAccountLeaseKeepsVaultAndAuthorityTogether() {
        let lease = AccountLease(
            subjectId: "owner-a",
            vaultId: "vault-a",
            sessionId: "session-a",
            generation: 4,
            generationId: UUID(uuidString: "00000000-0000-0000-0000-000000000402")!,
            authorityEpoch: "authority-a"
        )

        XCTAssertEqual(lease.subjectId, "owner-a")
        XCTAssertEqual(lease.vaultId, "vault-a")
        XCTAssertEqual(lease.authorityEpoch, "authority-a")
    }
}

private final class CoreKBLiteCompatibilityClient: OwnerTruthKBLiteCompatibilityClient {
    func fetchOwnerTruthKBLiteCompatibilityReadEnvelope(
        vaultID: OwnerTruthVaultID,
        expectedOwnerSubjectID: String,
        completion: @escaping (Result<OwnerTruthKBLiteCompatibilityReadEnvelope, Error>) -> Void
    ) {
        completion(.failure(CoreKBLiteCompatibilityClientError.unused))
    }
}

private enum CoreKBLiteCompatibilityClientError: Error {
    case unused
}

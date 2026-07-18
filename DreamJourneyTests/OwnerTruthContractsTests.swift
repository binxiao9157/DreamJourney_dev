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
}

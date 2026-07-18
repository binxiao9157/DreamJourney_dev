import Foundation

// Read-only port for the V1 schema. Commands are deliberately deferred to
// WI-S1-01-02 so no legacy Archive item becomes Owner Truth by accident.
protocol OwnerTruthReadRepository: Sendable {
    func source(
        vaultID: OwnerTruthVaultID,
        sourceID: OwnerTruthRecordID
    ) async throws -> OwnerTruthSource?

    func memory(
        vaultID: OwnerTruthVaultID,
        memoryID: OwnerTruthRecordID
    ) async throws -> OwnerTruthMemoryRecord?

    func memoryVersions(
        vaultID: OwnerTruthVaultID,
        memoryID: OwnerTruthRecordID
    ) async throws -> [OwnerTruthMemoryVersion]
}

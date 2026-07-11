import Foundation

enum KnowledgeLocalStorageWriteResult: Equatable {
    case committedAndHardened
    case committedWithHardeningWarning
}

enum KnowledgeLocalStoragePolicy {
    static func prepareDirectory(at directoryURL: URL) throws {
        try FileManager.default.createDirectory(
            at: directoryURL,
            withIntermediateDirectories: true
        )
        try hardenExistingItem(at: directoryURL)
    }

    @discardableResult
    static func write(_ data: Data, to fileURL: URL) throws -> KnowledgeLocalStorageWriteResult {
        try prepareDirectory(at: fileURL.deletingLastPathComponent())
        try data.write(
            to: fileURL,
            options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication]
        )
        // Atomic replacement creates a new inode, so attributes must be applied afterwards.
        do {
            try hardenExistingItem(at: fileURL)
            return .committedAndHardened
        } catch {
            // The payload is already committed. Report degraded hardening without making
            // callers retry a business operation that may otherwise execute twice.
            print(
                "[KnowledgeStorage] postCommitHardeningFailed " +
                "file=\(fileURL.lastPathComponent) error=\(error.localizedDescription)"
            )
            return .committedWithHardeningWarning
        }
    }

    static func hardenExistingItem(at fileURL: URL) throws {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return }

        var mutableURL = fileURL
        var resourceValues = URLResourceValues()
        resourceValues.isExcludedFromBackup = true
        try mutableURL.setResourceValues(resourceValues)

        try FileManager.default.setAttributes(
            [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication],
            ofItemAtPath: fileURL.path
        )
    }
}

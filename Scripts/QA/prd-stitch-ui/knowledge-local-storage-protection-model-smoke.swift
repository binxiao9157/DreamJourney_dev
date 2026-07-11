import Foundation

@main
enum KnowledgeLocalStorageProtectionModelSmoke {
    static func main() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("dj-knowledge-storage-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let file = root.appendingPathComponent("kb_sync_base_test.json")

        let firstWrite = try KnowledgeLocalStoragePolicy.write(Data("first".utf8), to: file)
        require(firstWrite == .committedAndHardened, "the host write must report full hardening")
        try verifyProtection(file, expectedContents: "first")

        let replacementWrite = try KnowledgeLocalStoragePolicy.write(Data("replacement".utf8), to: file)
        require(replacementWrite == .committedAndHardened, "atomic replacement must report final inode hardening")
        try verifyProtection(file, expectedContents: "replacement")

        print("Knowledge local storage protection model smoke passed")
    }

    private static func verifyProtection(_ file: URL, expectedContents: String) throws {
        let contents = try String(contentsOf: file, encoding: .utf8)
        require(contents == expectedContents, "atomic replacement must preserve the requested payload")

        let values = try file.resourceValues(forKeys: [.isExcludedFromBackupKey])
        require(values.isExcludedFromBackup == true, "knowledge files must be excluded from backup")

        let attributes = try FileManager.default.attributesOfItem(atPath: file.path)
        let protection = attributes[.protectionKey] as? FileProtectionType
        require(
            protection == .completeUntilFirstUserAuthentication,
            "the final inode must retain first-unlock file protection"
        )
    }

    private static func require(_ condition: @autoclosure () -> Bool, _ message: String) {
        guard condition() else { fatalError(message) }
    }
}

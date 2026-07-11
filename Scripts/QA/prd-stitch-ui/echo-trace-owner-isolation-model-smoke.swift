import CryptoKit
import Foundation

@main
enum EchoTraceOwnerIsolationModelSmoke {
    private static let legacyKeys = [
        "DreamJourney.EchoTraceStore.records.v1",
        "DreamJourney.EchoRuntimeDiagnosticsStore.snapshots.v1",
        "DreamJourney.EchoTraceEvidencePackageStore.packages.v1",
        "DreamJourney.EchoQAEvidenceBundleStore.bundles.v2",
    ]

    static func main() throws {
        let suiteName = "EchoTraceOwnerIsolationModelSmoke.\(UUID().uuidString)"
        let exportRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent(suiteName, isDirectory: true)
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            fatalError("unable to create isolated defaults")
        }
        defer {
            defaults.removePersistentDomain(forName: suiteName)
            try? FileManager.default.removeItem(at: exportRoot)
        }

        for key in legacyKeys {
            defaults.set(Data("legacy".utf8), forKey: key)
        }

        let scope = OwnerScope()
        let store = ScopedStore(
            defaults: defaults,
            scope: scope,
            legacyKeys: legacyKeys,
            exportRoot: exportRoot
        )
        let ownerA = "account-A"
        let ownerB = "account-B"

        store.activate(owner: ownerA)
        require(legacyKeys.allSatisfy { defaults.object(forKey: $0) == nil }, "activation must purge legacy global keys")
        require(store.record("A-1", owner: ownerA), "active owner A should be writable")
        require(!store.record("B-stale", owner: ownerB), "non-active owner B must be rejected")
        require(store.read(owner: ownerA) == ["A-1"], "owner A should read only A records")
        require(store.read(owner: ownerB).isEmpty, "owner B must not read owner A records")
        require(
            derivedEvidenceOwner(
                packageOwner: ownerA,
                traceOwner: ownerA,
                runtimeOwner: ownerA,
                sessionOwner: ownerA,
                synthesisOwner: ownerA
            ) == ownerA,
            "matching evidence owners should be accepted"
        )
        require(
            derivedEvidenceOwner(
                packageOwner: ownerA,
                traceOwner: ownerA,
                runtimeOwner: ownerB,
                sessionOwner: ownerA,
                synthesisOwner: ownerA
            ) == nil,
            "mismatched runtime owner must be rejected"
        )
        require(
            derivedEvidenceOwner(
                packageOwner: ownerA,
                traceOwner: ownerA,
                runtimeOwner: ownerA,
                sessionOwner: ownerB,
                synthesisOwner: ownerA
            ) == nil,
            "mismatched provider session owner must be rejected"
        )
        require(
            derivedEvidenceOwner(
                packageOwner: ownerA,
                traceOwner: ownerA,
                runtimeOwner: ownerA,
                sessionOwner: ownerA,
                synthesisOwner: ownerB
            ) == nil,
            "mismatched synthesis owner must be rejected"
        )

        let ownerAExportURL = try store.exportFile(owner: ownerA)
        require(FileManager.default.fileExists(atPath: ownerAExportURL.path), "owner A export should exist before switching")
        require(!ownerAExportURL.path.contains(ownerA), "export paths must not contain raw owner IDs")

        store.switchOwner(from: ownerA, to: ownerB)
        require(!FileManager.default.fileExists(atPath: ownerAExportURL.path), "switch must delete previous owner export files")
        require(store.read(owner: ownerA).isEmpty, "switch must clear and reject the previous owner")
        require(!store.record("A-late", owner: ownerA), "late owner A callback must be rejected")
        require(store.record("B-1", owner: ownerB), "new active owner B should be writable")
        let ownerBExport = try store.export(owner: ownerB)
        require(ownerBExport == ["B-1"], "export must contain only current owner B data")
        let ownerBExportURL = try store.exportFile(owner: ownerB)
        require(FileManager.default.fileExists(atPath: ownerBExportURL.path), "owner B export should exist before logout")
        require(throwsError { _ = try store.export(owner: ownerA) }, "previous owner export must be rejected")

        let persistedKeys = defaults.dictionaryRepresentation().keys.filter { $0.contains("EchoTraceModel.records") }
        require(persistedKeys.count == 1, "only the current owner key should remain after switching")
        require(!persistedKeys[0].contains(ownerB), "storage keys must not contain raw owner IDs")

        store.logout(owner: ownerB)
        require(!FileManager.default.fileExists(atPath: ownerBExportURL.path), "logout must delete current owner export files")
        require(store.read(owner: ownerB).isEmpty, "logout must clear current owner records")
        require(!store.record("B-late", owner: ownerB), "late owner B callback must not recreate data after logout")
        require(defaults.dictionaryRepresentation().keys.allSatisfy { !$0.contains("EchoTraceModel.records") }, "logout must remove owner storage")

        print("Echo trace owner isolation model smoke passed")
    }

    private static func throwsError(_ operation: () throws -> Void) -> Bool {
        do {
            try operation()
            return false
        } catch {
            return true
        }
    }

    private static func derivedEvidenceOwner(
        packageOwner: String?,
        traceOwner: String?,
        runtimeOwner: String?,
        sessionOwner: String?,
        synthesisOwner: String?
    ) -> String? {
        func normalized(_ owner: String?) -> String? {
            let value = owner?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            guard !value.isEmpty, value.lowercased() != "unknown" else { return nil }
            return value
        }

        guard let package = normalized(packageOwner) else { return nil }
        let owners = [traceOwner, runtimeOwner, sessionOwner, synthesisOwner]
        guard owners.allSatisfy({ $0 == nil || normalized($0) == package }) else {
            return nil
        }
        return package
    }

    private static func require(_ condition: @autoclosure () -> Bool, _ message: String) {
        guard condition() else { fatalError(message) }
    }
}

private final class OwnerScope {
    private let lock = NSRecursiveLock()
    private var activeDigest: String?

    func withActiveOwner<T>(_ owner: String, operation: (String) throws -> T) rethrows -> T? {
        guard let digest = Self.digest(owner) else { return nil }
        lock.lock()
        defer { lock.unlock() }
        guard digest == activeDigest else { return nil }
        return try operation(digest)
    }

    func transition(to owner: String?, cleanup: (String?) -> Void) {
        lock.lock()
        defer { lock.unlock() }
        let previousDigest = activeDigest
        activeDigest = nil
        cleanup(previousDigest)
        activeDigest = owner.flatMap(Self.digest)
    }

    private static func digest(_ owner: String) -> String? {
        let normalized = owner.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty, normalized.lowercased() != "unknown" else { return nil }
        return SHA256.hash(data: Data("echo-trace-owner-v2|\(normalized)".utf8))
            .map { String(format: "%02x", $0) }
            .joined()
    }
}

private final class ScopedStore {
    private let defaults: UserDefaults
    private let scope: OwnerScope
    private let legacyKeys: [String]
    private let exportRoot: URL

    init(defaults: UserDefaults, scope: OwnerScope, legacyKeys: [String], exportRoot: URL) {
        self.defaults = defaults
        self.scope = scope
        self.legacyKeys = legacyKeys
        self.exportRoot = exportRoot
    }

    func activate(owner: String) {
        scope.transition(to: owner) { _ in purgeLegacy() }
    }

    func switchOwner(from oldOwner: String, to newOwner: String) {
        scope.transition(to: newOwner) { previousDigest in
            if let previousDigest {
                defaults.removeObject(forKey: storageKey(digest: previousDigest))
                clearExports(digest: previousDigest)
            }
            purgeLegacy()
        }
    }

    func logout(owner: String) {
        scope.transition(to: nil) { previousDigest in
            if let previousDigest {
                defaults.removeObject(forKey: storageKey(digest: previousDigest))
                clearExports(digest: previousDigest)
            }
            purgeLegacy()
        }
    }

    func record(_ value: String, owner: String) -> Bool {
        scope.withActiveOwner(owner) { digest in
            var values = load(digest: digest)
            values.append(value)
            defaults.set(try! JSONEncoder().encode(values), forKey: storageKey(digest: digest))
            return true
        } ?? false
    }

    func read(owner: String) -> [String] {
        scope.withActiveOwner(owner) { load(digest: $0) } ?? []
    }

    func export(owner: String) throws -> [String] {
        guard let values = scope.withActiveOwner(owner, operation: { load(digest: $0) }) else {
            throw NSError(domain: "EchoTraceOwnerIsolationModelSmoke", code: 1)
        }
        return values
    }

    func exportFile(owner: String) throws -> URL {
        guard let result = try scope.withActiveOwner(owner, operation: { digest in
            let url = exportRoot
                .appendingPathComponent(digest, isDirectory: true)
                .appendingPathComponent("echo-trace.json", isDirectory: false)
            try FileManager.default.createDirectory(
                at: url.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            try JSONEncoder().encode(load(digest: digest)).write(to: url, options: [.atomic])
            defaults.set([url.path], forKey: manifestKey(digest: digest))
            return url
        }) else {
            throw NSError(domain: "EchoTraceOwnerIsolationModelSmoke", code: 2)
        }
        return result
    }

    private func load(digest: String) -> [String] {
        guard let data = defaults.data(forKey: storageKey(digest: digest)) else { return [] }
        return (try? JSONDecoder().decode([String].self, from: data)) ?? []
    }

    private func storageKey(digest: String) -> String {
        "DreamJourney.EchoTraceModel.records.v2.owner.\(digest)"
    }

    private func manifestKey(digest: String) -> String {
        "DreamJourney.EchoTraceModel.exports.v2.owner.\(digest)"
    }

    private func clearExports(digest: String) {
        for path in defaults.stringArray(forKey: manifestKey(digest: digest)) ?? [] {
            try? FileManager.default.removeItem(at: URL(fileURLWithPath: path))
        }
        defaults.removeObject(forKey: manifestKey(digest: digest))
    }

    private func purgeLegacy() {
        legacyKeys.forEach { defaults.removeObject(forKey: $0) }
    }
}

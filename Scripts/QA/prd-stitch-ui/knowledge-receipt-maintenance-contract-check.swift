import Foundation

let root = URL(
    fileURLWithPath: CommandLine.arguments.dropFirst().first
        ?? FileManager.default.currentDirectoryPath
)
let backendRoot = URL(
    fileURLWithPath: ProcessInfo.processInfo.environment["BACKEND_ROOT"]
        ?? root.deletingLastPathComponent().appendingPathComponent("DreamJourneyBackend").path
)

func read(_ base: URL, _ relativePath: String) -> String {
    let fileURL = base.appendingPathComponent(relativePath)
    guard let content = try? String(contentsOf: fileURL, encoding: .utf8) else {
        fatalError("Unable to read \(fileURL.path)")
    }
    return content
}

func require(_ condition: @autoclosure () -> Bool, _ message: String) {
    guard condition() else {
        fputs("Knowledge receipt maintenance guard failed: \(message)\n", stderr)
        exit(1)
    }
}

func position(_ needle: String, in source: String) -> String.Index {
    guard let range = source.range(of: needle) else {
        fputs("Knowledge receipt maintenance guard failed: missing \(needle)\n", stderr)
        exit(1)
    }
    return range.lowerBound
}

func section(_ source: String, from start: String, to end: String) -> String {
    let startIndex = position(start, in: source)
    guard let endRange = source.range(of: end, range: startIndex..<source.endIndex) else {
        fputs("Knowledge receipt maintenance guard failed: missing section end \(end)\n", stderr)
        exit(1)
    }
    return String(source[startIndex..<endRange.lowerBound])
}

let knowledgeStore = read(backendRoot, "app/services/knowledge_store.py")
let memoryStore = read(backendRoot, "app/services/in_memory_store.py")
let postgresStore = read(backendRoot, "app/services/postgres_store.py")
let receiptMaintenance = read(
    backendRoot,
    "app/services/knowledge_receipt_maintenance.py"
)
let privacyMaintenance = read(
    backendRoot,
    "app/services/knowledge_privacy_maintenance.py"
)
let cli = read(backendRoot, "scripts/maintain_knowledge_operation_receipts.py")
let backendRunner = read(
    backendRoot,
    "scripts/run-backend-knowledge-receipt-maintenance-smoke.sh"
)
let receiptTests = read(backendRoot, "tests/test_knowledge_receipt_maintenance.py")
let postgresTests = read(
    backendRoot,
    "tests/test_knowledge_receipt_postgres_maintenance.py"
)
let operations = read(
    backendRoot,
    "docs/backend/2026-07-11-knowledge-operation-receipt-maintenance.md"
)
let releaseRegression = read(root, "Scripts/QA/prd-stitch-ui/run-release-regression.sh")
let releaseQA = read(root, "Scripts/QA/prd-stitch-ui/release-qa-package-check.swift")
let status = read(
    root,
    "docs/superpowers/status/2026-07-11-knowledge-operation-receipt-minimization.md"
)

for contract in [
    "def compact_knowledge_operation_receipt_result(",
    "\"receiptEnvelopeVersion\": KB_RECEIPT_ENVELOPE_VERSION",
    "def rebuild_compact_knowledge_operation_result(",
    "result[\"receiptCompacted\"] = True",
    "result[\"originalRevision\"]",
] {
    require(knowledgeStore.contains(contract), "missing compact receipt contract \(contract)")
}
require(
    memoryStore.contains("\"result\": compact_knowledge_operation_receipt_result(") &&
        memoryStore.contains("if not is_compact_knowledge_operation_receipt_result(receipt_result):") &&
        memoryStore.contains("return rebuild_compact_knowledge_operation_result("),
    "memory store must write compact receipts and read compact/legacy receipts"
)
require(
    postgresStore.contains("compact_result = compact_knowledge_operation_receipt_result(") &&
        postgresStore.contains("payload_hash, result, created_at") &&
        postgresStore.contains("if is_compact_knowledge_operation_receipt_result(receipt_result):") &&
        postgresStore.contains("result = rebuild_compact_knowledge_operation_result("),
    "Postgres must write compact receipts and rebuild compact replay responses"
)

let memoryReplay = section(
    memoryStore,
    from: "def get_kb_operation_replay(",
    to: "def _store_kb_operation_receipt_locked("
)
require(
    position("verify_knowledge_operation_receipt(", in: memoryReplay) <
        position("result = self._rebuild_kb_operation_receipt_locked(", in: memoryReplay),
    "memory replay must verify the fingerprint before reading receipt result"
)
let postgresReplay = section(
    postgresStore,
    from: "def _kb_operation_receipt_replay_cursor(",
    to: "def _insert_kb_operation_receipt_cursor("
)
require(
    position("verify_knowledge_operation_receipt(", in: postgresReplay) <
        position("receipt_result = receipt[\"result\"]", in: postgresReplay) &&
        position("receipt_result = receipt[\"result\"]", in: postgresReplay) <
        position("if is_compact_knowledge_operation_receipt_result(receipt_result):", in: postgresReplay),
    "Postgres replay must be fingerprint-first before compact/full result handling"
)

for contract in [
    "def compact_persisted_knowledge_receipt_result(",
    "def canonicalize_compact_knowledge_receipt_result(",
    "if \"graph\" in result or \"mutation\" in result:",
] {
    require(receiptMaintenance.contains(contract), "missing receipt canonicalizer \(contract)")
}
require(
    postgresStore.contains("compact_result = compact_persisted_knowledge_receipt_result(") &&
        postgresStore.contains("if compact_result == result:") &&
        postgresTests.contains("test_dirty_compact_envelope_is_canonicalized_instead_of_skipped") &&
        postgresTests.contains("self.assertNotIn(\"dirty private text\", str(dirty))"),
    "dirty compact envelopes must use canonical compare and be rewritten safely"
)
require(
    privacyMaintenance.contains("return canonicalize_compact_knowledge_receipt_result(result)") &&
        privacyMaintenance.contains("if is_compact_knowledge_operation_receipt_result(canonical_result):") &&
        privacyMaintenance.contains("return current_payload_hash") &&
        receiptTests.contains("test_privacy_maintenance_accepts_compact_v2_and_preserves_hash"),
    "privacy maintenance must accept canonical compact receipts without hash rewrite"
)

require(
    cli.contains("action=\"store_true\"") &&
        cli.contains("apply=args.apply") &&
        cli.contains("Default: dry-run.") &&
        !cli.contains("default=True"),
    "receipt maintenance CLI must require explicit --apply and default to dry-run"
)
for smokeContract in [
    "tests.test_knowledge_receipt_maintenance",
    "tests.test_knowledge_receipt_postgres_maintenance",
    "tests.test_knowledge_privacy_maintenance",
    "tests.test_knowledge_change_feed_compaction",
    "test_memory_reads_legacy_full_receipt_and_checks_fingerprint_first",
    "test_mutation_api_marks_snapshot_fallback_after_receipt_change_compaction",
    "test_governance_compact_receipt_keeps_summary_after_change_compaction",
    "test_archive_compact_receipt_keeps_cascade_summary_without_change",
] {
    require(backendRunner.contains(smokeContract), "missing combined smoke \(smokeContract)")
}
require(
    backendRunner.contains("action=\"store_true\"") &&
        backendRunner.contains("apply=args.apply") &&
        !backendRunner.contains("maintain_knowledge_operation_receipts.py --apply"),
    "backend fixture smoke must guard dry-run CLI semantics without applying maintenance"
)

require(
    operations.contains("不删除 receipt 行，也不修改 payload hash") &&
        operations.contains("只运行线上 dry-run") &&
        operations.contains("不允许删除 receipt identity 行或重算 `payload_hash`") &&
        operations.contains("reader-first 部署完成前运行 apply"),
    "operations guide must preserve dry-run-first, no-delete, and no-hash-rewrite boundaries"
)
require(
    releaseRegression.contains("knowledge-receipt-maintenance-contract-check.swift") &&
        releaseRegression.contains("RUN_KNOWLEDGE_RECEIPT_MAINTENANCE_GATE") &&
        releaseRegression.contains("run-knowledge-receipt-maintenance-gate.sh"),
    "release regression must run the static guard and expose the optional full gate"
)
require(
    releaseQA.contains("knowledge-receipt-maintenance-contract-check.swift") &&
        releaseQA.contains("run-knowledge-receipt-maintenance-gate.sh") &&
        releaseQA.contains("2026-07-11-knowledge-operation-receipt-minimization.md"),
    "release QA package must include the receipt maintenance gate and status"
)
require(
    status.contains("先 dry-run") &&
        status.contains("不删除 receipt") &&
        status.contains("不重写 payload hash") &&
        status.contains("不做真机"),
    "status must document production and true-device boundaries"
)

print("Knowledge receipt maintenance contract guard passed")

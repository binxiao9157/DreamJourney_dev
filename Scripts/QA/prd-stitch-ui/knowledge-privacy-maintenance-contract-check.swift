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
    let url = base.appendingPathComponent(relativePath)
    guard let content = try? String(contentsOf: url, encoding: .utf8) else {
        fatalError("Unable to read \(url.path)")
    }
    return content
}

func require(_ condition: @autoclosure () -> Bool, _ message: String) {
    guard condition() else {
        fputs("Knowledge privacy maintenance guard failed: \(message)\n", stderr)
        exit(1)
    }
}

let knowledgeStore = read(backendRoot, "app/services/knowledge_store.py")
let memoryStore = read(backendRoot, "app/services/in_memory_store.py")
let maintenance = read(backendRoot, "app/services/knowledge_privacy_maintenance.py")
let postgresStore = read(backendRoot, "app/services/postgres_store.py")
let cli = read(backendRoot, "scripts/maintain_knowledge_privacy_metadata.py")
let backendRunner = read(
    backendRoot,
    "scripts/run-backend-knowledge-privacy-maintenance-smoke.sh"
)
let maintenanceTests = read(
    backendRoot,
    "tests/test_knowledge_privacy_maintenance.py"
)
let releaseRegression = read(root, "Scripts/QA/prd-stitch-ui/run-release-regression.sh")
let releaseQA = read(root, "Scripts/QA/prd-stitch-ui/release-qa-package-check.swift")
let status = read(
    root,
    "docs/superpowers/status/2026-07-11-knowledge-mutation-privacy-canonicalization.md"
)

require(
    knowledgeStore.contains("canonicalize_source_ref_titles(entity)") &&
        memoryStore.contains("normalized_requested_mutation") &&
        memoryStore.contains("knowledge_operation_payload_fingerprint(") &&
        postgresStore.contains("normalized_requested_mutation") &&
        postgresStore.contains("knowledge_operation_payload_fingerprint("),
    "V2 mutation must be canonical before semantic fingerprint and persistence"
)
require(
    maintenance.contains("canonicalize_persisted_knowledge_graph") &&
        maintenance.contains("canonicalize_persisted_knowledge_mutation") &&
        maintenance.contains("operation_kind != KB_OPERATION_MUTATION or schema_version != 2"),
    "maintenance must cover graph/mutation and only recalculate V2 mutation hashes"
)
for contract in [
    "knowledge-privacy-metadata-maintenance:v1",
    "knowledge:{user_id}",
    "LOCK TABLE kb_snapshots, kb_changes, kb_operation_receipts",
    "invalidRecordCount",
    "if apply:",
    "connection.commit()",
    "self._rollback(connection)",
] {
    require(postgresStore.contains(contract), "missing Postgres maintenance contract \(contract)")
}
require(
    cli.contains("action=\"store_true\"") &&
        cli.contains("apply=args.apply") &&
        !cli.contains("default=True"),
    "maintenance CLI must default to dry-run and require explicit --apply"
)
require(
    !backendRunner.contains(" --apply") &&
        backendRunner.contains("tests.test_knowledge_privacy_maintenance"),
    "local backend smoke must use fixtures and never apply production maintenance"
)
for evidence in [
    "RAW_PRIVATE_SOURCE_TITLE_SENTINEL",
    "test_postgres_maintenance_dry_run_apply_and_second_apply_are_safe",
    "test_postgres_maintenance_rolls_back_all_updates_on_database_failure",
    "test_apply_refuses_invalid_records_without_writing",
    "governance-hash-must-stay",
] {
    require(maintenanceTests.contains(evidence), "missing maintenance evidence \(evidence)")
}
require(
    releaseRegression.contains("RUN_KNOWLEDGE_PRIVACY_MAINTENANCE_GATE") &&
        releaseRegression.contains("run-knowledge-privacy-maintenance-gate.sh"),
    "release regression must expose and run the local privacy maintenance gate"
)
require(
    releaseQA.contains("knowledge-privacy-maintenance-contract-check.swift") &&
        releaseQA.contains("run-knowledge-privacy-maintenance-gate.sh"),
    "release QA package must guard the privacy maintenance gate"
)
require(
    status.contains("dry-run -> apply -> dry-run") &&
        status.contains("不自动执行生产 --apply"),
    "status document must preserve the production safety boundary"
)

print("Knowledge privacy maintenance contract guard passed")

import Foundation

let root = URL(
    fileURLWithPath: CommandLine.arguments.dropFirst().first
        ?? FileManager.default.currentDirectoryPath
)

func read(_ relativePath: String, from base: URL = root) -> String {
    let url = base.appendingPathComponent(relativePath)
    guard let value = try? String(contentsOf: url, encoding: .utf8) else {
        fatalError("Unable to read \(url.path)")
    }
    return value
}

func require(_ content: String, _ needle: String, _ reason: String) {
    guard content.contains(needle) else {
        fatalError("\(reason): missing \(needle)")
    }
}

let featureFlags = read("DreamJourney/Sources/App/FeatureFlagService.swift")
let lifecycle = read("DreamJourney/Sources/App/AccountLifecycleRuntimeRegistry.swift")
let client = read("DreamJourney/Sources/Services/DreamJourneyBackendClient.swift")
let profile = read("DreamJourney/Sources/Modules/Profile/ProfileViewController.swift")
let tests = read("DreamJourneyTests/OwnerTruthContractsTests.swift")

require(featureFlags, "case formalMemoryMarkdownExport", "formal export needs a typed feature")
require(
    featureFlags,
    ".formalMemoryMarkdownExport,",
    "formal export must remain server-policy managed"
)

for token in [
    "struct FormalMemoryMarkdownExportManifestContract",
    "struct FormalMemoryMarkdownExportJobContract",
    "struct FormalMemoryMarkdownDownloadCredentialContract",
    "struct FormalMemoryMarkdownFileContract",
    "func createFormalMemoryMarkdownExportJob(",
    "func cancelFormalMemoryMarkdownExportJob(",
    "func downloadFormalMemoryMarkdownExport(",
    "X-DreamJourney-Export-Token",
    "X-Content-SHA256",
    "text/markdown; charset=utf-8",
] {
    require(client, token, "typed client must preserve the formal export contract")
}

for token in [
    "private var isAccountDataExportVisible: Bool {\n        false",
    "rows.append(.formalMemoryExport)",
    "return \"导出正式记忆\"",
    "profile-formal-memory-export-row",
    "struct FormalMemoryMarkdownExportJobStatusSnapshot",
    "enum FormalMemoryMarkdownTemporaryStore",
    "FileProtectionType.complete",
    ".completeFileProtection",
    "FormalMemoryMarkdownPreviewViewController",
    "UIActivityViewController",
    "FileManager.default.fileExists(atPath: fileURL.path)",
    "navigationItem.rightBarButtonItem?.isEnabled = false",
    "removeTemporaryFileIfNeeded()",
] {
    require(profile, token, "Profile must expose only the protected formal-memory export")
}

for token in [
    "FormalMemoryMarkdownExportJobStatusStore.teardownForAccountLifecycle",
    "FormalMemoryMarkdownTemporaryStore.teardownForAccountLifecycle",
] {
    require(lifecycle, token, "account lifecycle must remove export state and files")
}

for token in [
    "testFormalMemoryMarkdownExportContractsRequireVaultMimeAndHash",
    "testFormalMemoryMarkdownExportStatusIsOwnerScopedAndResumable",
] {
    require(tests, token, "iOS tests must guard export integrity and account isolation")
}

let backendRoot = root.deletingLastPathComponent().appendingPathComponent("DreamJourneyBackend")
if FileManager.default.fileExists(atPath: backendRoot.path) {
    let service = read("app/services/formal_memory_markdown_export.py", from: backendRoot)
    let apiTests = read("tests/test_formal_memory_markdown_export_api.py", from: backendRoot)
    for token in [
        "FORMAL_MEMORY_MARKDOWN_MIME_TYPE = \"text/markdown; charset=utf-8\"",
        "collect_current_formal_memories",
        "formal_memory_markdown_download",
    ] {
        require(service, token, "backend renderer must stay current-only and integrity checked")
    }
    for token in [
        "test_owner_downloads_only_current_memory_with_one_time_credential",
        "test_empty_export_can_cancel_and_full_account_type_is_rejected",
    ] {
        require(apiTests, token, "backend API tests must guard the public export boundary")
    }
}

print("Formal memory Markdown export guard passed")

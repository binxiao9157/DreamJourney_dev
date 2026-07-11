import Foundation

let root = URL(fileURLWithPath: CommandLine.arguments.dropFirst().first ?? FileManager.default.currentDirectoryPath)
let fileManager = FileManager.default

func fail(_ message: String) -> Never {
    fputs("knowledge-governance-release-boundary-check failed: \(message)\n", stderr)
    exit(1)
}

func swiftFiles(under relativePath: String) -> [URL] {
    let directory = root.appendingPathComponent(relativePath, isDirectory: true)
    guard let enumerator = fileManager.enumerator(
        at: directory,
        includingPropertiesForKeys: [.isRegularFileKey],
        options: [.skipsHiddenFiles]
    ) else {
        fail("cannot enumerate \(relativePath)")
    }
    return enumerator.compactMap { value in
        guard let url = value as? URL, url.pathExtension == "swift" else { return nil }
        return url
    }
}

let publicProductSources = swiftFiles(under: "DreamJourney/Sources/Modules")
    + swiftFiles(under: "DreamJourney/Sources/App")

for file in publicProductSources {
    guard let source = try? String(contentsOf: file, encoding: .utf8) else {
        fail("cannot read \(file.path)")
    }
    if source.contains("performGovernance(") {
        fail("public product source calls QA-only governance API: \(file.path)")
    }
    for publicCopy in ["确认知识", "拒绝知识", "纠正知识", "删除知识来源", "知识治理"] {
        if source.contains(publicCopy) {
            fail("public product source exposes governance copy '\(publicCopy)': \(file.path)")
        }
    }
}

let coordinatorPath = "DreamJourney/Sources/Services/KnowledgeSyncCoordinator.swift"
let coordinatorURL = root.appendingPathComponent(coordinatorPath)
guard let coordinator = try? String(contentsOf: coordinatorURL, encoding: .utf8),
      coordinator.contains("func performGovernance("),
      coordinator.contains("private let governanceOutboxStore = KnowledgeGovernanceOutboxStore()") else {
    fail("governance API must remain implemented in the service coordinator")
}

print("Knowledge governance release boundary check passed")

import Foundation

let rootPath = CommandLine.arguments.dropFirst().first ?? FileManager.default.currentDirectoryPath
let rootURL = URL(fileURLWithPath: rootPath)

struct StatusEntry {
    let status: String
    let path: String
}

func runGitStatus() -> String {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
    process.arguments = [
        "git",
        "-C",
        rootURL.path,
        "-c",
        "core.quotePath=false",
        "status",
        "--porcelain=v1",
        "-uall",
    ]

    let pipe = Pipe()
    process.standardOutput = pipe
    process.standardError = pipe

    do {
        try process.run()
        process.waitUntilExit()
    } catch {
        fatalError("Unable to run git status: \(error)")
    }

    let data = pipe.fileHandleForReading.readDataToEndOfFile()
    let output = String(data: data, encoding: .utf8) ?? ""
    guard process.terminationStatus == 0 else {
        fatalError("git status failed:\n\(output)")
    }
    return output
}

func parseStatus(_ output: String) -> [StatusEntry] {
    output
        .split(separator: "\n", omittingEmptySubsequences: true)
        .map(String.init)
        .compactMap { line in
            guard line.count >= 4 else { return nil }
            let status = String(line.prefix(2))
            var path = String(line.dropFirst(3))
            if path.contains(" -> "), let newPath = path.components(separatedBy: " -> ").last {
                path = newPath
            }
            return StatusEntry(status: status, path: path)
        }
}

func hasPrefix(_ path: String, _ prefix: String) -> Bool {
    path == prefix || path.hasPrefix(prefix)
}

func classify(_ path: String) -> String? {
    let group1: Set<String> = [
        ".gitignore",
        "DreamJourney/Config/Backend.example.xcconfig",
        "DreamJourney.xcodeproj/project.pbxproj",
        "DreamJourney/Resources/Info.plist",
        "DreamJourney/Sources/App/FeatureFlagService.swift",
        "DreamJourney/Sources/AppDelegate.swift",
        "DreamJourney/Sources/Services/DreamJourneyBackendClient.swift",
        "Podfile",
        "Podfile.lock",
    ]
    if group1.contains(path) {
        return "1-project-scaffolding-release-gates"
    }
    if hasPrefix(path, "DreamJourney/Sources/DesignSystem/") {
        return "1-project-scaffolding-release-gates"
    }

    let group2: Set<String> = [
        "DreamJourney/Sources/App/DigitalHumanContextStore.swift",
        "DreamJourney/Sources/TabBar/WarmTabBarController.swift",
        "DreamJourney/Sources/Modules/Auth/LoginViewController.swift",
        "DreamJourney/Sources/Modules/Echo/EchoViewController.swift",
        "DreamJourney/Sources/Modules/Echo/EchoViewModel.swift",
        "DreamJourney/Sources/Services/DialogEngineManager.swift",
        "DreamJourney/Sources/Services/MicrophonePermissionManager.swift",
        "DreamJourney/Sources/Services/UserManager.swift",
    ]
    if group2.contains(path) {
        return "2-shell-login-echo-prompt"
    }

    if hasPrefix(path, "DreamJourney/Sources/Modules/Archive/") {
        return "3-archive-core-creation"
    }

    let group4Services: Set<String> = [
        "DreamJourney/Sources/Services/FamilyRepository.swift",
        "DreamJourney/Sources/Services/MemoryModel.swift",
    ]
    if hasPrefix(path, "DreamJourney/Sources/Modules/Profile/")
        || hasPrefix(path, "DreamJourney/Sources/Modules/Family/")
        || group4Services.contains(path) {
        return "4-profile-care-settings-legal"
    }

    let sourceWarningCleanup: Set<String> = [
        "DreamJourney/Sources/Common/UI/TGLoadingView.swift",
        "DreamJourney/Sources/Common/UI/TGToast.swift",
        "DreamJourney/Sources/Modules/Home/Views/HomeHeaderView.swift",
        "DreamJourney/Sources/Modules/Map/FootprintNotificationBanner.swift",
        "DreamJourney/Sources/Modules/Memory/MemoryDetailViewController.swift",
        "DreamJourney/Sources/Memoir/MemoirDetailViewController.swift",
        "DreamJourney/Sources/Services/ConversationMemoryManager.swift",
    ]
    if sourceWarningCleanup.contains(path) {
        return "5-source-warning-cleanup"
    }

    let group5: Set<String> = [
        "DreamJourney/Sources/Modules/Home/AIRecordingViewController.swift",
        "DreamJourney/Sources/Modules/Map/MapFootprintViewController.swift",
        "DreamJourney/Sources/Modules/Map/MemoryAnnotation.swift",
        "DreamJourney/Sources/Modules/Map/MemoryAnnotationView.swift",
        "DreamJourney/Sources/Memoir/MemoirFlowManager.swift",
        "DreamJourney/Sources/Memoir/MemoirTTSService.swift",
        "DreamJourney/Sources/Memoir/VoiceCloneService.swift",
    ]
    if group5.contains(path) {
        return "5-map-future-route-compatibility"
    }

    if path == "task_plan.md"
        || path == "findings.md"
        || path == "progress.md"
        || path == ".closure-lodestar/task-ledgers.json"
        || hasPrefix(path, "docs/plans/")
        || hasPrefix(path, "docs/superpowers/plans/")
        || hasPrefix(path, "docs/superpowers/status/")
        || hasPrefix(path, ".closure-lodestar/tickets/")
        || hasPrefix(path, ".closure-lodestar/results/")
        || hasPrefix(path, ".closure-lodestar/checks/")
        || hasPrefix(path, ".closure-lodestar/followups/")
        || hasPrefix(path, ".complex-problems/") {
        return "6-durable-docs"
    }

    if path == "tmp/visual-qa/prd-stitch-ui/run-archive-to-echo-smoke.sh"
        || path == "tmp/visual-qa/prd-stitch-ui/run-backend-env-smoke.sh"
        || (hasPrefix(path, "tmp/visual-qa/prd-stitch-ui/") && path.hasSuffix(".swift"))
        || (hasPrefix(path, "tmp/visual-qa/prd-stitch-ui/") && path.hasSuffix("/report.md"))
        || (hasPrefix(path, "tmp/visual-qa/prd-stitch-ui/") && path.hasSuffix("archive-to-echo-smoke-result.json"))
        || (hasPrefix(path, "tmp/visual-qa/prd-stitch-ui/") && path.hasSuffix("backend-env-smoke-result.json"))
        || hasPrefix(path, "tmp/visual-qa/prd-stitch-ui/screenshots/stitch-") {
        return "6-optional-qa-evidence"
    }

    if hasPrefix(path, "tmp/visual-qa/prd-stitch-ui/")
        && (path.contains("/DerivedData")
            || path.hasSuffix(".log")
            || path.hasSuffix(".png")
            || path.hasSuffix(".jpg")
            || path.hasSuffix(".jpeg")
            || path.hasSuffix(".html")
            || path.hasSuffix(".txt")
            || path.hasSuffix(".mp4")
            || path.hasSuffix(".xcresult")) {
        return "local-only-generated-qa"
    }

    if hasPrefix(path, "tmp/visual-qa/prd-stitch-ui/") {
        return "local-only-generated-qa"
    }

    if hasPrefix(path, "tmp/stitch/") {
        return "local-only-stitch-cache"
    }

    return nil
}

let entries = parseStatus(runGitStatus())
var grouped: [String: [StatusEntry]] = [:]
var unclassified: [StatusEntry] = []

for entry in entries {
    if let group = classify(entry.path) {
        grouped[group, default: []].append(entry)
    } else {
        unclassified.append(entry)
    }
}

if !unclassified.isEmpty {
    let details = unclassified
        .map { "\($0.status) \($0.path)" }
        .sorted()
        .joined(separator: "\n")
    fatalError("Unclassified dirty files found:\n\(details)")
}

let outputOrder = [
    "1-project-scaffolding-release-gates",
    "2-shell-login-echo-prompt",
    "3-archive-core-creation",
    "4-profile-care-settings-legal",
    "5-source-warning-cleanup",
    "5-map-future-route-compatibility",
    "6-durable-docs",
    "6-optional-qa-evidence",
    "local-only-generated-qa",
    "local-only-stitch-cache",
]

print("Submit slice inventory checks passed")
for group in outputOrder {
    guard let files = grouped[group], !files.isEmpty else { continue }
    print("- \(group): \(files.count)")
}

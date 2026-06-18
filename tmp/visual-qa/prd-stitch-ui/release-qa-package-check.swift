import Foundation

let root = URL(fileURLWithPath: CommandLine.arguments.dropFirst().first ?? FileManager.default.currentDirectoryPath)
let fileManager = FileManager.default

func url(_ relativePath: String) -> URL {
    root.appendingPathComponent(relativePath)
}

func read(_ relativePath: String) -> String {
    let fileURL = url(relativePath)
    guard let content = try? String(contentsOf: fileURL, encoding: .utf8) else {
        fatalError("Unable to read \(fileURL.path)")
    }
    return content
}

func assertFileExists(_ relativePath: String, _ message: String) {
    guard fileManager.fileExists(atPath: url(relativePath).path) else {
        fatalError("\(message): missing \(relativePath)")
    }
}

func assertContains(_ haystack: String, _ needle: String, _ message: String) {
    guard haystack.contains(needle) else {
        fatalError("\(message): missing \(needle)")
    }
}

func latestDirectoryName(in relativePath: String) -> String {
    let directoryURL = url(relativePath)
    guard let contents = try? fileManager.contentsOfDirectory(
        at: directoryURL,
        includingPropertiesForKeys: [.isDirectoryKey, .contentModificationDateKey],
        options: [.skipsHiddenFiles]
    ) else {
        fatalError("Unable to list \(directoryURL.path)")
    }

    let directories = contents.compactMap { candidate -> (name: String, modifiedAt: Date)? in
        let values = try? candidate.resourceValues(forKeys: [.isDirectoryKey, .contentModificationDateKey])
        guard values?.isDirectory == true else {
            return nil
        }
        return (candidate.lastPathComponent, values?.contentModificationDate ?? .distantPast)
    }
    guard let latest = directories.sorted(by: {
        if $0.modifiedAt == $1.modifiedAt {
            return $0.name < $1.name
        }
        return $0.modifiedAt < $1.modifiedAt
    }).last else {
        fatalError("No evidence directories found in \(relativePath)")
    }
    return latest.name
}

func assertBuildSucceeded(_ relativePath: String) {
    let log = read(relativePath)
    assertContains(log, "** BUILD SUCCEEDED **", "\(relativePath) should contain a successful build")
}

func assertSmokeResultSucceeded(_ relativePath: String) {
    let dataURL = url(relativePath)
    guard let data = try? Data(contentsOf: dataURL),
          let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
        fatalError("Unable to parse smoke result \(relativePath)")
    }

    guard object["completed"] as? Bool == true else {
        fatalError("Smoke result did not complete: \(relativePath)")
    }
    guard object["containsArchiveContext"] as? Bool == true else {
        fatalError("Smoke result did not include archive context: \(relativePath)")
    }
    guard object["availableItemCount"] as? Int == 1 else {
        fatalError("Smoke result should expose exactly one archive item: \(relativePath)")
    }
    guard object["entries"] as? String == "相册影像（相册）" else {
        fatalError("Smoke result entries changed: \(relativePath)")
    }
}

let requiredDocs = [
    "docs/superpowers/plans/2026-06-16-prd-stitch-ui-adaptation.md",
    "docs/superpowers/status/2026-06-17-prd-stitch-ui-gap-audit.md",
    "docs/superpowers/status/2026-06-17-release-feature-matrix.md",
    "docs/superpowers/status/2026-06-17-pre-submit-inventory.md",
    "docs/superpowers/status/2026-06-17-group1-scaffolding-review.md",
    "docs/superpowers/status/2026-06-17-group2-shell-echo-review.md",
    "docs/superpowers/status/2026-06-17-group3-archive-core-review.md",
    "docs/superpowers/status/2026-06-17-group4-profile-care-review.md",
    "docs/superpowers/status/2026-06-17-group5-map-compatibility-review.md",
    "docs/superpowers/status/2026-06-17-group6-release-qa-package-review.md",
    "docs/superpowers/status/2026-06-17-submit-slice-inventory.md",
]

for doc in requiredDocs {
    assertFileExists(doc, "required status doc")
}

let plan = read("docs/superpowers/plans/2026-06-16-prd-stitch-ui-adaptation.md")
assertContains(plan, "current Stitch canvas and `htmlCode`", "plan should preserve visual source-of-truth policy")
assertContains(plan, "MCP screenshot", "plan should keep MCP screenshots auxiliary")
assertContains(plan, "run-archive-to-echo-smoke.sh", "plan should document core smoke")
assertContains(plan, "release-qa-package-check.swift", "plan should document Group 6 package guard")
assertContains(plan, "submit-slice-inventory-check.swift", "plan should document submit slice guard")

let archiveSmokeScript = read("tmp/visual-qa/prd-stitch-ui/run-archive-to-echo-smoke.sh")
assertContains(archiveSmokeScript, "defaults delete \"$BUNDLE_ID\"", "archive-to-echo smoke should clear simulator defaults for isolation")
assertContains(archiveSmokeScript, "simctl uninstall \"$SIMULATOR_UDID\" \"$BUNDLE_ID\"", "archive-to-echo smoke should uninstall the old app container for isolation")

let inventory = read("docs/superpowers/status/2026-06-17-pre-submit-inventory.md")
for group in ["Group 1", "Group 2", "Group 3", "Group 4", "Group 5", "Group 6"] {
    assertContains(inventory, group, "pre-submit inventory should include \(group)")
}
assertContains(inventory, "Avoid staging all of `tmp/` wholesale", "inventory should protect commit hygiene")
assertContains(inventory, "release-qa-package-check.swift", "inventory should list the Group 6 guard")
assertContains(inventory, "final-visual-qa-package-check.swift", "inventory should list the final visual QA guard")
assertContains(inventory, "submit-slice-inventory-check.swift", "inventory should list the submit slice guard")

let matrix = read("docs/superpowers/status/2026-06-17-release-feature-matrix.md")
assertContains(matrix, "Default enabled feature flags must remain exactly", "release matrix should pin default feature flags")
assertContains(matrix, "Hidden By Default", "release matrix should list hidden branches")
assertContains(matrix, "DJFeature.archiveRemoteFetch", "release matrix should document remote archive fetch as hidden")
assertContains(matrix, "DJEnableArchiveHiddenBranches", "release matrix should document archive hidden QA arg")
assertContains(matrix, "DJEnableProfileHiddenBranches", "release matrix should document profile hidden QA arg")

let gapAudit = read("docs/superpowers/status/2026-06-17-prd-stitch-ui-gap-audit.md")
assertContains(gapAudit, "Old routes / map", "gap audit should classify old map routes")
assertContains(gapAudit, "QA harness", "gap audit should classify the QA harness")
assertContains(gapAudit, "Project hygiene", "gap audit should classify project hygiene")

let latestFinalVisual = latestDirectoryName(in: "tmp/visual-qa/prd-stitch-ui/final-stitch-visual-qa")
let finalVisualBase = "tmp/visual-qa/prd-stitch-ui/final-stitch-visual-qa/\(latestFinalVisual)"
let finalVisualReport = read("\(finalVisualBase)/report.md")
assertContains(finalVisualReport, "current Stitch canvas and downloaded `htmlCode`", "final visual report should preserve Stitch/htmlCode authority")
assertContains(finalVisualReport, "Release-Gated Differences", "final visual report should classify expected hidden-release differences")
for screenshot in [
    "app/01-login.png",
    "app/02-echo-default.png",
    "app/03-archive-default.png",
    "app/04-profile-default.png",
    "app/06-archive-stitch-qa-hidden-branches.png",
    "app/07-profile-stitch-qa-hidden-branches.png",
    "stitch/login.png",
    "stitch/echo.png",
    "stitch/archive.png",
    "stitch/profile.png",
] {
    assertFileExists("\(finalVisualBase)/\(screenshot)", "final visual QA evidence")
}
assertBuildSucceeded("\(finalVisualBase)/build-final.log")

let releaseStateBase = "tmp/visual-qa/prd-stitch-ui/release-state-overview/20260617-current"
let releaseStateReport = read("\(releaseStateBase)/report.md")
assertContains(releaseStateReport, "No hidden-branch launch arguments were used", "release-state report should prove default release mode")
for screenshot in [
    "01-echo-default.jpg",
    "02-archive-default.jpg",
    "03-archive-create-sheet-default.jpg",
    "04-profile-default.jpg",
    "05-profile-settings-default.jpg",
    "06-profile-legal-default.jpg",
] {
    assertFileExists("\(releaseStateBase)/\(screenshot)", "release-state visual evidence")
}

let requiredScripts = [
    "tmp/visual-qa/prd-stitch-ui/run-archive-to-echo-smoke.sh",
    "tmp/visual-qa/prd-stitch-ui/run-backend-env-smoke.sh",
    "tmp/visual-qa/prd-stitch-ui/final-visual-qa-package-check.swift",
    "tmp/visual-qa/prd-stitch-ui/group1-scaffolding-check.swift",
    "tmp/visual-qa/prd-stitch-ui/group1-source-review-check.swift",
    "tmp/visual-qa/prd-stitch-ui/group2-shell-echo-check.swift",
    "tmp/visual-qa/prd-stitch-ui/echo-archive-context-indicator-check.swift",
    "tmp/visual-qa/prd-stitch-ui/digital-human-mode-lifecycle-check.swift",
    "tmp/visual-qa/prd-stitch-ui/echo-voice-state-visual-check.swift",
    "tmp/visual-qa/prd-stitch-ui/group3-archive-core-check.swift",
    "tmp/visual-qa/prd-stitch-ui/archive-compact-stitch-layout-check.swift",
    "tmp/visual-qa/prd-stitch-ui/archive-timeline-detail-stitch-check.swift",
    "tmp/visual-qa/prd-stitch-ui/archive-analysis-state-stitch-check.swift",
    "tmp/visual-qa/prd-stitch-ui/archive-remote-fetch-check.swift",
    "tmp/visual-qa/prd-stitch-ui/archive-remote-json-behavior-check.swift",
    "tmp/visual-qa/prd-stitch-ui/backend-integration-contract-check.py",
    "tmp/visual-qa/prd-stitch-ui/backend-auth-token-check.swift",
    "tmp/visual-qa/prd-stitch-ui/backend-auth-token-contract-check.py",
    "tmp/visual-qa/prd-stitch-ui/backend-build-config-check.swift",
    "tmp/visual-qa/prd-stitch-ui/backend-fallback-ui-check.swift",
    "tmp/visual-qa/prd-stitch-ui/group4-profile-care-check.swift",
    "tmp/visual-qa/prd-stitch-ui/profile-care-snapshot-check.swift",
    "tmp/visual-qa/prd-stitch-ui/profile-care-escalation-contract-check.swift",
    "tmp/visual-qa/prd-stitch-ui/profile-compact-stitch-layout-check.swift",
    "tmp/visual-qa/prd-stitch-ui/group5-map-compatibility-check.swift",
    "tmp/visual-qa/prd-stitch-ui/profile-scroll-inset-check.swift",
    "tmp/visual-qa/prd-stitch-ui/release-feature-matrix-check.swift",
    "tmp/visual-qa/prd-stitch-ui/release-qa-package-check.swift",
    "tmp/visual-qa/prd-stitch-ui/submit-slice-inventory-check.swift",
]

for script in requiredScripts {
    assertFileExists(script, "required QA script")
}

let groupEvidence = [
    "group1-scaffolding",
    "group2-shell-echo",
    "group3-archive-core",
    "group4-profile-care",
    "group5-map-compatibility",
]

for group in groupEvidence {
    let base = "tmp/visual-qa/prd-stitch-ui/\(group)/20260617-current"
    assertFileExists("\(base)/report.md", "\(group) should have a current report")
    assertFileExists("\(base)/build-final.log", "\(group) should have a current build log")
    assertBuildSucceeded("\(base)/build-final.log")
}

let group6Base = "tmp/visual-qa/prd-stitch-ui/group6-release-qa-package/20260617-current"
assertFileExists("\(group6Base)/report.md", "Group 6 should have a current report")
assertFileExists("\(group6Base)/build-final.log", "Group 6 should have a current build log")
assertBuildSucceeded("\(group6Base)/build-final.log")

let backendIntegrationBase = "tmp/visual-qa/prd-stitch-ui/backend-integration/20260617-current"
assertFileExists("\(backendIntegrationBase)/report.md", "backend integration should have a report")
assertFileExists("\(backendIntegrationBase)/01-archive-backend-fetch.jpg", "backend integration should capture archive screenshot")
assertFileExists("\(backendIntegrationBase)/02-profile-care-backend.jpg", "backend integration should capture profile screenshot")
assertFileExists("\(backendIntegrationBase)/app-archive-store-summary.json", "backend integration should capture app archive store summary")
assertBuildSucceeded("\(backendIntegrationBase)/build-uiqa.log")

let backendAuthBase = "tmp/visual-qa/prd-stitch-ui/backend-auth-token/20260617-current"
assertFileExists("\(backendAuthBase)/report.md", "backend auth token should have a report")
assertFileExists("\(backendAuthBase)/01-archive-auth-token-fetch.jpg", "backend auth token should capture archive screenshot")
assertFileExists("\(backendAuthBase)/02-profile-auth-token-care.jpg", "backend auth token should capture profile screenshot")
assertFileExists("\(backendAuthBase)/app-archive-store-summary.json", "backend auth token should capture app archive store summary")
assertBuildSucceeded("\(backendAuthBase)/build-uiqa.log")

let backendFallbackBase = "tmp/visual-qa/prd-stitch-ui/backend-fallback-ui/20260617-current"
assertFileExists("\(backendFallbackBase)/report.md", "backend fallback UI should have a report")
assertFileExists("\(backendFallbackBase)/01-archive-remote-fallback.jpg", "backend fallback UI should capture archive fallback screenshot")
assertFileExists("\(backendFallbackBase)/02-profile-care-fallback.jpg", "backend fallback UI should capture profile fallback screenshot")
assertBuildSucceeded("\(backendFallbackBase)/build-standard-debug.log")
assertBuildSucceeded("\(backendFallbackBase)/build-uiqa.log")

let backendBuildConfigBase = "tmp/visual-qa/prd-stitch-ui/backend-build-config/20260617-current"
assertFileExists("\(backendBuildConfigBase)/report.md", "backend build config should have a report")
assertBuildSucceeded("\(backendBuildConfigBase)/build-default-debug.log")
assertBuildSucceeded("\(backendBuildConfigBase)/build-override-debug.log")

let latestSmoke = latestDirectoryName(in: "tmp/visual-qa/prd-stitch-ui/archive-to-echo-smoke")
let latestSmokeBase = "tmp/visual-qa/prd-stitch-ui/archive-to-echo-smoke/\(latestSmoke)"
assertFileExists("\(latestSmokeBase)/archive-to-echo-smoke-result.json", "latest smoke should write result JSON")
assertFileExists("\(latestSmokeBase)/01-archive-to-echo-completed.png", "latest smoke should capture screenshot")
assertSmokeResultSucceeded("\(latestSmokeBase)/archive-to-echo-smoke-result.json")

let gitignore = read(".gitignore")
assertContains(gitignore, "tmp/**/DerivedData*", "gitignore should exclude generated DerivedData")

print("Release QA package checks passed with latest smoke \(latestSmoke)")

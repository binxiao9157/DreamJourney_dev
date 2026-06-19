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

func assertNotContains(_ haystack: String, _ needle: String, _ message: String) {
    guard !haystack.contains(needle) else {
        fatalError("\(message): unexpected \(needle)")
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
    "docs/superpowers/status/2026-06-18-prd-coverage-matrix.md",
    "docs/superpowers/status/2026-06-18-prd-full-feature-closure-decisions.md",
    "docs/superpowers/status/2026-06-18-phase0-backend-alignment.md",
    "docs/superpowers/status/2026-06-18-release-like-backend-acceptance.md",
    "docs/superpowers/status/2026-06-18-backend-contract-gap-matrix.md",
    "docs/superpowers/status/2026-06-18-one-command-release-regression.md",
    "docs/superpowers/status/2026-06-18-final-stitch-visual-refresh.md",
    "docs/superpowers/status/2026-06-18-echo-waiting-reply-policy.md",
    "docs/superpowers/status/2026-06-18-profile-settings-save-state.md",
    "docs/superpowers/status/2026-06-18-profile-care-data-states.md",
    "docs/superpowers/status/2026-06-18-profile-care-intervention-placeholder.md",
    "docs/superpowers/status/2026-06-18-archive-sync-error-recovery.md",
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

let releaseRegression = read("tmp/visual-qa/prd-stitch-ui/run-release-regression.sh")
let oneCommandRegression = read("docs/superpowers/status/2026-06-18-one-command-release-regression.md")
assertContains(releaseRegression, "Release handoff mode forces release-like backend acceptance", "release handoff mode should document forced backend acceptance")
assertContains(releaseRegression, "RUN_RELEASE_LIKE_BACKEND=1", "release handoff mode should force release-like backend acceptance")
assertContains(releaseRegression, "BACKEND_API_TOKEN= BACKEND_BASE_URL= ./scripts/verify_backend.sh", "backend verify should not inherit deployed backend credentials")
for handoffGuard in [
    "prd-full-feature-closure-decisions-check.swift",
    "echo-state-machine-runtime-check.swift",
    "echo-delayed-reply-notification-check.swift",
    "echo-delayed-reply-push-contract-check.swift",
    "echo-delayed-reply-dispatch-contract-check.swift",
    "backend-voice-runtime-contract-check.swift",
    "profile-account-fields-check.swift",
    "archive-ownership-visibility-check.swift",
    "archive-audio-ia-release-check.swift",
    "archive-audio-lifecycle-smoke-check.swift",
    "true-device-archive-audio-acceptance-check.swift",
    "archive-media-backend-contract-check.swift",
    "archive-media-upload-intent-contract-check.swift",
    "profile-care-public-placeholder-check.swift",
    "release-like-backend-acceptance-check.swift",
] {
    assertContains(releaseRegression, handoffGuard, "release regression should run handoff guard \(handoffGuard)")
}
assertContains(oneCommandRegression, "cannot be disabled by RUN_RELEASE_LIKE_BACKEND=0", "handoff docs should forbid disabling backend acceptance")
assertContains(oneCommandRegression, "PRD decision guard", "handoff docs should list PRD decision guard")
assertContains(oneCommandRegression, "Echo notification guard", "handoff docs should list Echo notification guard")
assertContains(oneCommandRegression, "Profile account fields guard", "handoff docs should list Profile account fields guard")
assertContains(oneCommandRegression, "Archive ownership guard", "handoff docs should list Archive ownership guard")
assertContains(oneCommandRegression, "Care placeholder guard", "handoff docs should list Care placeholder guard")
assertContains(oneCommandRegression, "Release-like backend acceptance", "handoff docs should list release-like backend acceptance")
assertNotContains(oneCommandRegression, "explicitly set `RUN_RELEASE_LIKE_BACKEND=0`", "handoff docs must not suggest bypassing backend acceptance")
assertNotContains(oneCommandRegression, "unless explicitly overridden", "handoff docs must not suggest backend acceptance can be overridden")

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
    "tmp/visual-qa/prd-stitch-ui/run-echo-delayed-reply-notification-smoke.sh",
    "tmp/visual-qa/prd-stitch-ui/echo-delayed-reply-dispatch-contract-check.swift",
    "tmp/visual-qa/prd-stitch-ui/run-release-regression.sh",
    "tmp/visual-qa/prd-stitch-ui/run-backend-env-smoke.sh",
    "tmp/visual-qa/prd-stitch-ui/run-release-like-backend-acceptance.sh",
    "tmp/visual-qa/prd-stitch-ui/final-visual-qa-package-check.swift",
    "tmp/visual-qa/prd-stitch-ui/group1-scaffolding-check.swift",
    "tmp/visual-qa/prd-stitch-ui/group1-source-review-check.swift",
    "tmp/visual-qa/prd-stitch-ui/group2-shell-echo-check.swift",
    "tmp/visual-qa/prd-stitch-ui/echo-archive-context-indicator-check.swift",
    "tmp/visual-qa/prd-stitch-ui/digital-human-mode-lifecycle-check.swift",
    "tmp/visual-qa/prd-stitch-ui/echo-voice-state-visual-check.swift",
    "tmp/visual-qa/prd-stitch-ui/echo-state-machine-runtime-check.swift",
    "tmp/visual-qa/prd-stitch-ui/echo-waiting-reply-policy-check.swift",
    "tmp/visual-qa/prd-stitch-ui/echo-delayed-reply-notification-check.swift",
    "tmp/visual-qa/prd-stitch-ui/echo-delayed-reply-push-contract-check.swift",
    "tmp/visual-qa/prd-stitch-ui/group3-archive-core-check.swift",
    "tmp/visual-qa/prd-stitch-ui/archive-compact-stitch-layout-check.swift",
    "tmp/visual-qa/prd-stitch-ui/archive-timeline-detail-stitch-check.swift",
    "tmp/visual-qa/prd-stitch-ui/archive-analysis-state-stitch-check.swift",
    "tmp/visual-qa/prd-stitch-ui/archive-remote-fetch-check.swift",
    "tmp/visual-qa/prd-stitch-ui/archive-remote-json-behavior-check.swift",
    "tmp/visual-qa/prd-stitch-ui/archive-ownership-visibility-check.swift",
    "tmp/visual-qa/prd-stitch-ui/archive-analysis-disclaimer-check.swift",
    "tmp/visual-qa/prd-stitch-ui/archive-sync-error-recovery-check.swift",
    "tmp/visual-qa/prd-stitch-ui/archive-feature-card-ia-check.swift",
    "tmp/visual-qa/prd-stitch-ui/archive-audio-ia-release-check.swift",
    "tmp/visual-qa/prd-stitch-ui/archive-audio-lifecycle-smoke-check.swift",
    "tmp/visual-qa/prd-stitch-ui/run-archive-audio-lifecycle-smoke.sh",
    "tmp/visual-qa/prd-stitch-ui/true-device-archive-audio-acceptance-check.swift",
    "tmp/visual-qa/prd-stitch-ui/run-true-device-archive-audio-preflight.sh",
    "tmp/visual-qa/prd-stitch-ui/archive-media-backend-contract-check.swift",
    "tmp/visual-qa/prd-stitch-ui/archive-media-upload-intent-contract-check.swift",
    "tmp/visual-qa/prd-stitch-ui/backend-integration-contract-check.py",
    "tmp/visual-qa/prd-stitch-ui/backend-auth-token-check.swift",
    "tmp/visual-qa/prd-stitch-ui/backend-auth-token-contract-check.py",
    "tmp/visual-qa/prd-stitch-ui/backend-build-config-check.swift",
    "tmp/visual-qa/prd-stitch-ui/backend-family-acceptance-check.swift",
    "tmp/visual-qa/prd-stitch-ui/phase0-backend-alignment-check.swift",
    "tmp/visual-qa/prd-stitch-ui/backend-voice-runtime-contract-check.swift",
    "tmp/visual-qa/prd-stitch-ui/backend-postgres-persistence-check.py",
    "tmp/visual-qa/prd-stitch-ui/release-like-backend-acceptance-check.swift",
    "tmp/visual-qa/prd-stitch-ui/backend-contract-gap-check.swift",
    "tmp/visual-qa/prd-stitch-ui/care-snapshot-backend-state-fixtures-check.swift",
    "tmp/visual-qa/prd-stitch-ui/backend-fallback-ui-check.swift",
    "tmp/visual-qa/prd-stitch-ui/login-password-contract-check.swift",
    "tmp/visual-qa/prd-stitch-ui/group4-profile-care-check.swift",
    "tmp/visual-qa/prd-stitch-ui/profile-settings-save-state-check.swift",
    "tmp/visual-qa/prd-stitch-ui/profile-account-fields-check.swift",
    "tmp/visual-qa/prd-stitch-ui/profile-password-change-check.swift",
    "tmp/visual-qa/prd-stitch-ui/profile-care-public-placeholder-check.swift",
    "tmp/visual-qa/prd-stitch-ui/profile-care-snapshot-check.swift",
    "tmp/visual-qa/prd-stitch-ui/profile-care-escalation-contract-check.swift",
    "tmp/visual-qa/prd-stitch-ui/profile-care-escalation-backend-boundary-check.swift",
    "tmp/visual-qa/prd-stitch-ui/run-profile-care-escalation-boundary-smoke.sh",
    "tmp/visual-qa/prd-stitch-ui/profile-compact-stitch-layout-check.swift",
    "tmp/visual-qa/prd-stitch-ui/group5-map-compatibility-check.swift",
    "tmp/visual-qa/prd-stitch-ui/profile-scroll-inset-check.swift",
    "tmp/visual-qa/prd-stitch-ui/release-feature-matrix-check.swift",
    "tmp/visual-qa/prd-stitch-ui/prd-coverage-matrix-check.swift",
    "tmp/visual-qa/prd-stitch-ui/prd-full-feature-closure-decisions-check.swift",
    "tmp/visual-qa/prd-stitch-ui/release-regression-check.swift",
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

let releaseRegressionRunner = read("tmp/visual-qa/prd-stitch-ui/run-release-regression.sh")
let releaseRegressionDoc = read("docs/superpowers/status/2026-06-18-one-command-release-regression.md")
assertContains(releaseRegressionRunner, "RELEASE_HANDOFF_MODE", "release regression should support backend-required handoff mode")
assertContains(releaseRegressionDoc, "Release Handoff Mode", "release regression docs should include handoff mode")

print("Release QA package checks passed with latest smoke \(latestSmoke)")

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

func fileExists(_ relativePath: String) -> Bool {
    fileManager.fileExists(atPath: url(relativePath).path)
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
    "docs/superpowers/status/2026-06-19-archive-analysis-backend-contract.md",
    "docs/superpowers/status/2026-06-19-archive-image-analysis-live-chain.md",
    "docs/superpowers/status/2026-06-19-archive-image-analysis-runtime-contract.md",
    "docs/superpowers/status/2026-06-19-archive-image-analysis-runtime-ui.md",
    "docs/superpowers/status/2026-06-19-backend-archive-image-analysis-smoke.md",
    "docs/superpowers/status/2026-06-19-p0-archive-analysis-care-retry.md",
    "docs/superpowers/status/2026-06-19-archive-failed-analysis-retry-smoke.md",
    "docs/superpowers/status/2026-06-19-profile-care-state-smoke.md",
    "docs/superpowers/status/2026-06-19-profile-care-backend-state-smoke.md",
    "docs/superpowers/status/2026-06-19-time-letter-backend-lifecycle.md",
    "docs/superpowers/status/2026-06-19-time-letter-delivery-policy-shell.md",
    "docs/superpowers/status/2026-06-19-archive-video-hidden-readiness.md",
    "docs/superpowers/status/2026-06-19-true-device-acceptance-evidence-package.md",
    "docs/superpowers/status/2026-06-19-production-voice-sdk-readiness-boundary.md",
    "docs/superpowers/status/2026-06-19-archive-media-echo-context-polish.md",
    "docs/superpowers/status/2026-06-19-archive-hidden-media-combo-gate.md",
    "docs/superpowers/status/2026-06-19-voice-clone-backend-contract.md",
    "docs/superpowers/status/2026-06-19-family-digital-human-hidden-contract.md",
    "docs/superpowers/status/2026-06-19-backend-family-voice-contract-smoke.md",
    "docs/superpowers/status/2026-06-19-ios-family-voice-consumer-contract.md",
    "docs/superpowers/status/2026-06-19-ios-family-voice-hidden-uiqa.md",
    "docs/superpowers/status/2026-06-28-ios-stability-hardening.md",
    "docs/superpowers/status/2026-06-29-tencent-digital-human-pcm-drive-poc.md",
    "docs/superpowers/status/2026-06-29-tencent-audio-drive-backend-pcm-contract.md",
    "docs/superpowers/status/2026-06-29-backend-voice-clone-deployed-smoke.md",
    "docs/superpowers/status/2026-06-29-tencent-backend-pcm-drive-mock-smoke.md",
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

let archiveSmokeScript = read("Scripts/QA/prd-stitch-ui/run-archive-to-echo-smoke.sh")
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

let releaseRegression = read("Scripts/QA/prd-stitch-ui/run-release-regression.sh")
let oneCommandRegression = read("docs/superpowers/status/2026-06-18-one-command-release-regression.md")
assertContains(releaseRegression, "Release handoff mode forces release-like backend acceptance", "release handoff mode should document forced backend acceptance")
assertContains(releaseRegression, "RUN_RELEASE_LIKE_BACKEND=1", "release handoff mode should force release-like backend acceptance")
assertContains(releaseRegression, "RUN_PUBLIC_MVP_REGRESSION", "release regression should expose the public MVP minimum regression gate")
assertContains(releaseRegression, "RUN_PUBLIC_MVP_REGRESSION forces RUN_P0_ARCHIVE_ECHO_REGRESSION and RUN_P0_PROFILE_CARE_REGRESSION", "public MVP gate should force both P0 gates")
assertContains(releaseRegression, "RUN_P0_ARCHIVE_ECHO_REGRESSION", "release regression should expose public MVP Archive -> Echo P0 gate")
assertContains(releaseRegression, "RUN_P0_ARCHIVE_ECHO_REGRESSION forces RUN_SIMULATOR_SMOKE", "Archive -> Echo P0 gate should force the core simulator smoke")
assertContains(releaseRegression, "RUN_BACKEND_ARCHIVE_IMAGE_ANALYSIS_SMOKE", "release regression should expose deployed archive image-analysis smoke")
assertContains(releaseRegression, "RUN_BACKEND_TIME_LETTER_LIFECYCLE_SMOKE", "release regression should expose deployed time-letter lifecycle smoke")
assertContains(releaseRegression, "RUN_DIGITAL_HUMAN_TTS_VISEME_GATE", "release regression should expose optional digital-human TTS/viseme gate")
assertContains(releaseRegression, "run-digital-human-tts-viseme-gate.sh", "release regression should call digital-human TTS/viseme gate")
assertContains(releaseRegression, "RUN_TENCENT_BACKEND_PCM_DRIVE_MOCK_SMOKE", "release regression should expose optional Tencent backend PCM-drive mock smoke")
assertContains(releaseRegression, "run-tencent-backend-pcm-drive-mock-smoke.sh", "release regression should call Tencent backend PCM-drive mock smoke")
assertContains(releaseRegression, "RUN_P0_PROFILE_CARE_REGRESSION", "release regression should expose public MVP Profile care P0 gate")
assertContains(releaseRegression, "RUN_P0_PROFILE_CARE_REGRESSION forces RUN_PROFILE_CARE_STATE_SMOKE and RUN_PROFILE_CARE_BACKEND_STATE_SMOKE", "Profile care P0 gate should force local and deployed backend care smokes")
assertContains(releaseRegression, "BACKEND_API_TOKEN= BACKEND_BASE_URL= ./scripts/verify_backend.sh", "backend verify should not inherit deployed backend credentials")
for handoffGuard in [
    "prd-full-feature-closure-decisions-check.swift",
    "echo-state-machine-runtime-check.swift",
    "echo-delayed-reply-notification-check.swift",
    "echo-delayed-reply-push-contract-check.swift",
    "echo-delayed-reply-dispatch-contract-check.swift",
    "backend-voice-runtime-contract-check.swift",
    "voice-sdk-readiness-boundary-check.swift",
    "profile-account-fields-check.swift",
    "archive-ownership-visibility-check.swift",
    "archive-audio-ia-release-check.swift",
    "archive-audio-lifecycle-smoke-check.swift",
    "archive-local-file-path-recovery-check.swift",
    "true-device-archive-audio-acceptance-check.swift",
    "true-device-acceptance-evidence-package-check.swift",
    "archive-media-backend-contract-check.swift",
    "archive-media-upload-intent-contract-check.swift",
    "archive-media-provider-switch-contract-check.swift",
    "archive-hidden-media-timeletter-shell-check.swift",
    "time-letter-delivery-policy-shell-check.swift",
    "archive-time-letter-backend-lifecycle-check.swift",
    "archive-video-hidden-readiness-check.swift",
    "archive-analysis-insights-contract-check.swift",
    "archive-media-echo-context-polish-check.swift",
    "archive-analysis-backend-payload-contract-check.swift",
    "archive-context-snapshot-check.swift",
    "archive-image-analysis-live-chain-check.swift",
    "archive-image-analysis-runtime-contract-check.swift",
    "archive-image-analysis-runtime-ui-check.swift",
    "backend-archive-image-analysis-smoke-check.swift",
    "p0-archive-analysis-care-retry-check.swift",
    "archive-failed-analysis-retry-smoke-check.swift",
    "profile-care-state-smoke-check.swift",
    "profile-care-backend-state-smoke-check.swift",
    "voice-clone-shell-contract-check.swift",
    "voice-clone-backend-contract-check.swift",
    "family-digital-human-hidden-contract-check.swift",
    "backend-family-voice-contract-smoke-check.swift",
    "backend-voice-clone-deployed-smoke-check.swift",
    "voice-synthesis-viseme-contract-check.swift",
    "voice-synthesis-tencent-audio-drive-contract-check.swift",
    "memoir-tts-cache-contract-check.swift",
    "digital-human-live-panel-check.swift",
    "tencent-digital-human-pcm-drive-poc-check.swift",
    "digital-human-tts-viseme-gate-check.swift",
    "ios-family-voice-consumer-contract-check.swift",
    "ios-family-voice-hidden-uiqa-smoke-check.swift",
    "profile-care-public-placeholder-check.swift",
    "profile-care-snapshot-check.swift",
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
assertContains(oneCommandRegression, "Public MVP Minimal Regression Gate", "handoff docs should document the public MVP minimum regression gate")
assertContains(oneCommandRegression, "RUN_PUBLIC_MVP_REGRESSION=1", "handoff docs should show how to enable the public MVP minimum regression gate")
assertContains(oneCommandRegression, "P0 Archive -> Echo Regression Gate", "handoff docs should document the public MVP Archive -> Echo P0 gate")
assertContains(oneCommandRegression, "RUN_P0_ARCHIVE_ECHO_REGRESSION=1", "handoff docs should show how to enable the Archive -> Echo P0 gate")
assertContains(oneCommandRegression, "P0 Profile Care Regression Gate", "handoff docs should document the public MVP Profile care P0 gate")
assertContains(oneCommandRegression, "RUN_P0_PROFILE_CARE_REGRESSION=1", "handoff docs should show how to enable the Profile care P0 gate")
assertNotContains(oneCommandRegression, "explicitly set `RUN_RELEASE_LIKE_BACKEND=0`", "handoff docs must not suggest bypassing backend acceptance")
assertNotContains(oneCommandRegression, "unless explicitly overridden", "handoff docs must not suggest backend acceptance can be overridden")

let gapAudit = read("docs/superpowers/status/2026-06-17-prd-stitch-ui-gap-audit.md")
assertContains(gapAudit, "Old routes / map", "gap audit should classify old map routes")
assertContains(gapAudit, "QA harness", "gap audit should classify the QA harness")
assertContains(gapAudit, "Project hygiene", "gap audit should classify project hygiene")

let finalVisualStatus = read("docs/superpowers/status/2026-06-18-final-stitch-visual-refresh.md")
assertContains(finalVisualStatus, "current Stitch project", "final visual status should preserve Stitch refresh scope")
assertContains(finalVisualStatus, "Final visual QA package guard", "final visual status should document package guard")
if fileExists("tmp/visual-qa/prd-stitch-ui/final-stitch-visual-qa") {
    let latestFinalVisual = latestDirectoryName(in: "tmp/visual-qa/prd-stitch-ui/final-stitch-visual-qa")
    let finalVisualBase = "tmp/visual-qa/prd-stitch-ui/final-stitch-visual-qa/\(latestFinalVisual)"
    if fileExists("\(finalVisualBase)/report.md"), fileExists("\(finalVisualBase)/build-final.log") {
        let finalVisualReport = read("\(finalVisualBase)/report.md")
        assertContains(finalVisualReport, "current Stitch canvas and downloaded `htmlCode`", "final visual report should preserve Stitch/htmlCode authority")
        assertContains(finalVisualReport, "Release-Gated Differences", "final visual report should classify expected hidden-release differences")
        assertBuildSucceeded("\(finalVisualBase)/build-final.log")
    } else {
        print("Skipped strict final visual evidence validation; latest directory is incomplete: \(finalVisualBase)")
    }
}

let releaseStateBase = "tmp/visual-qa/prd-stitch-ui/release-state-overview/20260617-current"
if fileExists("\(releaseStateBase)/report.md") {
    let releaseStateReport = read("\(releaseStateBase)/report.md")
    assertContains(releaseStateReport, "No hidden-branch launch arguments were used", "release-state report should prove default release mode")
}

let requiredScripts = [
    "Scripts/doctor-ios.sh",
    "Scripts/QA/prd-stitch-ui/ios-doctor-check.swift",
    "Scripts/QA/prd-stitch-ui/qa-script-location-check.swift",
    "Scripts/QA/prd-stitch-ui/docs-qa-script-path-check.swift",
    "Scripts/QA/prd-stitch-ui/digital-human-conversation-coordinator-check.swift",
    "Scripts/QA/prd-stitch-ui/run-archive-to-echo-smoke.sh",
    "Scripts/QA/prd-stitch-ui/run-echo-delayed-reply-notification-smoke.sh",
    "Scripts/QA/prd-stitch-ui/echo-delayed-reply-dispatch-contract-check.swift",
    "Scripts/QA/prd-stitch-ui/run-release-regression.sh",
    "Scripts/QA/prd-stitch-ui/run-backend-env-smoke.sh",
    "Scripts/QA/prd-stitch-ui/run-release-like-backend-acceptance.sh",
    "Scripts/QA/prd-stitch-ui/final-visual-qa-package-check.swift",
    "Scripts/QA/prd-stitch-ui/group1-scaffolding-check.swift",
    "Scripts/QA/prd-stitch-ui/group1-source-review-check.swift",
    "Scripts/QA/prd-stitch-ui/group2-shell-echo-check.swift",
    "Scripts/QA/prd-stitch-ui/echo-archive-context-indicator-check.swift",
    "Scripts/QA/prd-stitch-ui/digital-human-mode-lifecycle-check.swift",
    "Scripts/QA/prd-stitch-ui/echo-voice-state-visual-check.swift",
    "Scripts/QA/prd-stitch-ui/echo-state-machine-runtime-check.swift",
    "Scripts/QA/prd-stitch-ui/echo-waiting-reply-policy-check.swift",
    "Scripts/QA/prd-stitch-ui/echo-delayed-reply-notification-check.swift",
    "Scripts/QA/prd-stitch-ui/echo-delayed-reply-push-contract-check.swift",
    "Scripts/QA/prd-stitch-ui/group3-archive-core-check.swift",
    "Scripts/QA/prd-stitch-ui/archive-compact-stitch-layout-check.swift",
    "Scripts/QA/prd-stitch-ui/archive-timeline-detail-stitch-check.swift",
    "Scripts/QA/prd-stitch-ui/archive-analysis-state-stitch-check.swift",
    "Scripts/QA/prd-stitch-ui/archive-remote-fetch-check.swift",
    "Scripts/QA/prd-stitch-ui/archive-remote-json-behavior-check.swift",
    "Scripts/QA/prd-stitch-ui/archive-ownership-visibility-check.swift",
    "Scripts/QA/prd-stitch-ui/archive-analysis-disclaimer-check.swift",
    "Scripts/QA/prd-stitch-ui/archive-sync-error-recovery-check.swift",
    "Scripts/QA/prd-stitch-ui/archive-local-file-path-recovery-check.swift",
    "Scripts/QA/prd-stitch-ui/archive-feature-card-ia-check.swift",
    "Scripts/QA/prd-stitch-ui/archive-audio-ia-release-check.swift",
    "Scripts/QA/prd-stitch-ui/archive-audio-lifecycle-smoke-check.swift",
    "Scripts/QA/prd-stitch-ui/run-archive-audio-lifecycle-smoke.sh",
    "Scripts/QA/prd-stitch-ui/true-device-archive-audio-acceptance-check.swift",
    "Scripts/QA/prd-stitch-ui/true-device-acceptance-evidence-package-check.swift",
    "Scripts/QA/prd-stitch-ui/run-true-device-archive-audio-preflight.sh",
    "Scripts/QA/prd-stitch-ui/run-true-device-tencent-backend-pcm-drive-smoke.sh",
    "Scripts/QA/prd-stitch-ui/archive-media-backend-contract-check.swift",
    "Scripts/QA/prd-stitch-ui/archive-media-upload-intent-contract-check.swift",
    "Scripts/QA/prd-stitch-ui/archive-media-provider-switch-contract-check.swift",
    "Scripts/QA/prd-stitch-ui/archive-hidden-media-timeletter-shell-check.swift",
    "Scripts/QA/prd-stitch-ui/time-letter-delivery-policy-shell-check.swift",
    "Scripts/QA/prd-stitch-ui/archive-hidden-media-backend-upload-lifecycle-check.swift",
    "Scripts/QA/prd-stitch-ui/archive-time-letter-backend-lifecycle-check.swift",
    "Scripts/QA/prd-stitch-ui/archive-hidden-media-detail-ui-check.swift",
    "Scripts/QA/prd-stitch-ui/archive-video-hidden-readiness-check.swift",
    "Scripts/QA/prd-stitch-ui/archive-hidden-media-runtime-ui-check.swift",
    "Scripts/QA/prd-stitch-ui/archive-hidden-media-combo-gate-check.swift",
    "Scripts/QA/prd-stitch-ui/archive-media-echo-context-polish-check.swift",
    "Scripts/QA/prd-stitch-ui/run-archive-media-echo-context-smoke.sh",
    "Scripts/QA/prd-stitch-ui/run-archive-hidden-shell-smoke.sh",
    "Scripts/QA/prd-stitch-ui/run-archive-hidden-media-combo-gate.sh",
    "Scripts/QA/prd-stitch-ui/backend-hidden-media-sync-smoke.py",
    "Scripts/QA/prd-stitch-ui/run-backend-hidden-media-sync-smoke.sh",
    "Scripts/QA/prd-stitch-ui/backend-time-letter-lifecycle-smoke.py",
    "Scripts/QA/prd-stitch-ui/run-backend-time-letter-lifecycle-smoke.sh",
    "Scripts/QA/prd-stitch-ui/archive-analysis-insights-contract-check.swift",
    "Scripts/QA/prd-stitch-ui/archive-analysis-backend-payload-contract-check.swift",
    "Scripts/QA/prd-stitch-ui/archive-context-snapshot-check.swift",
    "Scripts/QA/prd-stitch-ui/archive-image-analysis-live-chain-check.swift",
    "Scripts/QA/prd-stitch-ui/archive-image-analysis-runtime-contract-check.swift",
    "Scripts/QA/prd-stitch-ui/archive-image-analysis-runtime-ui-check.swift",
    "Scripts/QA/prd-stitch-ui/backend-archive-image-analysis-smoke-check.swift",
    "Scripts/QA/prd-stitch-ui/p0-archive-analysis-care-retry-check.swift",
    "Scripts/QA/prd-stitch-ui/archive-failed-analysis-retry-smoke-check.swift",
    "Scripts/QA/prd-stitch-ui/run-archive-failed-analysis-retry-smoke.sh",
    "Scripts/QA/prd-stitch-ui/profile-care-state-smoke-check.swift",
    "Scripts/QA/prd-stitch-ui/run-profile-care-state-smoke.sh",
    "Scripts/QA/prd-stitch-ui/profile-care-backend-state-smoke-check.swift",
    "Scripts/QA/prd-stitch-ui/backend-care-state-uiqa-fixtures.py",
    "Scripts/QA/prd-stitch-ui/run-profile-care-backend-state-smoke.sh",
    "Scripts/QA/prd-stitch-ui/backend-archive-image-analysis-smoke.py",
    "Scripts/QA/prd-stitch-ui/run-backend-archive-image-analysis-smoke.sh",
    "Scripts/QA/prd-stitch-ui/voice-clone-shell-contract-check.swift",
    "Scripts/QA/prd-stitch-ui/voice-clone-backend-contract-check.swift",
    "Scripts/QA/prd-stitch-ui/family-digital-human-hidden-contract-check.swift",
    "Scripts/QA/prd-stitch-ui/backend-family-voice-contract-smoke-check.swift",
    "Scripts/QA/prd-stitch-ui/ios-family-voice-consumer-contract-check.swift",
    "Scripts/QA/prd-stitch-ui/ios-family-voice-hidden-uiqa-smoke-check.swift",
    "Scripts/QA/prd-stitch-ui/backend-family-voice-contract-smoke.py",
    "Scripts/QA/prd-stitch-ui/run-backend-family-voice-contract-smoke.sh",
    "Scripts/QA/prd-stitch-ui/backend-voice-clone-deployed-smoke-check.swift",
    "Scripts/QA/prd-stitch-ui/backend-voice-clone-deployed-smoke.py",
    "Scripts/QA/prd-stitch-ui/run-backend-voice-clone-deployed-smoke.sh",
    "Scripts/QA/prd-stitch-ui/voice-clone-profile-selection-smoke-check.swift",
    "Scripts/QA/prd-stitch-ui/run-voice-clone-profile-selection-smoke.sh",
    "Scripts/QA/prd-stitch-ui/voice-clone-synthesis-runtime-smoke-check.swift",
    "Scripts/QA/prd-stitch-ui/run-voice-clone-synthesis-runtime-smoke.sh",
    "Scripts/QA/prd-stitch-ui/tencent-backend-pcm-drive-mock-smoke-check.swift",
    "Scripts/QA/prd-stitch-ui/run-tencent-backend-pcm-drive-mock-smoke.sh",
    "Scripts/QA/prd-stitch-ui/voice-clone-status-feedback-check.swift",
    "Scripts/QA/prd-stitch-ui/voice-clone-runtime-capability-check.swift",
    "Scripts/QA/prd-stitch-ui/backend-digital-human-session-smoke-check.swift",
    "Scripts/QA/prd-stitch-ui/backend-digital-human-session-smoke.py",
    "Scripts/QA/prd-stitch-ui/run-backend-digital-human-session-smoke.sh",
    "Scripts/QA/prd-stitch-ui/voice-synthesis-viseme-contract-check.swift",
    "Scripts/QA/prd-stitch-ui/voice-synthesis-tencent-audio-drive-contract-check.swift",
    "Scripts/QA/prd-stitch-ui/memoir-tts-cache-contract-check.swift",
    "Scripts/QA/prd-stitch-ui/digital-human-live-panel-check.swift",
    "Scripts/QA/prd-stitch-ui/tencent-digital-human-pcm-drive-poc-check.swift",
    "Scripts/QA/prd-stitch-ui/backend-voice-synthesis-viseme-smoke.py",
    "Scripts/QA/prd-stitch-ui/run-backend-voice-synthesis-viseme-smoke.sh",
    "Scripts/QA/prd-stitch-ui/run-digital-human-tts-viseme-gate.sh",
    "Scripts/QA/prd-stitch-ui/digital-human-tts-viseme-gate-check.swift",
    "Scripts/QA/prd-stitch-ui/backend-integration-contract-check.py",
    "Scripts/QA/prd-stitch-ui/backend-auth-token-check.swift",
    "Scripts/QA/prd-stitch-ui/backend-auth-token-contract-check.py",
    "Scripts/QA/prd-stitch-ui/backend-build-config-check.swift",
    "Scripts/QA/prd-stitch-ui/backend-family-acceptance-check.swift",
    "Scripts/QA/prd-stitch-ui/phase0-backend-alignment-check.swift",
    "Scripts/QA/prd-stitch-ui/backend-voice-runtime-contract-check.swift",
    "Scripts/QA/prd-stitch-ui/voice-sdk-readiness-boundary-check.swift",
    "Scripts/QA/prd-stitch-ui/backend-postgres-persistence-check.py",
    "Scripts/QA/prd-stitch-ui/release-like-backend-acceptance-check.swift",
    "Scripts/QA/prd-stitch-ui/backend-contract-gap-check.swift",
    "Scripts/QA/prd-stitch-ui/care-snapshot-backend-state-fixtures-check.swift",
    "Scripts/QA/prd-stitch-ui/backend-fallback-ui-check.swift",
    "Scripts/QA/prd-stitch-ui/login-password-contract-check.swift",
    "Scripts/QA/prd-stitch-ui/group4-profile-care-check.swift",
    "Scripts/QA/prd-stitch-ui/profile-settings-save-state-check.swift",
    "Scripts/QA/prd-stitch-ui/profile-account-fields-check.swift",
    "Scripts/QA/prd-stitch-ui/profile-password-change-check.swift",
    "Scripts/QA/prd-stitch-ui/profile-care-public-placeholder-check.swift",
    "Scripts/QA/prd-stitch-ui/profile-care-snapshot-check.swift",
    "Scripts/QA/prd-stitch-ui/profile-care-escalation-contract-check.swift",
    "Scripts/QA/prd-stitch-ui/profile-care-escalation-backend-boundary-check.swift",
    "Scripts/QA/prd-stitch-ui/run-profile-care-escalation-boundary-smoke.sh",
    "Scripts/QA/prd-stitch-ui/profile-compact-stitch-layout-check.swift",
    "Scripts/QA/prd-stitch-ui/group5-map-compatibility-check.swift",
    "Scripts/QA/prd-stitch-ui/profile-scroll-inset-check.swift",
    "Scripts/QA/prd-stitch-ui/release-feature-matrix-check.swift",
    "Scripts/QA/prd-stitch-ui/prd-coverage-matrix-check.swift",
    "Scripts/QA/prd-stitch-ui/prd-full-feature-closure-decisions-check.swift",
    "Scripts/QA/prd-stitch-ui/release-regression-check.swift",
    "Scripts/QA/prd-stitch-ui/release-qa-package-check.swift",
    "Scripts/QA/prd-stitch-ui/submit-slice-inventory-check.swift",
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
    if fileExists("\(base)/report.md"), fileExists("\(base)/build-final.log") {
        assertBuildSucceeded("\(base)/build-final.log")
    } else {
        print("Skipped strict \(group) evidence validation; report/build log is not present.")
    }
}

let group6Base = "tmp/visual-qa/prd-stitch-ui/group6-release-qa-package/20260617-current"
if fileExists("\(group6Base)/report.md"), fileExists("\(group6Base)/build-final.log") {
    assertBuildSucceeded("\(group6Base)/build-final.log")
} else {
    print("Skipped strict Group 6 evidence validation; report/build log is not present.")
}

let backendIntegrationBase = "tmp/visual-qa/prd-stitch-ui/backend-integration/20260617-current"
if fileExists("\(backendIntegrationBase)/report.md"), fileExists("\(backendIntegrationBase)/build-uiqa.log") {
    assertBuildSucceeded("\(backendIntegrationBase)/build-uiqa.log")
} else {
    print("Skipped strict backend integration evidence validation; report/build log is not present.")
}

let backendAuthBase = "tmp/visual-qa/prd-stitch-ui/backend-auth-token/20260617-current"
if fileExists("\(backendAuthBase)/report.md"), fileExists("\(backendAuthBase)/build-uiqa.log") {
    assertBuildSucceeded("\(backendAuthBase)/build-uiqa.log")
} else {
    print("Skipped strict backend auth token evidence validation; report/build log is not present.")
}

let backendFallbackBase = "tmp/visual-qa/prd-stitch-ui/backend-fallback-ui/20260617-current"
if fileExists("\(backendFallbackBase)/report.md"), fileExists("\(backendFallbackBase)/build-standard-debug.log"), fileExists("\(backendFallbackBase)/build-uiqa.log") {
    assertBuildSucceeded("\(backendFallbackBase)/build-standard-debug.log")
    assertBuildSucceeded("\(backendFallbackBase)/build-uiqa.log")
} else {
    print("Skipped strict backend fallback UI evidence validation; report/build logs are not present.")
}

let backendBuildConfigBase = "tmp/visual-qa/prd-stitch-ui/backend-build-config/20260617-current"
if fileExists("\(backendBuildConfigBase)/report.md"), fileExists("\(backendBuildConfigBase)/build-default-debug.log"), fileExists("\(backendBuildConfigBase)/build-override-debug.log") {
    assertBuildSucceeded("\(backendBuildConfigBase)/build-default-debug.log")
    assertBuildSucceeded("\(backendBuildConfigBase)/build-override-debug.log")
} else {
    print("Skipped strict backend build config evidence validation; report/build logs are not present.")
}

if fileExists("tmp/visual-qa/prd-stitch-ui/archive-to-echo-smoke") {
    let latestSmoke = latestDirectoryName(in: "tmp/visual-qa/prd-stitch-ui/archive-to-echo-smoke")
    let latestSmokeBase = "tmp/visual-qa/prd-stitch-ui/archive-to-echo-smoke/\(latestSmoke)"
    if fileExists("\(latestSmokeBase)/archive-to-echo-smoke-result.json") {
        assertSmokeResultSucceeded("\(latestSmokeBase)/archive-to-echo-smoke-result.json")
    } else {
        print("Skipped strict latest smoke evidence validation; result JSON is not present.")
    }
}

let gitignore = read(".gitignore")
assertContains(gitignore, "tmp/**/DerivedData*", "gitignore should exclude generated DerivedData")

let releaseRegressionRunner = read("Scripts/QA/prd-stitch-ui/run-release-regression.sh")
let releaseRegressionDoc = read("docs/superpowers/status/2026-06-18-one-command-release-regression.md")
assertContains(releaseRegressionRunner, "RELEASE_HANDOFF_MODE", "release regression should support backend-required handoff mode")
assertContains(releaseRegressionDoc, "Release Handoff Mode", "release regression docs should include handoff mode")

print("Release QA package checks passed")

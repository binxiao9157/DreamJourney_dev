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

let coveragePath = "docs/superpowers/status/2026-06-18-prd-coverage-matrix.md"
assertFileExists(coveragePath, "PRD coverage matrix")

let coverage = read(coveragePath)
let releasePackage = read("tmp/visual-qa/prd-stitch-ui/release-qa-package-check.swift")

assertContains(coverage, "# PRD Coverage Matrix", "coverage matrix should have title")
assertContains(coverage, "Source of truth", "coverage matrix should document source of truth")
assertContains(coverage, "current Stitch canvas and `htmlCode`", "coverage matrix should keep visual authority")
assertContains(coverage, "MCP screenshots are auxiliary", "coverage matrix should keep MCP screenshots auxiliary")
assertContains(coverage, "| PRD requirement | Current status | Public? | Evidence | Next action |", "coverage matrix should use the required table")

let requiredRowMarkers = [
    "| 回响语音输入 | implemented with production voice SDK configuration gate and explicit readiness boundary |",
    "| 2-3轮后等待回信 | implemented ten-round/adaptive policy with persisted in-app state",
    "| 档案照片 | implemented with sync error recovery |",
    "| 档案视频 | hidden readiness shell implemented with mock detail/list state",
    "| 档案录音 | hidden candidate with non-true-device lifecycle",
    "| 档案文字描述 | implemented with sync error recovery |",
    "| 时间信件 | public delivery foundation implemented with text + image creation",
    "| 个人资料管理 | implemented for profile fields and login password participation",
    "| 心境追踪 | implemented fallback and data states |",
    "| 家人管理 | implemented public phone invitation foundation",
    "| 法律法规 | implemented | yes |",
    "| 账号退出 | implemented | yes |",
    "| 账号注销 | implemented public soft-delete foundation",
    "| 长辈关怀 | implemented aggregate with loading/empty/stale/failed states |",
    "| 后端合同闭环 | partially implemented; contract gaps pinned |",
    "| 生死转换机制 | hidden boundary |",
    "| 声音克隆 | public foundation with backend lifecycle contract",
]

for marker in requiredRowMarkers {
    assertContains(coverage, marker, "coverage matrix should include required PRD row marker")
}

let requiredStatuses = [
    "implemented with production voice SDK configuration gate and explicit readiness boundary",
    "implemented ten-round/adaptive policy",
    "implemented with sync error recovery",
    "hidden readiness shell implemented",
    "hidden candidate with non-true-device lifecycle",
    "public delivery foundation implemented",
    "implemented public phone invitation foundation",
    "public foundation with backend lifecycle contract",
    "implemented fallback and data states",
    "implemented public soft-delete foundation",
    "hidden boundary",
    "partially implemented; contract gaps pinned",
]

for status in requiredStatuses {
    assertContains(coverage, status, "coverage matrix should use explicit status \(status)")
}

for phrase in [
    "真机已验收",
    "true-device complete",
    "real backend complete",
    "production backend accepted",
    "physical device accepted",
] {
    assertNotContains(coverage, phrase, "coverage matrix must not overclaim external acceptance")
}

for phrase in [
    "Last synced: 2026-06-21",
    "2026-06-19 Phase 0 Sync Notes",
    "Hidden Family / Voice UIQA Consumer Gate",
    "时间信件公开投递闭环",
    "视频档案 Hidden Readiness",
    "真机验收包强化",
    "生产语音 SDK readiness 边界",
    "家庭成员规则",
    "账号注销规则",
    "Remaining Work By Decision Type",
    "Public MVP engineering remains",
    "Hidden engineering remains",
    "External acceptance remains",
    "Product / compliance decisions remain",
] {
    assertContains(coverage, phrase, "coverage matrix should include Phase 0 sync section and remaining-work classification")
}

for phrase in [
    "VoiceSDKReadinessSummary",
    "voice-sdk-readiness-boundary-check.swift",
    "true-device-acceptance-evidence-package-check.swift",
    "time-letter-delivery-policy-shell-check.swift",
    "archive-video-hidden-readiness-check.swift",
    "backend-family-voice-contract-smoke-check.swift",
    "ios-family-voice-hidden-uiqa-smoke-check.swift",
] {
    assertContains(coverage, phrase, "coverage matrix should include recent task evidence \(phrase)")
}

assertContains(coverage, "本地 FastAPI 后端 smoke：accepted", "coverage matrix should mark local FastAPI backend smoke as accepted")
assertContains(coverage, "release-like FastAPI/Postgres 后端验收：accepted", "coverage matrix should mark release-like Postgres backend as accepted")
assertContains(coverage, "线上/公网后端验收：accepted for simulator release-like scope", "coverage matrix should mark simulator remote backend as accepted")
assertContains(coverage, "真机验收：partially accepted", "coverage matrix should mark true-device as partially accepted without overclaiming full acceptance")
assertContains(coverage, "signed build, install, launch, and process evidence passed", "coverage matrix should record true-device signed build/install/launch evidence")
assertContains(coverage, "permission prompts, archive photo picker, voice conversation, foreground/background, playback route, logs, and screenshot evidence remain open", "coverage matrix should keep manual true-device flow open")
assertContains(coverage, "生产语音 SDK key now resolves through build settings", "coverage matrix should document production voice SDK config injection")
assertContains(coverage, "run-true-device-voice-preflight.sh", "coverage matrix should reference true-device voice preflight")
assertContains(coverage, "True-device console output shows `SpeechEngineToB` SDK initialization", "coverage matrix should record true-device voice SDK initialization evidence")
assertContains(coverage, "`VoiceSDKReadinessSummary` now separates", "coverage matrix should document production voice SDK readiness boundary")
assertContains(coverage, "production voice quality is still not accepted", "coverage matrix should preserve production voice quality external gate")
assertContains(coverage, "APNs provider delivery / 真机通知到达：not accepted", "coverage matrix should keep APNs as not accepted")
assertContains(coverage, "skips APNs registration when `aps-environment` is absent", "coverage matrix should document APNs entitlement-gated registration")
assertContains(coverage, "Paid-Team Push capability", "coverage matrix should document paid-team APNs blocker")
assertContains(coverage, "the old third-turn default policy has been superseded", "coverage matrix should document superseded Echo policy")
assertContains(coverage, "In-app state, local notification, device-token registration, delayed-reply backend persistence, and the `POST /echo/delayed-replies/dispatch-due` ready-for-provider contract are implemented", "coverage matrix should document implemented Echo notification scope")
assertContains(coverage, "20260618-deployed-push-device-token-contract-rerun-205018", "coverage matrix should record latest deployed push token acceptance")
assertContains(coverage, "20260618-deployed-echo-dispatch-contract-accepted-211732", "coverage matrix should record accepted deployed dispatch rerun")
assertContains(coverage, "were blocked by HTTP 405 before the backend redeploy and are retained as recovered deployment-drift evidence", "coverage matrix should preserve recovered dispatch deployment drift evidence")
assertContains(coverage, "APNs provider delivery and true-device notification acceptance remain open", "coverage matrix should preserve external Echo notification gates")
assertContains(coverage, "name/gender/region validation", "coverage matrix should document updated profile scope")
assertContains(coverage, "Password change hidden shell", "coverage matrix should document password shell state")
assertContains(coverage, "PasswordAPITests", "coverage matrix should document local password backend tests")
assertContains(coverage, "Login password participation is covered", "coverage matrix should document completed iOS password login participation")
assertContains(coverage, "selected-backend password acceptance has passed", "coverage matrix should record selected backend password acceptance")
assertContains(coverage, "auth/security review and true-device acceptance remain open", "coverage matrix should preserve password external gates")
assertContains(coverage, "`profile-password-change-check.swift`", "coverage matrix should reference password shell guard")
assertContains(coverage, "后端合同闭环", "coverage matrix should include backend contract closure row")
assertContains(coverage, "2026-06-18-backend-contract-gap-matrix.md", "coverage matrix should reference backend contract gap matrix")
assertContains(coverage, "backend-contract-gap-check.swift", "coverage matrix should reference backend contract guard")
assertContains(coverage, "档案文字 / 照片同步失败恢复", "coverage matrix should document archive text/photo sync recovery")
assertContains(coverage, "archive-sync-error-recovery-check.swift", "coverage matrix should reference archive sync recovery guard")
assertContains(coverage, "item metadata tracks `pending` / `synced` / `failed`", "coverage matrix should document archive backend sync states")
assertContains(coverage, "Hidden audio, time-letter, and video candidates remain outside default public sync recovery", "coverage matrix should keep hidden media outside public sync recovery")
assertContains(coverage, "/echo/delayed-replies", "coverage matrix should call out echo delayed reply backend gap")
assertContains(coverage, "/echo/delayed-replies/dispatch-due", "coverage matrix should call out echo delayed reply dispatch backend gap")
assertContains(coverage, "/devices/push-token", "coverage matrix should call out push device token backend gap")
assertContains(coverage, "/profile", "coverage matrix should call out profile backend gap")
assertContains(coverage, "/auth/password", "coverage matrix should call out password backend gap")
assertContains(coverage, "No remaining hidden PRD feature is public by default", "coverage matrix should preserve release gating policy")
assertContains(coverage, "## Hidden Candidate Release Matrix", "coverage matrix should link hidden candidates to release matrix")
assertContains(coverage, "docs/superpowers/status/2026-06-17-release-feature-matrix.md", "coverage matrix should reference release feature matrix")
assertContains(coverage, "archive audio upload", "coverage matrix should name archive audio candidate")
assertContains(coverage, "video upload", "coverage matrix should name archive video candidate")
assertContains(coverage, "family advanced lifecycle controls", "coverage matrix should name family advanced lifecycle candidate")
assertContains(coverage, "care escalation draft", "coverage matrix should name care escalation draft candidate")
assertContains(coverage, "digital inheritance lifecycle", "coverage matrix should name digital inheritance candidate")
assertContains(coverage, "20260618-deployed-postgres-acceptance-after-deploy", "coverage matrix should record accepted backend run")
assertContains(coverage, "20260618-selected-backend-latest-contracts-after-deploy-r2", "coverage matrix should record latest accepted backend run")
assertContains(coverage, "deployed push-token registration, delayed-reply `deviceTokenId` persistence, and dispatch-due route parity are accepted", "coverage matrix should record recovered deployed push and dispatch route parity")
assertContains(coverage, "APNs provider delivery and true-device notification arrival remain external gates", "coverage matrix should keep APNs and true-device notification as blockers")
assertContains(coverage, "后续如有后端合同变化，需要 rerun `run-release-like-backend-acceptance.sh`", "coverage matrix should require backend reruns after backend changes")
assertContains(coverage, "需要真机、签名和设备操作", "coverage matrix should call out device blocker")

assertContains(releasePackage, "tmp/visual-qa/prd-stitch-ui/prd-coverage-matrix-check.swift", "release QA package should include PRD coverage guard")
assertContains(releasePackage, coveragePath, "release QA package should include PRD coverage doc")

print("PRD coverage matrix checks passed")

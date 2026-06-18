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

let requiredRows = [
    "| 回响语音输入 | implemented | yes | `EchoViewController`, archive-to-echo smoke | true-device microphone acceptance |",
    "| 2-3轮后等待回信 | implemented ten-round/adaptive policy with persisted in-app state, local notification, deployed backend device-token registration, deployed backend delayed-reply persistence, and local backend dispatch-due contract | yes | `EchoViewModel`, `EchoDelayedReplyStore`, `EchoDelayedReplyNotificationScheduler`, `PushDeviceTokenStore`, echo delayed reply notification/push/dispatch checks, deployed run `20260618-deployed-push-device-token-contract-rerun-205018`, blocked dispatch run `20260618-deployed-echo-dispatch-contract-210536` | deploy dispatch-due route, rerun release-like backend acceptance, APNs provider delivery, true-device voice/notification acceptance |",
    "| 档案照片 | implemented | yes | Archive photo entry smoke | true-device photo acceptance |",
    "| 档案视频 | hidden candidate shell | no | archive media readiness guard, release matrix | picker/compression/storage/backend policy, true-device video picker acceptance |",
    "| 档案录音 | hidden candidate | no | archive media smoke | true-device audio acceptance |",
    "| 档案文字描述 | implemented | yes | archive smoke | maintain |",
    "| 时间信件 | hidden candidate | no | archive media smoke | delivery policy |",
    "| 个人资料管理 | implemented for profile fields and login password participation with selected-backend `/profile`, `/auth/login`, and `/auth/password` acceptance; password change UI remains hidden | yes for profile fields and login; no for password change | `LoginViewController`, `ProfileSettingsViewController`, `ProfilePasswordChangeViewController`, `login-password-contract-check.swift`, backend `ProfileAPITests`, backend `PasswordAPITests`, release-like backend run `20260618-selected-backend-latest-contracts-after-deploy-r2` | auth/security review, true-device acceptance, explicit password-change public release decision |",
    "| 心境追踪 | implemented fallback and data states | yes | Profile care checks, care data states check | lifecycle policy |",
    "| 家人管理 | hidden candidate | no | family persona smoke | product exposure decision |",
    "| 法律法规 | implemented | yes | `ProfileLegalViewController` | legal review |",
    "| 账号退出 | implemented | yes | `ProfileViewController` | maintain |",
    "| 账号注销 | hidden blocked shell | no | safety check | compliance/backend contract |",
    "| 长辈关怀 | implemented aggregate with loading/empty/stale/failed states | yes | elder dashboard check, profile care public placeholder check | real backend acceptance |",
    "| 生死转换机制 | hidden boundary | no | mode lifecycle checks | product/legal policy |",
]

for row in requiredRows {
    assertContains(coverage, row, "coverage matrix should include required PRD row")
}

let requiredStatuses = [
    "implemented",
    "partially implemented",
    "implemented ten-round/adaptive policy with persisted in-app state, local notification, deployed backend device-token registration, deployed backend delayed-reply persistence, and local backend dispatch-due contract",
    "hidden candidate",
    "hidden candidate shell",
    "hidden blocked shell",
    "hidden boundary",
    "implemented aggregate",
    "implemented aggregate with loading/empty/stale/failed states",
    "implemented fallback",
    "implemented fallback and data states",
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

assertContains(coverage, "本地 FastAPI 后端 smoke：accepted", "coverage matrix should mark local FastAPI backend smoke as accepted")
assertContains(coverage, "release-like FastAPI/Postgres 后端验收：accepted", "coverage matrix should mark release-like Postgres backend as accepted")
assertContains(coverage, "线上/公网后端验收：accepted for simulator release-like scope", "coverage matrix should mark simulator remote backend as accepted")
assertContains(coverage, "真机验收：not accepted", "coverage matrix should mark true-device as not accepted")
assertContains(coverage, "the old third-turn default policy has been superseded", "coverage matrix should document superseded Echo policy")
assertContains(coverage, "In-app state, local notification, device-token registration, delayed-reply backend persistence, and the local `POST /echo/delayed-replies/dispatch-due` ready-for-provider contract are implemented", "coverage matrix should document implemented Echo notification scope")
assertContains(coverage, "20260618-deployed-push-device-token-contract-rerun-205018", "coverage matrix should record latest deployed push token acceptance")
assertContains(coverage, "20260618-deployed-echo-dispatch-contract-210536", "coverage matrix should record blocked deployed dispatch acceptance")
assertContains(coverage, "deployed dispatch acceptance run `20260618-deployed-echo-dispatch-contract-210536` is blocked by HTTP 405", "coverage matrix should preserve dispatch deployment drift evidence")
assertContains(coverage, "APNs provider delivery, deployed service-side scheduled dispatch acceptance, and true-device notification acceptance remain open", "coverage matrix should preserve external Echo notification gates")
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
assertContains(coverage, "/echo/delayed-replies", "coverage matrix should call out echo delayed reply backend gap")
assertContains(coverage, "/echo/delayed-replies/dispatch-due", "coverage matrix should call out echo delayed reply dispatch backend gap")
assertContains(coverage, "/devices/push-token", "coverage matrix should call out push device token backend gap")
assertContains(coverage, "/profile", "coverage matrix should call out profile backend gap")
assertContains(coverage, "/auth/password", "coverage matrix should call out password backend gap")
assertContains(coverage, "No hidden PRD feature is public by default", "coverage matrix should preserve release gating policy")
assertContains(coverage, "## Hidden Candidate Release Matrix", "coverage matrix should link hidden candidates to release matrix")
assertContains(coverage, "docs/superpowers/status/2026-06-17-release-feature-matrix.md", "coverage matrix should reference release feature matrix")
assertContains(coverage, "archive audio upload", "coverage matrix should name archive audio candidate")
assertContains(coverage, "video upload", "coverage matrix should name archive video candidate")
assertContains(coverage, "hidden shell only; PRD scope and media backend contract still required", "coverage matrix should document video shell boundary")
assertContains(coverage, "family management public release", "coverage matrix should name family management candidate")
assertContains(coverage, "care escalation draft", "coverage matrix should name care escalation draft candidate")
assertContains(coverage, "digital inheritance lifecycle", "coverage matrix should name digital inheritance candidate")
assertContains(coverage, "20260618-deployed-postgres-acceptance-after-deploy", "coverage matrix should record accepted backend run")
assertContains(coverage, "20260618-selected-backend-latest-contracts-after-deploy-r2", "coverage matrix should record latest accepted backend run")
assertContains(coverage, "deployed push-token registration and delayed-reply `deviceTokenId` persistence are accepted", "coverage matrix should record recovered deployed push route parity")
assertContains(coverage, "dispatch-due route deployment", "coverage matrix should keep dispatch-due route deployment as a blocker")
assertContains(coverage, "后续如有后端合同变化，需要 rerun `run-release-like-backend-acceptance.sh`", "coverage matrix should require backend reruns after backend changes")
assertContains(coverage, "需要真机、签名和设备操作", "coverage matrix should call out device blocker")

assertContains(releasePackage, "tmp/visual-qa/prd-stitch-ui/prd-coverage-matrix-check.swift", "release QA package should include PRD coverage guard")
assertContains(releasePackage, coveragePath, "release QA package should include PRD coverage doc")

print("PRD coverage matrix checks passed")

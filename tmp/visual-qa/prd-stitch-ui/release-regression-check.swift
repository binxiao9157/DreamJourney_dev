import Foundation

let root = URL(fileURLWithPath: CommandLine.arguments.dropFirst().first ?? FileManager.default.currentDirectoryPath)
let fileManager = FileManager.default

func read(_ relativePath: String) -> String {
    let url = root.appendingPathComponent(relativePath)
    guard let content = try? String(contentsOf: url, encoding: .utf8) else {
        fatalError("Unable to read \(url.path)")
    }
    return content
}

func assertFileExists(_ relativePath: String, _ message: String) {
    let url = root.appendingPathComponent(relativePath)
    guard fileManager.fileExists(atPath: url.path) else {
        fatalError("\(message): missing \(relativePath)")
    }
}

func assertContains(_ haystack: String, _ needle: String, _ message: String) {
    guard haystack.contains(needle) else {
        fatalError("\(message): missing \(needle)")
    }
}

assertFileExists("tmp/visual-qa/prd-stitch-ui/run-release-regression.sh", "release regression runner")
assertFileExists("docs/superpowers/status/2026-06-18-one-command-release-regression.md", "release regression status doc")

let runner = read("tmp/visual-qa/prd-stitch-ui/run-release-regression.sh")
let status = read("docs/superpowers/status/2026-06-18-one-command-release-regression.md")
let releasePackage = read("tmp/visual-qa/prd-stitch-ui/release-qa-package-check.swift")

for phrase in [
    "RUN_STANDARD_BUILD",
    "RUN_SIMULATOR_SMOKE",
    "RUN_BACKEND_ENV_SMOKE",
    "RELEASE_HANDOFF_MODE",
    "RUN_RELEASE_LIKE_BACKEND",
    "./scripts/verify_backend.sh",
    "backend-postgres-persistence-check.py",
    "release-feature-matrix-check.swift",
    "prd-coverage-matrix-check.swift",
    "phase0-backend-alignment-check.swift",
    "release-like-backend-acceptance-check.swift",
    "backend-env-smoke-check.swift",
    "final-visual-qa-package-check.swift",
    "release-qa-package-check.swift",
    "git diff --check",
    "xcodebuild",
    "run-archive-to-echo-smoke.sh",
    "run-backend-env-smoke.sh",
    "run-release-like-backend-acceptance.sh",
] {
    assertContains(runner, phrase, "runner should include \(phrase)")
}

for phrase in [
    "one-command release regression",
    "run-release-regression.sh",
    "Archive -> Echo",
    "RUN_RELEASE_LIKE_BACKEND=1",
    "Release Handoff Mode",
    "RELEASE_HANDOFF_MODE=1",
    "Postgres release-like backend remains optional",
] {
    assertContains(status, phrase, "status doc should include \(phrase)")
}

assertContains(
    releasePackage,
    "docs/superpowers/status/2026-06-18-one-command-release-regression.md",
    "release QA package should include release regression status doc"
)
assertContains(
    releasePackage,
    "tmp/visual-qa/prd-stitch-ui/run-release-regression.sh",
    "release QA package should include release regression runner"
)
assertContains(
    releasePackage,
    "tmp/visual-qa/prd-stitch-ui/release-regression-check.swift",
    "release QA package should include release regression guard"
)

print("Release regression checks passed")

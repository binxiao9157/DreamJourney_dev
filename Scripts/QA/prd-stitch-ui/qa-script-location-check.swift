import Foundation

let root = CommandLine.arguments.dropFirst().first ?? FileManager.default.currentDirectoryPath
let rootURL = URL(fileURLWithPath: root)

func shell(_ command: String) -> String {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/bin/zsh")
    process.arguments = ["-lc", command]
    process.currentDirectoryURL = rootURL
    let pipe = Pipe()
    process.standardOutput = pipe
    process.standardError = pipe
    try! process.run()
    process.waitUntilExit()
    return String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
}

func read(_ relativePath: String) -> String {
    let url = rootURL.appendingPathComponent(relativePath)
    return (try? String(contentsOf: url, encoding: .utf8)) ?? ""
}

func require(_ condition: @autoclosure () -> Bool, _ message: String) {
    if !condition() {
        fputs("qa-script-location-check failed: \(message)\n", stderr)
        exit(1)
    }
}

let trackedTmpScripts = shell("git ls-files 'tmp/visual-qa/prd-stitch-ui/*' | rg '^tmp/visual-qa/prd-stitch-ui/[^/]+\\.(swift|sh|py)$' || true")
require(trackedTmpScripts.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, "durable QA scripts must not be tracked under tmp: \(trackedTmpScripts)")

let trackedScriptCount = Int(shell("git ls-files 'Scripts/QA/prd-stitch-ui/*' | rg '\\.(swift|sh|py)$' | wc -l").trimmingCharacters(in: .whitespacesAndNewlines)) ?? 0
require(trackedScriptCount > 100, "expected migrated QA scripts under Scripts/QA/prd-stitch-ui")

let gitignore = read(".gitignore")
require(gitignore.contains("\ntmp/\n"), ".gitignore should make tmp a generated-output directory")

let readme = read("Scripts/QA/prd-stitch-ui/README.md")
require(readme.contains("durable QA and smoke scripts"), "QA README should explain script ownership")
require(readme.contains("tmp/visual-qa/prd-stitch-ui"), "QA README should keep generated outputs under tmp")

let releasePackage = read("Scripts/QA/prd-stitch-ui/release-qa-package-check.swift")
require(releasePackage.contains("Scripts/QA/prd-stitch-ui/run-release-regression.sh"), "release package should reference stable script paths")
require(!releasePackage.contains("tmp/visual-qa/prd-stitch-ui/run-release-regression.sh"), "release package should not require scripts from tmp")

print("qa-script-location-check passed")

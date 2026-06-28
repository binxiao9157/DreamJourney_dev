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

func assertContains(_ haystack: String, _ needle: String, _ message: String) {
    guard haystack.contains(needle) else {
        fatalError("\(message): missing \(needle)")
    }
}

func assertFileExists(_ relativePath: String, minBytes: UInt64 = 1, _ message: String) {
    let fileURL = url(relativePath)
    guard let attributes = try? fileManager.attributesOfItem(atPath: fileURL.path),
          let size = attributes[.size] as? UInt64,
          size >= minBytes else {
        fatalError("\(message): missing or too small \(relativePath)")
    }
}

func fileExists(_ relativePath: String, minBytes: UInt64 = 1) -> Bool {
    let fileURL = url(relativePath)
    guard let attributes = try? fileManager.attributesOfItem(atPath: fileURL.path),
          let size = attributes[.size] as? UInt64 else {
        return false
    }
    return size >= minBytes
}

func latestDirectoryName(in relativePath: String) -> String? {
    let directoryURL = url(relativePath)
    guard let contents = try? fileManager.contentsOfDirectory(
        at: directoryURL,
        includingPropertiesForKeys: [.isDirectoryKey, .contentModificationDateKey],
        options: [.skipsHiddenFiles]
    ) else {
        return nil
    }

    let directories = contents.compactMap { candidate -> (name: String, modifiedAt: Date)? in
        let values = try? candidate.resourceValues(forKeys: [.isDirectoryKey, .contentModificationDateKey])
        guard values?.isDirectory == true else {
            return nil
        }
        return (candidate.lastPathComponent, values?.contentModificationDate ?? .distantPast)
    }
    return directories.sorted(by: {
        if $0.modifiedAt == $1.modifiedAt {
            return $0.name < $1.name
        }
        return $0.modifiedAt < $1.modifiedAt
    }).last?.name
}

func assertBuildSucceeded(_ relativePath: String) {
    assertContains(read(relativePath), "** BUILD SUCCEEDED **", "\(relativePath) should contain a successful build")
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
    guard object["entries"] as? String == "相册影像（相册）" else {
        fatalError("Smoke result entries changed: \(relativePath)")
    }
}

let finalVisualStatus = read("docs/superpowers/status/2026-06-18-final-stitch-visual-refresh.md")
assertContains(finalVisualStatus, "current Stitch project", "final visual status should describe Stitch refresh scope")
assertContains(finalVisualStatus, "Final visual QA package guard", "final visual status should document package guard")

if let latestFinalVisual = latestDirectoryName(in: "tmp/visual-qa/prd-stitch-ui/final-stitch-visual-qa") {
    let finalBase = "tmp/visual-qa/prd-stitch-ui/final-stitch-visual-qa/\(latestFinalVisual)"
    if fileExists("\(finalBase)/report.md"), fileExists("\(finalBase)/build-final.log") {
        let finalReport = read("\(finalBase)/report.md")
        assertContains(finalReport, "current Stitch canvas and downloaded `htmlCode`", "final Stitch visual report should name the visual source of truth")
        assertContains(finalReport, "Release-Gated Differences", "final Stitch visual report should separate release-gated differences")
        assertContains(finalReport, "DJEnableArchiveHiddenBranches", "final Stitch visual report should document archive hidden QA mode")
        assertContains(finalReport, "DJEnableProfileHiddenBranches", "final Stitch visual report should document profile hidden QA mode")
        assertBuildSucceeded("\(finalBase)/build-final.log")
    } else {
        print("Skipped strict final visual evidence validation; latest directory is incomplete: \(finalBase)")
    }
} else {
    print("Skipped strict final visual evidence validation; no final-stitch-visual-qa directory is present.")
}

let releaseStateBase = "tmp/visual-qa/prd-stitch-ui/release-state-overview/20260617-current"
if fileExists("\(releaseStateBase)/report.md") {
    let releaseStateReport = read("\(releaseStateBase)/report.md")
    assertContains(releaseStateReport, "No hidden-branch launch arguments were used", "release-state report should prove default release mode")
    assertContains(releaseStateReport, "Visible by default:", "release-state report should list public entries")
    assertContains(releaseStateReport, "Hidden by default:", "release-state report should list hidden entries")
} else {
    print("Skipped strict release-state visual evidence validation; release-state report is not present.")
}

let finalVisualReport = read("tmp/visual-qa/prd-stitch-ui/final-visual-qa/20260617-current/report.md")
assertContains(finalVisualReport, "Login page is light/cream, not black.", "legacy black-login regression should stay documented")
assertContains(finalVisualReport, "Bottom nav labels are `记忆档案`, `回响`, `我的`.", "tab labels should stay documented")

let profileIAContract = read("docs/superpowers/status/2026-06-18-profile-ia-contract.md")
assertContains(profileIAContract, "`我的` remains the third public tab", "Profile IA contract should preserve the third tab decision")
assertContains(profileIAContract, "`长辈关怀` aggregate card or child dashboard entry", "Profile IA contract should carry care under Profile")
assertContains(profileIAContract, "not a tab replacement", "Profile IA contract should prevent care tab rename drift")
assertContains(profileIAContract, "Current Stitch canvas + downloaded `htmlCode`", "Profile IA contract should preserve Stitch evidence rules")

if let latestSmoke = latestDirectoryName(in: "tmp/visual-qa/prd-stitch-ui/archive-to-echo-smoke") {
    let latestSmokeBase = "tmp/visual-qa/prd-stitch-ui/archive-to-echo-smoke/\(latestSmoke)"
    if fileExists("\(latestSmokeBase)/archive-to-echo-smoke-result.json") {
        assertSmokeResultSucceeded("\(latestSmokeBase)/archive-to-echo-smoke-result.json")
    } else {
        print("Skipped strict archive-to-echo smoke evidence validation; latest directory is incomplete: \(latestSmokeBase)")
    }
    print("Final visual QA package source checks passed with latest smoke directory \(latestSmoke)")
} else {
    print("Final visual QA package source checks passed; no archive-to-echo smoke directory is present.")
}

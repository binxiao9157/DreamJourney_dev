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

let latestFinalVisual = latestDirectoryName(in: "tmp/visual-qa/prd-stitch-ui/final-stitch-visual-qa")
let finalBase = "tmp/visual-qa/prd-stitch-ui/final-stitch-visual-qa/\(latestFinalVisual)"
let finalReport = read("\(finalBase)/report.md")
assertContains(finalReport, "current Stitch canvas and downloaded `htmlCode`", "final Stitch visual report should name the visual source of truth")
assertContains(finalReport, "Release-Gated Differences", "final Stitch visual report should separate release-gated differences")
assertContains(finalReport, "DJEnableArchiveHiddenBranches", "final Stitch visual report should document archive hidden QA mode")
assertContains(finalReport, "DJEnableProfileHiddenBranches", "final Stitch visual report should document profile hidden QA mode")
assertBuildSucceeded("\(finalBase)/build-final.log")

for fileName in [
    "01-login.png",
    "02-echo-default.png",
    "03-archive-default.png",
    "04-profile-default.png",
    "05-echo-stitch-qa.png",
    "06-archive-stitch-qa-hidden-branches.png",
    "07-profile-stitch-qa-hidden-branches.png",
] {
    assertFileExists("\(finalBase)/app/\(fileName)", minBytes: 16_384, "final app screenshot")
}

for screen in ["login", "echo", "archive", "profile"] {
    assertFileExists("\(finalBase)/stitch/\(screen).html", minBytes: 512, "Stitch htmlCode export")
    assertFileExists("\(finalBase)/stitch/\(screen).png", minBytes: 8_192, "Stitch raster reference")
}
assertFileExists("\(finalBase)/stitch/source-manifest.md", minBytes: 128, "Stitch source manifest")

let releaseStateBase = "tmp/visual-qa/prd-stitch-ui/release-state-overview/20260617-current"
let releaseStateReport = read("\(releaseStateBase)/report.md")
assertContains(releaseStateReport, "No hidden-branch launch arguments were used", "release-state report should prove default release mode")
assertContains(releaseStateReport, "Visible by default:", "release-state report should list public entries")
assertContains(releaseStateReport, "Hidden by default:", "release-state report should list hidden entries")
for fileName in [
    "01-echo-default.jpg",
    "02-archive-default.jpg",
    "03-archive-create-sheet-default.jpg",
    "04-profile-default.jpg",
    "05-profile-settings-default.jpg",
    "06-profile-legal-default.jpg",
] {
    assertFileExists("\(releaseStateBase)/\(fileName)", minBytes: 16_384, "release-state screenshot")
}

let finalVisualReport = read("tmp/visual-qa/prd-stitch-ui/final-visual-qa/20260617-current/report.md")
assertContains(finalVisualReport, "Login page is light/cream, not black.", "legacy black-login regression should stay documented")
assertContains(finalVisualReport, "Bottom nav labels are `记忆档案`, `回响`, `我的`.", "tab labels should stay documented")

let latestSmoke = latestDirectoryName(in: "tmp/visual-qa/prd-stitch-ui/archive-to-echo-smoke")
let latestSmokeBase = "tmp/visual-qa/prd-stitch-ui/archive-to-echo-smoke/\(latestSmoke)"
assertFileExists("\(latestSmokeBase)/01-archive-to-echo-completed.png", minBytes: 16_384, "latest archive-to-echo screenshot")
assertSmokeResultSucceeded("\(latestSmokeBase)/archive-to-echo-smoke-result.json")

print("Final visual QA package checks passed with latest smoke \(latestSmoke)")

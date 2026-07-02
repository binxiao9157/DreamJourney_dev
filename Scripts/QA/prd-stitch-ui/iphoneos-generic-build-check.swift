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

let runner = "Scripts/QA/prd-stitch-ui/run-iphoneos-generic-build.sh"
assertFileExists(runner, "iPhoneOS generic build runner")

let runnerContent = read(runner)
let releaseRegression = read("Scripts/QA/prd-stitch-ui/run-release-regression.sh")
let releaseQA = read("Scripts/QA/prd-stitch-ui/release-qa-package-check.swift")

for required in [
    "-destination 'generic/platform=iOS'",
    "-sdk iphoneos",
    "CODE_SIGNING_ALLOWED=NO",
    "DREAMJOURNEY_PRODUCT_BUNDLE_IDENTIFIER",
    "DREAMJOURNEY_DEVELOPMENT_TEAM",
    "$CONFIGURATION-iphoneos",
    "iPhoneOS generic build: passed",
] {
    assertContains(runnerContent, required, "iPhoneOS generic build runner should include \(required)")
}

for required in [
    "RUN_IPHONEOS_GENERIC_BUILD",
    "run-iphoneos-generic-build.sh",
    "iphoneos-generic-build-check.swift",
] {
    assertContains(releaseRegression, required, "release regression should include \(required)")
}

for required in [
    "run-iphoneos-generic-build.sh",
    "iphoneos-generic-build-check.swift",
] {
    assertContains(releaseQA, required, "release QA package should include \(required)")
}

print("iPhoneOS generic build checks passed")

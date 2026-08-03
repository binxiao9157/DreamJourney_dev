import Foundation

let root = CommandLine.arguments.dropFirst().first ?? FileManager.default.currentDirectoryPath
let rootURL = URL(fileURLWithPath: root)

func read(_ relativePath: String) -> String {
    let url = rootURL.appendingPathComponent(relativePath)
    return (try? String(contentsOf: url, encoding: .utf8)) ?? ""
}

func fileExists(_ relativePath: String) -> Bool {
    FileManager.default.fileExists(atPath: rootURL.appendingPathComponent(relativePath).path)
}

func require(_ condition: @autoclosure () -> Bool, _ message: String) {
    if !condition() {
        fputs("ios-doctor-check failed: \(message)\n", stderr)
        exit(1)
    }
}

let scriptPath = "Scripts/doctor-ios.sh"
require(fileExists(scriptPath), "Scripts/doctor-ios.sh must exist")

let script = read(scriptPath)
require(script.contains("VirtualmanStreamSDK.xcframework"), "doctor must check bundled Tencent SDK")
require(script.contains("DreamJourney.xcworkspace"), "doctor must check workspace")
require(script.contains("Podfile.lock"), "doctor must check CocoaPods install state")
require(script.contains("Backend.local.xcconfig"), "doctor must check backend local config")
require(script.contains("DREAMJOURNEY_BACKEND_BASE_URL"), "doctor must parse backend base URL")
require(script.contains("DREAMJOURNEY_BACKEND_API_TOKEN"), "doctor must parse backend API token")
require(script.contains("DREAMJOURNEY_DEVELOPMENT_TEAM"), "doctor must check signing team override")
require(script.contains("DREAMJOURNEY_PRODUCT_BUNDLE_IDENTIFIER"), "doctor must check bundle id override")
require(
    script.contains("mobile Provider credentials: retired"),
    "doctor must document the backend-only Provider credential boundary"
)
for retiredCredential in ["VoiceSDK.local.xcconfig", "VOLCENGINE_APP_ID", "VOLCENGINE_APP_KEY", "VOLCENGINE_APP_TOKEN"] {
    require(!script.contains(retiredCredential), "doctor must not require retired mobile Provider credentials")
}
require(script.contains("/health"), "doctor must optionally check backend health")
require(script.contains("/config/runtime"), "doctor must optionally check runtime config")
require(script.contains("value intentionally omitted"), "doctor must redact secret values")
require(!script.contains("set -x"), "doctor must not echo commands with secrets")

let releasePackage = read("Scripts/QA/prd-stitch-ui/release-qa-package-check.swift")
require(releasePackage.contains("Scripts/doctor-ios.sh"), "release package should include doctor script")

print("ios-doctor-check passed")

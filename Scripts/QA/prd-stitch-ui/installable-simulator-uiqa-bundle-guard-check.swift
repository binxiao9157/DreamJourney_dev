import Foundation

let root = URL(fileURLWithPath: CommandLine.arguments.dropFirst().first ?? FileManager.default.currentDirectoryPath)

func read(_ relativePath: String) -> String {
    let url = root.appendingPathComponent(relativePath)
    guard let content = try? String(contentsOf: url, encoding: .utf8) else {
        fatalError("Unable to read \(url.path)")
    }
    return content
}

func require(_ condition: @autoclosure () -> Bool, _ message: String) {
    guard condition() else {
        fatalError(message)
    }
}

func requireFile(_ relativePath: String) {
    require(FileManager.default.fileExists(atPath: root.appendingPathComponent(relativePath).path), "Missing \(relativePath)")
}

let helperPath = "Scripts/QA/prd-stitch-ui/run-installable-simulator-uiqa.sh"
let echoTracePath = "Scripts/QA/prd-stitch-ui/run-echo-trace-export-uiqa-smoke.sh"

requireFile(helperPath)
requireFile(echoTracePath)

let helper = read(helperPath)
let echoTraceSmoke = read(echoTracePath)
let archiveSmoke = read("Scripts/QA/prd-stitch-ui/run-archive-to-echo-smoke.sh")
let delayedReplySmoke = read("Scripts/QA/prd-stitch-ui/run-echo-delayed-reply-notification-smoke.sh")
let releaseRegression = read("Scripts/QA/prd-stitch-ui/run-release-regression.sh")
let releaseQA = read("Scripts/QA/prd-stitch-ui/release-qa-package-check.swift")
let statusDoc = read("docs/superpowers/status/2026-07-01-current-implementation-prd-alignment.md")

require(helper.contains("LOCAL_BUNDLE_ID=\"${LOCAL_BUNDLE_ID:-com.yxj.dreamjourney.app}\""), "installable simulator helper must default to the local QA bundle id")
require(helper.contains("LOCAL_DEVELOPMENT_TEAM=\"${LOCAL_DEVELOPMENT_TEAM:-2BTR77V3R8}\""), "installable simulator helper must default to the local QA team id")
require(helper.contains("DREAMJOURNEY_PRODUCT_BUNDLE_IDENTIFIER=\"$LOCAL_BUNDLE_ID\""), "installable simulator helper should pass the app bundle id through the project-owned setting")
require(helper.contains("DREAMJOURNEY_DEVELOPMENT_TEAM=\"$LOCAL_DEVELOPMENT_TEAM\""), "installable simulator helper should pass the app team through the project-owned setting")
require(!helper.contains("\n  PRODUCT_BUNDLE_IDENTIFIER=\"$LOCAL_BUNDLE_ID\""), "installable simulator helper must not use global PRODUCT_BUNDLE_IDENTIFIER because it pollutes Pods framework bundle ids")
require(!helper.contains("\nPRODUCT_BUNDLE_IDENTIFIER=\"$LOCAL_BUNDLE_ID\""), "installable simulator helper must not use global PRODUCT_BUNDLE_IDENTIFIER because it pollutes Pods framework bundle ids")
require(!helper.contains("PRODUCT_BUNDLE_IDENTIFIER=com.yxj.dreamjourney.app"), "installable simulator helper must not hard-code global PRODUCT_BUNDLE_IDENTIFIER")
require(helper.contains("EXCLUDED_ARCHS[sdk=iphonesimulator*]="), "installable simulator helper should clear simulator arm64 exclusions for Apple Silicon simulators")
require(helper.contains("lipo -archs"), "installable simulator helper should verify the built executable archs")
require(helper.contains("arm64"), "installable simulator helper should require arm64 simulator output")
require(helper.contains("/usr/bin/codesign --force --sign -"), "installable simulator helper should ad-hoc sign the simulator app before install")
require(helper.contains("xcrun simctl install"), "installable simulator helper should install the app on the booted simulator")
require(!helper.contains("LOCAL_BUNDLE_ID:-com.gaominge.dreamjourney.app"), "installable simulator helper must not default to the shared bundle id")
require(!helper.contains("DREAMJOURNEY_PRODUCT_BUNDLE_IDENTIFIER=\"com.gaominge.dreamjourney.app\""), "installable simulator helper must not build the shared bundle id")

for smoke in [archiveSmoke, delayedReplySmoke, echoTraceSmoke] {
    require(smoke.contains("run-installable-simulator-uiqa.sh"), "simulator UIQA smokes should use the shared installable build helper")
    require(!smoke.contains("com.gaominge.dreamjourney.app"), "simulator UIQA smokes must not run against the shared default bundle id")
    require(!smoke.contains("PRODUCT_BUNDLE_IDENTIFIER=com.yxj.dreamjourney.app"), "simulator UIQA smokes must not use global PRODUCT_BUNDLE_IDENTIFIER")
}

require(echoTraceSmoke.contains("DJRunEchoTraceExportSmoke"), "Echo trace export UIQA smoke should launch the Echo trace harness")
require(echoTraceSmoke.contains("echo-trace-export-smoke-result.json"), "Echo trace export UIQA smoke should copy the app-written result JSON")
require(echoTraceSmoke.contains("echo-trace-records.json"), "Echo trace export UIQA smoke should verify exported trace JSON")
require(echoTraceSmoke.contains("uiqa-turn-2") && echoTraceSmoke.contains("uiqa-turn-21"), "Echo trace export UIQA smoke should verify latest 20 trace retention")

require(releaseRegression.contains("installable-simulator-uiqa-bundle-guard-check.swift"), "release regression should run the installable simulator bundle guard")
require(releaseRegression.contains("RUN_ECHO_TRACE_EXPORT_UIQA_SMOKE"), "release regression should expose optional Echo trace export UIQA smoke")
require(releaseRegression.contains("run-echo-trace-export-uiqa-smoke.sh"), "release regression should call Echo trace export UIQA smoke")

require(releaseQA.contains("installable-simulator-uiqa-bundle-guard-check.swift"), "release QA package should include the bundle guard")
require(releaseQA.contains("run-installable-simulator-uiqa.sh"), "release QA package should include the shared installable simulator helper")
require(releaseQA.contains("run-echo-trace-export-uiqa-smoke.sh"), "release QA package should include Echo trace export UIQA smoke")

require(statusDoc.contains("Installable Simulator UIQA Bundle Guard"), "status doc should document the local bundle guard")
require(statusDoc.contains("com.yxj.dreamjourney.app") && statusDoc.contains("2BTR77V3R8"), "status doc should record the local QA bundle/team")

print("Installable simulator UIQA bundle guard passed")

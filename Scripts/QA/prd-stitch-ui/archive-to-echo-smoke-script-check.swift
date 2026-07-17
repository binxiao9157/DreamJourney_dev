import Foundation

let root = CommandLine.arguments.dropFirst().first ?? FileManager.default.currentDirectoryPath

func read(_ relativePath: String) -> String {
    let path = "\(root)/\(relativePath)"
    guard let content = try? String(contentsOfFile: path, encoding: .utf8) else {
        fatalError("Unable to read \(path)")
    }
    return content
}

func assertContains(_ haystack: String, _ needle: String, _ message: String) {
    guard haystack.contains(needle) else {
        fatalError("\(message): missing \(needle)")
    }
}

let appDelegate = read("DreamJourney/Sources/AppDelegate.swift")
let detail = read("DreamJourney/Sources/Modules/Archive/MemoryArchiveDetailViewController.swift")
let echo = read("DreamJourney/Sources/Modules/Echo/EchoViewController.swift")
let script = read("Scripts/QA/prd-stitch-ui/run-archive-to-echo-smoke.sh")
let installableHelper = read("Scripts/QA/prd-stitch-ui/run-installable-simulator-uiqa.sh")

assertContains(appDelegate, "DJRunArchiveToEchoSmoke", "archive-to-echo smoke launch argument")
assertContains(appDelegate, "runArchiveToEchoSmoke()", "archive-to-echo smoke runner")
assertContains(appDelegate, "[UI_QA] ArchiveToEchoSmoke completed", "archive-to-echo smoke completion log")
assertContains(appDelegate, "DialogPromptDebugRecorder.lastSnapshot", "archive-to-echo smoke verifies prompt recorder")
assertContains(appDelegate, "writeArchiveToEchoSmokeResult", "archive-to-echo smoke writes a pollable result file")
assertContains(appDelegate, "archive-to-echo-smoke-result.json", "archive-to-echo smoke result file name")

assertContains(detail, "runUIQALocalAnalysisSmoke()", "archive detail exposes UIQA local analysis wrapper")
assertContains(detail, "analyzeArchiveItemTapped()", "archive detail UIQA wrapper uses existing analysis action")

assertContains(echo, "runUIQAMicrophoneSmoke()", "echo exposes UIQA microphone wrapper")
assertContains(echo, "DialogEngineManager.shared.startDialog(", "echo UIQA wrapper starts the simulator dialog engine without backend credentials")
assertContains(echo, "usesTurnScopedKnowledgeContext: true", "echo UIQA wrapper should match production turn-scoped context mode")

assertContains(script, "DJRunArchiveToEchoSmoke", "smoke script launches the app with the auto-run argument")
assertContains(script, "SWIFT_ACTIVE_COMPILATION_CONDITIONS='DEBUG UI_QA_SIMULATOR'", "smoke script builds UIQA variant")
assertContains(script, "run-installable-simulator-uiqa.sh", "smoke script uses the shared installable simulator helper")
assertContains(installableHelper, "xcrun simctl install", "installable simulator helper installs the built app")
assertContains(script, "xcrun simctl launch", "smoke script launches the built app")
assertContains(script, "ArchiveToEchoSmoke completed", "smoke script waits for completion log")
assertContains(installableHelper, "xcrun simctl get_app_container", "installable simulator helper locates app data container")
assertContains(script, "archive-to-echo-smoke-result.json", "smoke script polls the app-written result file")
assertContains(script, "simctl io", "smoke script captures simulator screenshot")

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

func assertOrder(_ haystack: String, _ first: String, _ second: String, _ message: String) {
    guard let firstRange = haystack.range(of: first),
          let secondRange = haystack.range(of: second),
          firstRange.lowerBound < secondRange.lowerBound else {
        fatalError("\(message): expected \(first) before \(second)")
    }
}

let appDelegate = read("DreamJourney/Sources/AppDelegate.swift")
let featureFlags = read("DreamJourney/Sources/App/FeatureFlagService.swift")
let dialogManager = read("DreamJourney/Sources/Services/DialogEngineManager.swift")
let microphone = read("DreamJourney/Sources/Services/MicrophonePermissionManager.swift")

assertContains(appDelegate, "#if UI_QA_SIMULATOR && targetEnvironment(simulator)", "QA launch harness compile gate")
assertContains(featureFlags, "DJSeedEchoArchiveContext", "QA scenario registry should retain the archive context seed argument")
assertContains(appDelegate, "case .seedEchoArchiveContext", "AppDelegate should dispatch the archive context seed through the scenario registry")
assertContains(appDelegate, "UserManager.shared.login(phone: \"13800009999\"", "QA launch harness logs in deterministic user")
assertContains(appDelegate, "UserDefaults.standard.removeObject(forKey: \"dj.memoryArchive.items.user_9999\")", "QA launch harness resets deterministic archive state")
assertContains(appDelegate, "MemoryArchiveItemFactory.makeTextItem(", "QA launch harness seeds archive text item")
assertContains(appDelegate, "note: \"爸爸在老家院子里讲起小时候听收音机的声音\"", "QA launch harness seeds deterministic archive note")
assertContains(appDelegate, "MemoryArchiveRepository.shared.add(item, syncToBackend: false)", "QA launch harness persists seeded archive item without backend sync")

assertContains(dialogManager, "recordUIQAPromptSnapshot()", "QA dialog manager prompt snapshot hook")
assertContains(dialogManager, "let archiveSnapshot = MemoryArchiveRepository.shared.contextSnapshot()", "QA dialog prompt uses archive context snapshot")
assertContains(dialogManager, "let archiveContext = archiveSnapshot.promptSection", "QA dialog prompt reads archive prompt section")
assertContains(dialogManager, "private func buildArchiveContext() -> String", "real dialog archive context helper")
assertContains(dialogManager, "let archiveContext = buildArchiveContext()", "real dialog prompt injects archive context outside session gate")
assertContains(dialogManager, "fullPrompt += archiveContext", "real dialog prompt appends archive context")
assertContains(dialogManager, "DialogPromptDebugRecorder.record(prompt: prompt)", "QA dialog prompt records debug snapshot")
assertContains(dialogManager, "[UI_QA] Echo archive prompt containsArchiveContext=", "QA dialog prompt logs recorder status")
assertContains(dialogManager, "entries=\\(archiveSnapshot.debugSummary())", "QA dialog prompt logs archive entry summary")
assertOrder(
    dialogManager,
    "recordUIQAPromptSnapshot()",
    "delegate?.onDialogStarted()",
    "QA prompt should be recorded before dialog started callback"
)

assertContains(microphone, "#if UI_QA_SIMULATOR && targetEnvironment(simulator)", "QA microphone permission compile gate")
assertContains(microphone, "completion(true)", "QA microphone permission auto grant")

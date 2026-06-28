import Foundation

let root = CommandLine.arguments.dropFirst().first ?? FileManager.default.currentDirectoryPath
let path = "\(root)/DreamJourney/Sources/Services/DialogEngineManager.swift"

guard let source = try? String(contentsOfFile: path, encoding: .utf8) else {
    fatalError("Unable to read \(path)")
}

func assertContains(_ needle: String, _ message: String) {
    guard source.contains(needle) else {
        fatalError("\(message): missing \(needle)")
    }
}

func assertOrder(_ first: String, _ second: String, _ message: String) {
    guard let firstRange = source.range(of: first),
          let secondRange = source.range(of: second),
          firstRange.lowerBound < secondRange.lowerBound else {
        fatalError("\(message): expected \(first) before \(second)")
    }
}

assertContains("#if DEBUG || UI_QA_SIMULATOR", "debug recorder compile gate")
assertContains("struct DialogPromptDebugSnapshot", "debug prompt snapshot type")
assertContains("enum DialogPromptDebugRecorder", "debug prompt recorder type")
assertContains("private(set) static var lastSnapshot", "debug recorder keeps latest prompt only")
assertContains("containsArchiveContext: prompt.contains(\"【记忆档案馆素材线索】\")", "debug recorder marks archive context presence")
assertContains("DialogPromptDebugRecorder.record(prompt: fullPrompt)", "dialog manager records final prompt")
assertOrder(
    "DialogPromptDebugRecorder.record(prompt: fullPrompt)",
    "let startResult = engine.send(SEDirectiveStartEngine, data: configJSON)",
    "prompt should be recorded before starting engine"
)

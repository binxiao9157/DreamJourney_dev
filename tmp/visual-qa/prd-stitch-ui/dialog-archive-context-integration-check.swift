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

assertContains(
    "MemoryArchiveRepository.shared.contextSnapshot().promptSection",
    "dialog archive context helper uses archive context snapshot"
)
assertContains("private func buildArchiveContext() -> String", "dialog manager keeps archive context as independent helper")
assertContains("let archiveContext = buildArchiveContext()", "dialog prompt builds archive context outside memory session gate")
assertContains("fullPrompt += archiveContext", "dialog prompt appends archive prompt section")
assertOrder(
    "if memory.sessionCount > 0 {",
    "let archiveContext = buildArchiveContext()",
    "archive context should not be hidden inside previous-session branch"
)
assertOrder(
    "fullPrompt += archiveContext",
    "DialogPromptDebugRecorder.record(prompt: fullPrompt)",
    "archive context should be appended before debug prompt recording"
)

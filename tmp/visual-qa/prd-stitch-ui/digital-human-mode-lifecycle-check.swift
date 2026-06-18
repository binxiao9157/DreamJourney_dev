import Foundation

let root = URL(fileURLWithPath: CommandLine.arguments.dropFirst().first ?? FileManager.default.currentDirectoryPath)

func read(_ relativePath: String) throws -> String {
    try String(contentsOf: root.appendingPathComponent(relativePath), encoding: .utf8)
}

func require(_ condition: @autoclosure () -> Bool, _ message: String) {
    guard condition() else {
        fputs("Digital human mode lifecycle check failed: \(message)\n", stderr)
        exit(1)
    }
}

let echoViewModel = try read("DreamJourney/Sources/Modules/Echo/EchoViewModel.swift")
let echoView = try read("DreamJourney/Sources/Modules/Echo/EchoViewController.swift")
let dialogManager = try read("DreamJourney/Sources/Services/DialogEngineManager.swift")
let profile = try read("DreamJourney/Sources/Modules/Profile/ProfileViewController.swift")

require(echoViewModel.contains("let mode: DigitalHumanMode"), "Echo archive status must carry selected digital-human mode")
require(echoViewModel.contains("shouldShowArchiveContextIndicator"), "Echo should derive indicator visibility from mode and archive availability")
require(echoViewModel.contains("mode != .silent"), "Silent digital-human mode must hide archive context indicator")
require(echoViewModel.contains("关怀线索正在参与回响"), "Star mode should use care-oriented echo context copy without exposing mode name")
require(!echoViewModel.contains("星辰关怀"), "Echo visible copy must not expose the internal star mode name")
require(!echoViewModel.contains("静默"), "Echo visible copy must not expose the internal silent mode name")

require(echoView.contains("status.shouldShowArchiveContextIndicator"), "Echo UI must hide/show archive indicator through mode-aware status")
require(echoView.contains("status.indicatorText"), "Echo UI must render mode-aware archive indicator text")

require(dialogManager.contains("buildDigitalHumanModePolicy(context:"), "Dialog prompt must include a mode policy helper")
require(dialogManager.contains("shouldExposePersonalContext(for:"), "Dialog prompt must have one personal-context exposure gate for memory, KB, archive, and greeting paths")
require(
    dialogManager.contains("shouldExposeArchiveContext(for context: DigitalHumanContext)")
        && dialogManager.contains("shouldExposePersonalContext(for: context)"),
    "Dialog prompt must guard archive context through the personal-context exposure gate"
)
require(dialogManager.contains("DigitalHumanContextStore.shared.current"), "Dialog prompt must read the selected digital-human context")
require(dialogManager.contains("context.mode == .silent") || dialogManager.contains("case .silent"), "Dialog prompt must handle silent mode explicitly")
require(dialogManager.contains("不是医疗诊断"), "Star-mode prompt policy should keep psychological guidance within safety boundaries")
require(dialogManager.contains("不公开展示"), "Silent-mode prompt policy should preserve non-public display boundary")
require(dialogManager.contains("if shouldExposePersonalContext(for: context)"), "Silent mode must suppress historical memory and KBLite prompt injection")
require(dialogManager.contains("let hasContext = shouldUseContextualGreeting && memory.sessionCount > 0 && memory.lastSummary.hasAnyDimension"), "Silent mode must suppress context/KBLite-based greeting hints")
require(dialogManager.contains("guard shouldExposeArchiveContext(for: context) else { return \"\" }"), "Archive prompt builder must share the personal-context exposure gate")

require(profile.contains("personaStatusColor(context:"), "Profile persona status dot should reflect lifecycle state")
require(profile.contains("这份回响暂不公开展示"), "Profile silent persona subtitle should explain non-public display boundary")
require(profile.contains("context.mode == .silent"), "Profile should handle silent mode explicitly")

print("Digital human mode lifecycle checks passed")

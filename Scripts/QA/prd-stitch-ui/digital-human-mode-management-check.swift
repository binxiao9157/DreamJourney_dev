import Foundation

let root = URL(fileURLWithPath: CommandLine.arguments.dropFirst().first ?? FileManager.default.currentDirectoryPath)

func read(_ relativePath: String) throws -> String {
    try String(contentsOf: root.appendingPathComponent(relativePath), encoding: .utf8)
}

func require(_ condition: @autoclosure () -> Bool, _ message: String) {
    guard condition() else {
        fputs("Digital human mode management check failed: \(message)\n", stderr)
        exit(1)
    }
}

let model = try read("DreamJourney/Sources/Services/MemoryModel.swift")
let repository = try read("DreamJourney/Sources/Services/FamilyRepository.swift")
let family = try read("DreamJourney/Sources/Modules/Family/FamilyCircleViewController.swift")
let profile = try read("DreamJourney/Sources/Modules/Profile/ProfileViewController.swift")

require(model.contains("var digitalHumanMode: DigitalHumanMode"), "FamilyMember must persist a digital-human mode")
require(model.contains("digitalHumanMode: DigitalHumanMode = .sunlight"), "FamilyMember should default to sunlight, not star")

require(repository.contains("func updateMode(memberId: String, mode: DigitalHumanMode)"), "FamilyRepository must expose mode updates")
require(repository.contains("persistModeOverrides()"), "FamilyRepository must persist hidden mode changes")
require(repository.contains("loadModeOverrides()"), "FamilyRepository must load persisted hidden mode changes")
require(repository.contains("applyModeOverride(to:"), "FamilyRepository must apply mode overrides to seeded and KB members")

require(family.contains("modeLabel"), "Family member cell should show the hidden QA mode state")
require(family.contains("contextMenuConfigurationForRowAt"), "Family list should expose a hidden context menu for mode changes")
require(family.contains("setMode("), "FamilyCircleViewController must update selected member mode")
require(family.contains("mode: member.digitalHumanMode"), "Selecting a family persona must use its stored mode")
require(!family.contains("mode: .star"), "Family persona selection must not force every family member into star mode")

require(profile.contains("context.mode == .star"), "Care dashboard must still be limited to star family personas")

print("Digital human mode management checks passed")

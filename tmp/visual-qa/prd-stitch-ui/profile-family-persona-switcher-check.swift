import Foundation

let rootPath = CommandLine.arguments.dropFirst().first ?? FileManager.default.currentDirectoryPath
let rootURL = URL(fileURLWithPath: rootPath)

func read(_ relativePath: String) -> String {
    let url = rootURL.appendingPathComponent(relativePath)
    do {
        return try String(contentsOf: url, encoding: .utf8)
    } catch {
        fatalError("Unable to read \(relativePath): \(error)")
    }
}

func assertContains(_ source: String, _ needle: String, _ message: String) {
    guard source.contains(needle) else {
        fatalError("\(message): missing \(needle)")
    }
}

func assertNotContains(_ source: String, _ needle: String, _ message: String) {
    guard !source.contains(needle) else {
        fatalError("\(message): unexpected \(needle)")
    }
}

func extractDefaultEnabledFeatures(from flags: String) -> Set<String> {
    let marker = "private static let defaultEnabled: Set<DJFeature> = ["
    guard let start = flags.range(of: marker)?.upperBound,
          let end = flags[start...].range(of: "]")?.lowerBound else {
        fatalError("Unable to find FeatureFlagService.defaultEnabled")
    }

    let body = flags[start..<end]
    let regex = try! NSRegularExpression(pattern: "\\.([A-Za-z0-9_]+)")
    let range = NSRange(body.startIndex..<body.endIndex, in: body)
    return Set(regex.matches(in: String(body), range: range).compactMap { match in
        guard let valueRange = Range(match.range(at: 1), in: body) else { return nil }
        return String(body[valueRange])
    })
}

let flags = read("DreamJourney/Sources/App/FeatureFlagService.swift")
let profile = read("DreamJourney/Sources/Modules/Profile/ProfileViewController.swift")
let profileReadiness = read("DreamJourney/Sources/Modules/Profile/ProfileFamilyPersonaReleaseReadiness.swift")
let family = read("DreamJourney/Sources/Modules/Family/FamilyCircleViewController.swift")
let contextStore = read("DreamJourney/Sources/App/DigitalHumanContextStore.swift")
let repository = read("DreamJourney/Sources/Services/FamilyRepository.swift")
let model = read("DreamJourney/Sources/Services/MemoryModel.swift")
let releaseMatrix = read("docs/superpowers/status/2026-06-17-release-feature-matrix.md")

let defaults = extractDefaultEnabledFeatures(from: flags)
for hidden in ["familyManagement", "familySpace", "accountDeletion", "careDoctorContact"] {
    guard !defaults.contains(hidden) else {
        fatalError("\(hidden) must stay hidden by default")
    }
}

assertContains(profileReadiness, "DJEnableProfileHiddenBranches", "profile hidden branches should require explicit UIQA launch argument")
assertContains(profile, "ProfileFamilyPersonaReleaseReadiness.hiddenBranchesLaunchArgument", "profile should read hidden branches from the release readiness contract")
assertContains(profile, "ProfileFamilyPersonaReleaseReadiness.isFamilyManagementRowVisible", "family row should use the release readiness visibility contract")
assertContains(profile, "ProfileFamilyPersonaReleaseReadiness.canOpenFamilyPersonaSwitcher", "family route should use the release readiness route contract")
assertContains(profile, "featureFlags.isEnabled(.familyManagement)", "family row should stay feature-gated")
assertContains(profile, "featureFlags.isEnabled(.familySpace)", "family route should stay behind familySpace")
assertContains(profile, "ProfileFamilyPersonaReleaseReadiness.unavailableTitle", "family route should retain safe unavailable title through the release readiness contract")
assertContains(profileReadiness, "家人管理暂未开放", "family release readiness contract should retain safe unavailable copy")
assertContains(profile, ".djDigitalHumanContextDidChange", "profile should observe selected persona changes")
assertContains(profile, "makePersonaTitle(context:", "profile should derive persona title from context")
assertContains(profile, "makePersonaSubtitle(context:", "profile should derive persona subtitle from context")
assertContains(profile, "\"外面世界很美好\"", "default self profile title should keep Stitch visual copy")
assertContains(profile, "\"今天又是阳光灿烂的一天\"", "default self profile subtitle should keep Stitch visual copy")

assertContains(family, "private enum FamilyPersonaOption", "family page should expose explicit persona options")
assertContains(family, "case selfAssistant", "family page should include self assistant option")
assertContains(family, "case familyMember(FamilyMember)", "family page should include family member option")
assertContains(family, "FamilyRepository.shared.getAll()", "family page should use FamilyRepository data")
assertContains(family, "DigitalHumanContext.defaultContext(userId:", "self option should restore default digital-human context")
assertContains(family, "DigitalHumanContextStore.shared.current =", "family page should write selected digital-human context")
assertContains(family, "viewerUserId: user.id", "family context should preserve viewer user id")
assertContains(family, "ownerId: member.id", "family context should scope owner id to the selected member")
assertContains(family, "displayName: member.name", "family context should use member display name")
assertContains(family, "relation: member.relation", "family context should persist relation")
assertContains(family, "mode: member.digitalHumanMode", "family persona should use the member's stored digital-human mode")
assertNotContains(family, "mode: .star", "family persona must not force every family member into star mode")
assertContains(family, "isSelfAssistant: false", "family persona should not be marked as self assistant")
assertContains(family, "selectPersona(option:", "family table selection should call persona selection")
assertContains(family, "accessibilityIdentifier = \"familyPersonaOption", "family options should be inspectable in UIQA")
assertContains(family, "contextMenuConfigurationForRowAt", "family options should expose hidden mode management through a context menu")
assertContains(family, "setMode(", "family options should update persisted mode without exposing a release entry")
assertNotContains(family, "查看 \\(member.name) 的足迹", "old family row tap should not remain as the primary action")

assertContains(contextStore, "NotificationCenter.default.post(name: .djDigitalHumanContextDidChange", "context store should notify persona changes")
assertContains(repository, "func getAll() -> [FamilyMember]", "family repository should expose members")
assertContains(repository, "func updateMode(memberId: String, mode: DigitalHumanMode)", "family repository should persist mode changes")
assertContains(model, "digitalHumanMode: DigitalHumanMode = .sunlight", "family members should default to sunlight mode")

assertContains(releaseMatrix, "家人管理", "release matrix should document family management")
assertContains(releaseMatrix, "familyManagement", "release matrix should document familyManagement gate")
assertContains(releaseMatrix, "familySpace", "release matrix should document familySpace gate")

print("Profile family persona switcher checks passed")

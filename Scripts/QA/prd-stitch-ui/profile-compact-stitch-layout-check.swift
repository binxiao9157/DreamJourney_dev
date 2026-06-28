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

let profile = read("DreamJourney/Sources/Modules/Profile/ProfileViewController.swift")

assertContains(profile, "private enum ProfileLayout", "profile should centralize Stitch layout constants")
assertContains(profile, "static let contentTopMargin: CGFloat = 18", "profile top rhythm should be closer to Stitch")
assertContains(profile, "static let contentStackSpacing: CGFloat = 16", "profile stack spacing should be compact")
assertContains(profile, "static let afterPersonaSpacing: CGFloat = 16", "profile persona-to-card spacing should be compact")
assertContains(profile, "static let personaAvatarSize: CGFloat = 56", "profile avatar should match Stitch compact avatar scale")
assertContains(profile, "static let personaTitleFontSize: CGFloat = 18", "profile title should not overpower Stitch card hierarchy")
assertContains(profile, "static let careCardPadding: CGFloat = 16", "care card should use Stitch-like internal padding")
assertContains(profile, "static let careSignalHeight: CGFloat = 44", "care signal wave should be compact")
assertContains(profile, "static let settingsRowMinHeight: CGFloat = 56", "settings rows should remain compact but tappable")

assertContains(profile, "contentStack.spacing = ProfileLayout.contentStackSpacing", "profile stack should use centralized spacing")
assertContains(profile, "top: ProfileLayout.contentTopMargin", "profile top inset should use centralized spacing")
assertContains(profile, "contentStack.setCustomSpacing(ProfileLayout.afterPersonaSpacing, after: personaView)", "profile persona spacing should be centralized")
assertContains(profile, "avatarContainer.layer.cornerRadius = ProfileLayout.personaAvatarSize / 2", "avatar radius should follow avatar size")
assertContains(profile, "avatarContainer.widthAnchor.constraint(equalToConstant: ProfileLayout.personaAvatarSize)", "avatar width should use compact token")
assertContains(profile, "DJDesignTokens.Font.title(ProfileLayout.personaTitleFontSize)", "persona title should use compact token")
assertContains(profile, "ProfileSignalBarView(value: snapshot?.emotionalIndex ?? 0.8, height: ProfileLayout.careSignalHeight)", "care signal should use compact height")
assertContains(profile, "heightAnchor.constraint(greaterThanOrEqualToConstant: ProfileLayout.settingsRowMinHeight)", "settings row height should use compact token")

print("Profile compact Stitch layout checks passed")

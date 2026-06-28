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

let archive = read("DreamJourney/Sources/Modules/Archive/MemoryArchiveViewController.swift")
let detail = read("DreamJourney/Sources/Modules/Archive/MemoryArchiveDetailViewController.swift")

assertContains(archive, "static let timelineCardRadius: CGFloat = DJDesignTokens.Radius.extraLarge", "archive timeline cards should use Stitch large card radius")
assertContains(archive, "static let timelineCardInset: CGFloat = 18", "archive timeline cards should use explicit content inset")
assertContains(archive, "static let timelineMediaHeight: CGFloat = 132", "archive photo timeline card media height should stay close to Stitch")
assertContains(archive, "static let timelineAudioPlayerHeight: CGFloat = 44", "archive audio timeline player should match Stitch compact player")
assertContains(archive, "private func makeArchiveTimelineCard(_ item: MemoryArchiveItem) -> UIView", "archive real items should route through Stitch timeline card builder")
assertContains(archive, "private func makePhotoTimelineCard(", "archive photo items should render as media timeline cards")
assertContains(archive, "private func makeAudioTimelineCard(", "archive audio items should render as audio timeline cards")
assertContains(archive, "listStack.addArrangedSubview(makeArchiveTimelineCard(item))", "archive list should use Stitch timeline cards for real items")
assertContains(archive, "imageContainer.heightAnchor.constraint(equalToConstant: ArchiveLayout.timelineMediaHeight)", "archive photo timeline media height should be centralized")
assertContains(archive, "playerView.heightAnchor.constraint(equalToConstant: ArchiveLayout.timelineAudioPlayerHeight)", "archive audio timeline player height should be centralized")

assertContains(detail, "private enum ArchiveDetailLayout", "archive detail should centralize Stitch-sensitive layout constants")
assertContains(detail, "static let contentTopMargin: CGFloat = 12", "archive detail top spacing should be explicit")
assertContains(detail, "static let contentStackSpacing: CGFloat = 16", "archive detail stack rhythm should stay compact")
assertContains(detail, "static let cardInset: CGFloat = 18", "archive detail card inset should be explicit")
assertContains(detail, "static let headerIconSize: CGFloat = 44", "archive detail header icon should be compact")
assertContains(detail, "contentStack.spacing = ArchiveDetailLayout.contentStackSpacing", "archive detail stack should use layout constants")
assertContains(detail, "top: ArchiveDetailLayout.contentTopMargin", "archive detail top margin should use layout constants")
assertContains(detail, "stack.topAnchor.constraint(equalTo: card.topAnchor, constant: ArchiveDetailLayout.cardInset)", "archive detail cards should use centralized inset")
assertContains(detail, "iconContainer.widthAnchor.constraint(equalToConstant: ArchiveDetailLayout.headerIconSize)", "archive detail header icon size should be centralized")

print("Archive timeline/detail Stitch checks passed")

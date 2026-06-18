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
let sheet = read("DreamJourney/Sources/Modules/Archive/MemoryArchiveCreationSheetViewController.swift")

assertContains(archive, "private enum ArchiveLayout", "archive should centralize Stitch layout constants")
assertContains(archive, "static let contentTopMargin: CGFloat = 8", "archive content should start close to Stitch pt-unit")
assertContains(archive, "static let contentStackSpacing: CGFloat = 18", "archive stack rhythm should stay compact")
assertContains(archive, "static let headerStackSpacing: CGFloat = 6", "archive header title/subtitle rhythm should stay compact")
assertContains(archive, "static let headerTitleFontSize: CGFloat = 32", "archive title should stay close to Stitch scale")
assertContains(archive, "static let headerSubtitleFontSize: CGFloat = 14", "archive subtitle should stay quieter than hero copy")
assertContains(archive, "static let afterHeaderSpacing: CGFloat = 24", "archive header-to-bento rhythm should be explicit")
assertContains(archive, "static let featureGridHeight: CGFloat = 140", "archive bento height should match Stitch")
assertContains(archive, "static let featureGridGap: CGFloat = 16", "archive bento gap should match Stitch")
assertContains(archive, "static let primaryCTAHeight: CGFloat = 120", "archive CTA height should match Stitch")
assertContains(archive, "static let timelineItemSpacing: CGFloat = 18", "archive timeline cards should breathe without drifting")
assertContains(archive, "mainStack.spacing = ArchiveLayout.contentStackSpacing", "archive stack should use layout constants")
assertContains(archive, "stack.spacing = ArchiveLayout.headerStackSpacing", "archive header stack should use layout constants")
assertContains(archive, "titleLabel.font = DJDesignTokens.Font.display(ArchiveLayout.headerTitleFontSize)", "archive title font should be centralized")
assertContains(archive, "subtitleLabel.font = DJDesignTokens.Font.body(ArchiveLayout.headerSubtitleFontSize)", "archive subtitle font should be centralized")
assertContains(archive, "top: ArchiveLayout.contentTopMargin", "archive top margin should use layout constants")
assertContains(archive, "mainStack.setCustomSpacing(ArchiveLayout.afterHeaderSpacing, after: header)", "archive header spacing should be centralized")
assertContains(archive, "photoCard.heightAnchor.constraint(equalToConstant: ArchiveLayout.featureGridHeight)", "archive feature grid height should be centralized")
assertContains(archive, "grid.spacing = ArchiveLayout.featureGridGap", "archive grid gap should be centralized")
assertContains(archive, "control.heightAnchor.constraint(equalToConstant: ArchiveLayout.primaryCTAHeight)", "archive CTA height should be centralized")
assertContains(archive, "listStack.spacing = ArchiveLayout.timelineItemSpacing", "archive timeline spacing should be centralized")

assertContains(sheet, "private enum ArchiveCreationSheetLayout", "creation sheet should centralize Stitch layout constants")
assertContains(sheet, "static let titleFontSize: CGFloat = 28", "creation sheet title should be lighter than full screen display")
assertContains(sheet, "static let contentTopMargin: CGFloat = 24", "creation sheet top margin should stay compact")
assertContains(sheet, "static let optionMinHeight: CGFloat = 76", "creation sheet rows should be compact but tappable")
assertContains(sheet, "static let optionIconSize: CGFloat = 40", "creation sheet icon container should be compact")
assertContains(sheet, "titleLabel.font = DJDesignTokens.Font.display(ArchiveCreationSheetLayout.titleFontSize)", "sheet title should use layout token")
assertContains(sheet, "stackView.spacing = ArchiveCreationSheetLayout.optionSpacing", "sheet option spacing should be centralized")
assertContains(sheet, "heightAnchor.constraint(greaterThanOrEqualToConstant: ArchiveCreationSheetLayout.optionMinHeight)", "sheet option height should be centralized")

print("Archive compact Stitch layout checks passed")

import Foundation

let sourcePath = "DreamJourney/Sources/Modules/Archive/MemoryArchiveDetailViewController.swift"
let source = try String(contentsOfFile: sourcePath, encoding: .utf8)

func assertContains(_ needle: String, _ message: String) {
    guard source.contains(needle) else {
        fatalError("\(message): missing \(needle)")
    }
}

assertContains(
    "private static let stitchDetailBottomRhythm: CGFloat = 120",
    "Stitch detail bottom rhythm constant"
)
assertContains(
    "private static func detailBottomInset(safeAreaBottomInset: CGFloat) -> CGFloat",
    "detail bottom inset calculator"
)
assertContains(
    "max(stitchDetailBottomRhythm, DJDesignTokens.Spacing.section + safeAreaBottomInset)",
    "detail bottom inset formula"
)
assertContains(
    "scrollView.contentInsetAdjustmentBehavior = .never",
    "deterministic detail scroll inset adjustment"
)
assertContains(
    "override func viewDidLayoutSubviews()",
    "detail layout refresh hook"
)
assertContains(
    "updateDetailScrollInsets()",
    "detail scroll inset refresh call"
)

import Foundation

let sourcePath = "DreamJourney/Sources/Modules/Archive/MemoryArchiveViewController.swift"
let source = try String(contentsOfFile: sourcePath, encoding: .utf8)

func assertContains(_ needle: String, _ message: String) {
    guard source.contains(needle) else {
        fatalError("\(message): missing \(needle)")
    }
}

assertContains(
    "private static let warmTabBarFloatingBottomInset: CGFloat = 16",
    "floating tab bar bottom gap constant"
)
assertContains(
    "private static func archiveListBottomInset(safeAreaBottomInset: CGFloat) -> CGFloat",
    "archive list bottom inset calculator"
)
assertContains(
    "DJDesignTokens.Spacing.tabBarHeight + warmTabBarFloatingBottomInset + safeAreaBottomInset + DJDesignTokens.Spacing.page",
    "archive list inset formula"
)
assertContains(
    "scrollView.contentInsetAdjustmentBehavior = .never",
    "deterministic scroll inset adjustment"
)
assertContains(
    "override func viewDidLayoutSubviews()",
    "layout refresh hook"
)
assertContains(
    "updateArchiveListScrollInsets()",
    "scroll inset refresh call"
)

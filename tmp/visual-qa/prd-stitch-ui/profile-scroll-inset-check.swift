import Foundation

let root = CommandLine.arguments.dropFirst().first ?? FileManager.default.currentDirectoryPath
let profilePath = "\(root)/DreamJourney/Sources/Modules/Profile/ProfileViewController.swift"

guard let source = try? String(contentsOfFile: profilePath, encoding: .utf8) else {
    fputs("Unable to read ProfileViewController.swift\n", stderr)
    exit(1)
}

let requiredSnippets = [
    "private static let warmTabBarFloatingBottomInset: CGFloat = 16",
    "private static func profileScrollBottomInset(safeAreaBottomInset: CGFloat) -> CGFloat",
    "DJDesignTokens.Spacing.tabBarHeight + warmTabBarFloatingBottomInset + safeAreaBottomInset + DJDesignTokens.Spacing.page",
    "override func viewDidLayoutSubviews()",
    "updateProfileScrollInsets()",
    "scrollView.contentInsetAdjustmentBehavior = .never",
    "scrollView.contentInset.bottom = bottomInset",
    "scrollView.verticalScrollIndicatorInsets.bottom = bottomInset",
]

let missing = requiredSnippets.filter { !source.contains($0) }
if !missing.isEmpty {
    fputs("Profile scroll inset guard failed. Missing:\n", stderr)
    missing.forEach { fputs("- \($0)\n", stderr) }
    exit(1)
}

if source.contains("additionalSafeAreaInsets = UIEdgeInsets(") {
    fputs("Profile scroll inset guard failed: ProfileViewController should not rely on additionalSafeAreaInsets for the floating tabbar.\n", stderr)
    exit(1)
}

print("Profile scroll inset checks passed")

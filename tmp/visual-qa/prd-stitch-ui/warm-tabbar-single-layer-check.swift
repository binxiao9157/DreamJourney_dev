import Foundation

let root = CommandLine.arguments.dropFirst().first ?? FileManager.default.currentDirectoryPath
let path = "\(root)/DreamJourney/Sources/TabBar/WarmTabBarController.swift"

guard let tabbar = try? String(contentsOfFile: path, encoding: .utf8) else {
    fatalError("Unable to read \(path)")
}

func assertContains(_ haystack: String, _ needle: String, _ message: String) {
    guard haystack.contains(needle) else {
        fatalError("\(message): missing \(needle)")
    }
}

func assertNotContains(_ haystack: String, _ needle: String, _ message: String) {
    guard !haystack.contains(needle) else {
        fatalError("\(message): unexpected \(needle)")
    }
}

assertNotContains(tabbar, "warmTabBar.safeBottom =", "tab bar layout must not feed unused safe-bottom state back into the view")
assertNotContains(tabbar, "var safeBottom: CGFloat", "tab bar view should not keep unused safe-bottom layout state")
assertNotContains(tabbar, "shadowRadius = 40", "tab bar shadow must not read as a second bottom navigation layer")
assertNotContains(tabbar, "shadowOffset = CGSize(width: 0, height: -10)", "tab bar shadow must not create a lifted duplicate underneath the bar")

assertContains(tabbar, "private func updateShadowPath()", "tab bar should pin shadow geometry to the visible pill")
assertContains(
    tabbar,
    "layer.shadowPath = UIBezierPath(roundedRect: bounds, cornerRadius: Self.tabBarHeight / 2).cgPath",
    "tab bar shadow path should match the visible single pill"
)
assertContains(tabbar, "layer.shadowOpacity = 0.055", "tab bar shadow should remain subtle")
assertContains(tabbar, "layer.shadowRadius = 14", "tab bar shadow should stay compact")

assertContains(tabbar, "private func suppressSystemTabBar()", "custom shell should actively suppress the system UITabBar")
assertContains(tabbar, "tabBar.alpha = 0", "system UITabBar must not render below the custom bar")
assertContains(tabbar, "tabBar.isUserInteractionEnabled = false", "system UITabBar must not receive touches")
assertContains(tabbar, "tabBar.accessibilityElementsHidden = true", "system UITabBar tabs must not remain in the accessibility tree")
assertContains(tabbar, "tabBar.subviews.forEach", "system UITabBar child layers should be hidden as a defensive measure")

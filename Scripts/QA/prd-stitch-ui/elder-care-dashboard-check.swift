import Foundation

let root = URL(fileURLWithPath: CommandLine.arguments.dropFirst().first ?? FileManager.default.currentDirectoryPath)

func read(_ relativePath: String) throws -> String {
    let url = root.appendingPathComponent(relativePath)
    return try String(contentsOf: url, encoding: .utf8)
}

func require(_ condition: @autoclosure () -> Bool, _ message: String) {
    guard condition() else {
        fputs("Elder care dashboard check failed: \(message)\n", stderr)
        exit(1)
    }
}

let dashboardPath = "DreamJourney/Sources/Modules/Profile/ProfileElderCareDashboardViewController.swift"
let dashboardURL = root.appendingPathComponent(dashboardPath)
require(FileManager.default.fileExists(atPath: dashboardURL.path), "missing \(dashboardPath)")

let dashboard = try read(dashboardPath)
let profile = try read("DreamJourney/Sources/Modules/Profile/ProfileViewController.swift")
let project = try read("DreamJourney.xcodeproj/project.pbxproj")

require(dashboard.contains("final class ProfileElderCareDashboardViewController"), "dashboard view controller class is missing")
require(dashboard.contains("accessibilityIdentifier = \"elderCareDashboard\""), "dashboard root accessibility id is missing")
require(dashboard.contains("ProfileCareSnapshot"), "dashboard must consume existing ProfileCareSnapshot")
require(dashboard.contains("DigitalHumanContext"), "dashboard must receive the selected digital-human context")

for text in ["长辈关怀", "情绪指数", "认知指数", "睡眠状态", "孤独指数", "风险提醒"] {
    require(dashboard.contains(text), "dashboard missing visible aggregate field: \(text)")
}

require(dashboard.contains("仅查看结果"), "dashboard must state child view is aggregate-only")
require(dashboard.contains("不查看聊天内容"), "dashboard must state raw chat content is not exposed")
require(!dashboard.contains("= PaddingLabel"), "dashboard must not reference ProfileViewController's private PaddingLabel")

for forbidden in ["conversationTranscript", "rawTranscript", "messageHistory", "chatMessages"] {
    require(!dashboard.contains(forbidden), "dashboard must not expose raw chat data symbol: \(forbidden)")
}

require(profile.contains("showElderCareDashboard"), "ProfileViewController must provide a dashboard navigation action")
require(profile.contains("ProfileElderCareDashboardViewController"), "ProfileViewController must push the dashboard")
require(profile.contains("accessibilityIdentifier = \"profileCareDashboardCard\""), "care card must be discoverable for UI smoke")

require(project.contains("ProfileElderCareDashboardViewController.swift"), "dashboard file is not in the Xcode project")
require(project.contains("ProfileElderCareDashboardViewController.swift in Sources"), "dashboard file is not in the app target sources")

print("Elder care dashboard checks passed")

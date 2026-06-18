import Foundation

let root = URL(fileURLWithPath: CommandLine.arguments.dropFirst().first ?? FileManager.default.currentDirectoryPath)

func read(_ relativePath: String) -> String {
    let url = root.appendingPathComponent(relativePath)
    guard let content = try? String(contentsOf: url, encoding: .utf8) else {
        fatalError("Unable to read \(url.path)")
    }
    return content
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

let careModels = read("DreamJourney/Sources/Modules/Profile/ProfileCareModels.swift")
let profile = read("DreamJourney/Sources/Modules/Profile/ProfileViewController.swift")
let careDashboard = read("DreamJourney/Sources/Modules/Profile/ProfileElderCareDashboardViewController.swift")
let releaseRegression = read("tmp/visual-qa/prd-stitch-ui/run-release-regression.sh")
let releaseQA = read("tmp/visual-qa/prd-stitch-ui/release-qa-package-check.swift")

assertContains(careModels, "enum ProfileCareDataState", "Care dashboard should model data states")
assertContains(careModels, "case loading", "Care dashboard should support loading")
assertContains(careModels, "case empty", "Care dashboard should support empty")
assertContains(careModels, "case stale", "Care dashboard should support stale")
assertContains(careModels, "case failed", "Care dashboard should support failed")

for phrase in [
    "正在同步关怀信号",
    "暂无可用关怀信号",
    "数据可能不是最新",
    "关怀信号加载失败",
] {
    assertContains(careModels, phrase, "Care data state copy should include \(phrase)")
    assertContains(careDashboard, phrase, "Care dashboard should render \(phrase)")
}

assertContains(profile, "ProfileCareSnapshot.loadingPlaceholder()", "Profile should show an explicit loading state")
assertContains(profile, "ProfileCareSnapshot.emptyFallback()", "Profile should show an explicit empty state")
assertContains(profile, "ProfileCareSnapshot.failedFallback()", "Profile should show an explicit failed state")
assertContains(profile, "ProfileCareSnapshot.staleFallback()", "Profile should show an explicit stale state")
assertContains(careDashboard, "makeDataStateCard", "Care dashboard should expose state-specific public copy")
assertContains(careDashboard, "关怀升级准备中", "Care dashboard should expose MVP placeholder")
assertContains(careDashboard, "不会拨打电话或发送消息", "Placeholder must not imply real intervention")
assertNotContains(careDashboard, "立即通话", "Public care state placeholder must not expose direct call")
assertNotContains(careDashboard, "tel://", "Public care placeholder must not dial")
assertNotContains(careDashboard, "sms://", "Public care placeholder must not send messages")
assertNotContains(careDashboard, "DreamJourneyBackendClient", "Public care placeholder must not submit backend escalation")
assertNotContains(careDashboard, "submitCareEscalation", "Public care placeholder must not submit escalation")

assertContains(releaseRegression, "profile-care-public-placeholder-check.swift", "Release regression should run care public placeholder guard")
assertContains(releaseQA, "profile-care-public-placeholder-check.swift", "Release QA package should include care public placeholder guard")

print("Profile care public placeholder checks passed")

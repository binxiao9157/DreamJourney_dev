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

let featureFlags = read("DreamJourney/Sources/App/FeatureFlagService.swift")
let echo = read("DreamJourney/Sources/Modules/Echo/EchoViewController.swift")
let appDelegate = read("DreamJourney/Sources/AppDelegate.swift")
let project = read("DreamJourney.xcodeproj/project.pbxproj")
let webHTML = read("DreamJourney/Resources/web/DigitalHumanLive.html")

assertContains(featureFlags, "case digitalHumanLivePanel", "Digital human live panel should have an explicit feature flag")
assertNotContains(
    featureFlags,
    ".digitalHumanLivePanel,\n    ]",
    "Digital human live panel must not be default-enabled"
)

assertContains(echo, "DigitalHumanLivePanelView", "Echo should own the live panel view")
assertContains(echo, "DJShowDigitalHumanLivePanel", "Echo should gate the panel behind QA launch argument")
assertContains(echo, "DJRunDigitalHumanLivePanelSmoke", "Echo should support smoke launch argument")
assertContains(echo, "FeatureFlagService.shared.isEnabled(.digitalHumanLivePanel)", "Echo should require the feature flag")
assertContains(echo, "runUIQADigitalHumanLivePanelSmoke", "Echo should expose UIQA smoke driver")
assertContains(echo, "setInteractionState", "Echo should forward state to digital human panel")
assertContains(echo, "startSimulatedAudioLevels", "Echo smoke should drive simulated mouth amplitude")
assertContains(echo, "stopSimulatedAudioLevels", "Echo should stop simulated mouth amplitude")

assertContains(appDelegate, "DJRunDigitalHumanLivePanelSmoke", "AppDelegate should wire the smoke launch argument")
assertContains(appDelegate, "FeatureFlagService.shared.set(.digitalHumanLivePanel, enabled: true)", "Smoke should enable flag only in QA path")
assertContains(appDelegate, "runDigitalHumanLivePanelSmoke", "AppDelegate should run the digital human smoke")

assertContains(project, "DigitalHumanLive.html in Resources", "Digital human HTML wrapper should be bundled")
assertContains(project, "DigitalHumanLivePanelView.swift", "Digital human panel Swift source should be in target")

assertContains(webHTML, "window.DreamJourneyDigitalHuman", "HTML wrapper should expose a stable bridge")
assertContains(webHTML, "setState", "HTML bridge should accept state")
assertContains(webHTML, "setAudioLevel", "HTML bridge should accept audio level")
assertContains(webHTML, "snapshot", "HTML bridge should expose snapshot")
assertContains(webHTML, "MiniLive2.js", "HTML wrapper should load existing renderer script")
assertContains(webHTML, "DHLiveMini.js", "HTML wrapper should load existing wasm loader script")

print("Digital human live panel checks passed")

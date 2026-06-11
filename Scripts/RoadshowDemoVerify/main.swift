import Foundation

private func assertCondition(_ condition: @autoclosure () -> Bool, _ message: String) {
    guard condition() else {
        fputs("FAIL: \(message)\n", stderr)
        exit(1)
    }
}

private func allStrings(in package: RoadshowDemoSeed.Package) -> [String] {
    var values: [String] = []
    values += package.members.flatMap { [$0.id, $0.displayName, $0.relation] }
    values += package.transcript.flatMap { [$0.role, $0.text] }
    values += package.demoItems.flatMap { [$0.id, $0.stepID, $0.title, $0.body] }
    values += package.demoSteps.map(\.rawValue)
    values += package.boundaryNotices
    return values
}

let now = Date(timeIntervalSince1970: 1_800_000_600)
let package = RoadshowDemoSeed.makePackage(now: now)
let argConfiguration = RoadshowDemoSeed.launchConfiguration(
    arguments: ["DreamJourney", "--seed-roadshow-demo", "--roadshow-offline-mode"],
    environment: [:]
)
assertCondition(argConfiguration.shouldSeed, "seed launch argument should enable roadshow seeding")
assertCondition(argConfiguration.offlineMode, "offline launch argument should enable roadshow offline mode")
assertCondition(!argConfiguration.shouldReset, "reset should stay off unless explicitly requested")

let envConfiguration = RoadshowDemoSeed.launchConfiguration(
    arguments: ["DreamJourney"],
    environment: [
        "DREAMJOURNEY_SEED": "roadshow_demo",
        "DREAMJOURNEY_ROADSHOW_OFFLINE": "1",
        "DREAMJOURNEY_RESET_DEMO": "1"
    ]
)
assertCondition(envConfiguration.shouldSeed, "seed environment should enable roadshow seeding")
assertCondition(envConfiguration.offlineMode, "offline environment should enable roadshow offline mode")
assertCondition(envConfiguration.shouldReset, "reset environment should enable roadshow reset")

let viewerMemberID = package.selectedMemberIDForVisibility
assertCondition(package.members.count >= 3, "roadshow seed should include at least 3 family members")
assertCondition(
    package.members.contains { $0.id == viewerMemberID },
    "selected-member visibility ID should match a seeded family member"
)

let careTurns = CareDashboardInputPolicy.eligibleInputTurns(
    from: package.transcript,
    viewerFamilyMemberID: viewerMemberID
)
let familyCircleUserTurns = careTurns.filter { $0.role.lowercased() == "user" }
assertCondition(
    familyCircleUserTurns.count >= 3,
    "seed transcript should provide at least 3 eligible familyCircle user turns"
)

let snapshot = CareSignalAnalyzer().analyze(turns: careTurns, now: now)
assertCondition(
    snapshot.riskLevel == .watch
        || snapshot.riskLevel == .attention
        || snapshot.riskLevel != .insufficientData,
    "care dashboard seed should generate watch/attention or at least non-insufficient snapshot"
)

let expectedSteps: Set<RoadshowDemoSeed.DemoStepID> = [
    .timeMailbox,
    .memoryArchive,
    .voiceCompanion,
    .careDashboard,
    .familySharing
]
assertCondition(
    expectedSteps.isSubset(of: Set(package.demoSteps)),
    "seed should include all required roadshow demo step identifiers"
)

for stepID in expectedSteps {
    assertCondition(
        package.demoItems.contains { $0.stepID == stepID.rawValue },
        "seed should include demo item data for \(stepID.rawValue)"
    )
}

let boundaryText = package.boundaryNotices.joined(separator: "\n")
assertCondition(boundaryText.contains("不是复活"), "boundary copy should state not resurrection")
assertCondition(
    boundaryText.contains("不是医疗诊断") || boundaryText.contains("不能替代医疗诊断"),
    "boundary copy should state not a medical diagnosis"
)
assertCondition(boundaryText.contains("脱敏信号"), "boundary copy should explain sanitized signals")

let externalAPIPhrases = [
    "http://",
    "https://",
    "API key",
    "api key",
    "OpenAI",
    "DeepSeek",
    "联网",
    "网络请求",
    "外部接口",
    "远端生成"
]
for text in allStrings(in: package) {
    for phrase in externalAPIPhrases {
        assertCondition(
            !text.contains(phrase),
            "seed text should not require external API phrase \(phrase): \(text)"
        )
    }
}

assertCondition(
    package.demoItems.contains { $0.stepID == RoadshowDemoSeed.DemoStepID.familySharing.rawValue && $0.body.contains("分享包") },
    "seed should include minimum viable family sharing package copy"
)
assertCondition(
    package.demoItems.contains { $0.body.contains("KBLite") || $0.title.contains("KBLite") },
    "seed should include minimum viable KBLite data"
)

print("RoadshowDemoSeed verification passed")

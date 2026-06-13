import Foundation

private func assertCondition(_ condition: @autoclosure () -> Bool, _ message: String) {
    guard condition() else {
        fputs("RoadshowRoute verification failed: \(message)\n", stderr)
        exit(1)
    }
}

let steps = RoadshowDemoRoute.steps()
assertCondition(steps.count == 6, "route should contain six host-facing phases")

let expectedIDs: Set<String> = [
    "voice_companion",
    "time_mailbox",
    "memory_archive",
    "family_footprint",
    "care_dashboard",
    "family_share"
]
assertCondition(Set(steps.map(\.id)) == expectedIDs, "route should cover phase1 core flows")

for step in steps {
    assertCondition(!step.title.isEmpty, "step title should not be empty")
    assertCondition(!step.tabTitle.isEmpty, "step tab title should not be empty")
    assertCondition(!step.talkingPoint.isEmpty, "step talking point should not be empty")
    assertCondition(!step.acceptance.isEmpty, "step acceptance should not be empty")
    assertCondition(!step.fallback.isEmpty, "step fallback should not be empty")
    assertCondition(!step.iconName.isEmpty, "step icon should not be empty")
    assertCondition(step.evidenceFile.hasPrefix("screens/"), "step evidence file should point to expected screenshots directory")
    assertCondition(step.evidenceFile.hasSuffix(".png"), "step evidence file should be a stable screenshot name")
}

let allCopy = steps
    .flatMap { [$0.title, $0.talkingPoint, $0.acceptance, $0.fallback] }
    .joined(separator: "\n")

for phrase in ["不做诊断", "不是逝者真实回复", "不展示完整原文", "点亮", "分享包"] {
    assertCondition(allCopy.contains(phrase), "route should include phase1 boundary phrase: \(phrase)")
}

let routeNotices = RoadshowDemoRoute.boundaryNotices().joined(separator: "\n")
assertCondition(routeNotices.contains("不是复活"), "boundary notices should state not resurrection")
assertCondition(routeNotices.contains("医疗诊断"), "boundary notices should state not medical diagnosis")
assertCondition(routeNotices.contains("脱敏信号"), "boundary notices should mention sanitized signals")

let evidenceArtifacts = RoadshowDemoRoute.evidenceArtifacts()
assertCondition(evidenceArtifacts.count >= 14, "evidence center should include route screenshots and additional artifacts")
assertCondition(evidenceArtifacts.contains { $0.path == "screens/01_home_banner.png" }, "evidence center should include home banner screenshot")
assertCondition(evidenceArtifacts.contains { $0.path == "screens/02_route_checklist.png" }, "evidence center should include route checklist screenshot")
let evidenceSummary = RoadshowDemoRoute.evidenceClosureSummary()
assertCondition(evidenceSummary.totalCount == evidenceArtifacts.count, "evidence summary should count every artifact")
assertCondition(evidenceSummary.manualEvidenceCount > evidenceSummary.generatedCount, "evidence summary should distinguish manual evidence from generated reports")
assertCondition(evidenceSummary.diagnosticCount == 3, "evidence summary should require copied diagnostics and playback logs")
assertCondition(evidenceSummary.exportCount == 2, "evidence summary should require all-family and selected-member share packages")
assertCondition(evidenceSummary.privacyCount == 1, "evidence summary should require a privacy check log")
assertCondition(evidenceSummary.headline.contains("人工证据"), "evidence summary should produce host-facing headline")
for step in steps {
    assertCondition(
        evidenceArtifacts.contains { $0.path == step.evidenceFile },
        "evidence center should include route step evidence file \(step.evidenceFile)"
    )
}
for path in [
    "recordings/roadshow_6min_run.mp4",
    "share_packages/all_family.json",
    "share_packages/selected_member.json",
    "diagnostics/digital_human_readiness.txt",
    "diagnostics/digital_human_readiness.json",
    "diagnostics/digital_human_playback.log",
    "evidence_status.md"
] {
    assertCondition(evidenceArtifacts.contains { $0.path == path }, "evidence center should include \(path)")
}
let evidenceGuideText = RoadshowDemoRoute.evidenceGuideText()
assertCondition(evidenceGuideText.contains("路演证据中心"), "evidence guide should include title")
assertCondition(evidenceGuideText.contains("screens/01_home_banner.png"), "evidence guide should include home screenshot")
assertCondition(evidenceGuideText.contains("evidence_status.md"), "evidence guide should include evidence status report")
assertCondition(evidenceGuideText.contains("python3 Scripts/roadshow_evidence_report.py"), "evidence guide should include report command")
assertCondition(evidenceGuideText.contains("--archive"), "evidence guide should include final archive command")
assertCondition(evidenceGuideText.contains("archive_inventory.json"), "evidence guide should mention archive inventory checksum")
assertCondition(evidenceGuideText.contains("needs_privacy_review"), "evidence guide should include privacy review status")
assertCondition(evidenceGuideText.contains("不外发 evidence 包"), "evidence guide should block sharing when privacy review is needed")
let checkCommand = RoadshowDemoRoute.evidenceReportCommand()
assertCondition(checkCommand == "python3 Scripts/roadshow_evidence_report.py <evidence-dir> --write --fail-on-missing", "evidence check command should be stable")
let archiveCommand = RoadshowDemoRoute.evidenceArchiveCommand()
assertCondition(archiveCommand == "python3 Scripts/roadshow_evidence_report.py <evidence-dir> --write --archive --fail-on-missing", "evidence archive command should be stable")
let statusGuide = RoadshowDemoRoute.evidenceStatusGuide()
assertCondition(statusGuide.map(\.status).contains("needs_preflight"), "status guide should include preflight state")
assertCondition(statusGuide.map(\.status).contains("needs_privacy_review"), "status guide should include privacy review state")
assertCondition(statusGuide.map(\.status).contains("needs_manual_evidence"), "status guide should include manual evidence state")
assertCondition(statusGuide.map(\.status).contains("complete"), "status guide should include complete state")

let offlineStatus = RoadshowDemoSeed.RuntimeStatus(
    shouldSeed: false,
    shouldReset: false,
    offlineMode: true,
    hasSeededData: true
)
let offlineRecipe = RoadshowDemoRoute.launchRecipe(status: offlineStatus)
assertCondition(offlineRecipe.contains("--roadshow-offline-mode"), "offline route should copy offline launch recipe")
assertCondition(offlineRecipe.contains("--seed-roadshow-demo"), "offline route should seed demo data")

let onlineStatus = RoadshowDemoSeed.RuntimeStatus(
    shouldSeed: true,
    shouldReset: true,
    offlineMode: false,
    hasSeededData: false
)
let onlineRecipe = RoadshowDemoRoute.launchRecipe(status: onlineStatus)
assertCondition(!onlineRecipe.contains("--roadshow-offline-mode"), "online route should not force offline mode")
assertCondition(onlineRecipe.contains("--reset-roadshow-demo"), "online route should include reset for repeatable demo")

for step in steps {
    let key = RoadshowDemoRoute.completionKey(for: step.id)
    assertCondition(key.hasPrefix(RoadshowDemoRoute.completionKeyPrefix), "completion key should use stable prefix")
    assertCondition(key.contains(step.id), "completion key should include step id")
    assertCondition((0...4).contains(step.targetTabIndex), "target tab should point to one of the five primary tabs")
    assertCondition(RoadshowDemoRoute.targetTabIndex(for: step.id) == step.targetTabIndex, "target tab lookup should match step")
}

let expectedTabs: [String: Int] = [
    "voice_companion": 0,
    "family_footprint": 1,
    "care_dashboard": 2,
    "time_mailbox": 3,
    "memory_archive": 4,
    "family_share": 4
]
for (stepID, tabIndex) in expectedTabs {
    assertCondition(RoadshowDemoRoute.targetTabIndex(for: stepID) == tabIndex, "route step \(stepID) should jump to tab \(tabIndex)")
}

let completionDefaults = UserDefaults(suiteName: "RoadshowRouteVerify-\(UUID().uuidString)")!
let emptySummary = RoadshowDemoRoute.completionSummary(userDefaults: completionDefaults)
assertCondition(emptySummary.completedCount == 0, "empty summary should start with zero completed steps")
assertCondition(emptySummary.completionPercent == 0, "empty summary should report 0 percent")
assertCondition(emptySummary.nextStepID == "voice_companion", "empty summary should expose first route step as next step")
assertCondition(emptySummary.primaryActionTitle == "下一步", "empty summary should guide users to the first step")
completionDefaults.set(true, forKey: RoadshowDemoRoute.completionKey(for: "voice_companion"))
completionDefaults.set(true, forKey: RoadshowDemoRoute.completionKey(for: "care_dashboard"))
let completionSummary = RoadshowDemoRoute.completionSummary(userDefaults: completionDefaults)
assertCondition(completionSummary.completedCount == 2, "completion summary should count completed route steps")
assertCondition(completionSummary.totalCount == steps.count, "completion summary should include all route steps")
assertCondition(completionSummary.progressText == "演示进度 2/6", "completion summary should provide stable progress text")
assertCondition(completionSummary.compactProgressText == "2/6", "completion summary should provide compact progress text")
assertCondition(completionSummary.completionPercent == 33, "completion summary should round completion percentage")
assertCondition(completionSummary.nextStepID == "time_mailbox", "completion summary should expose next incomplete step id")
assertCondition(completionSummary.nextStepTitle == "时空信箱边界", "completion summary should expose next incomplete step title")
assertCondition(completionSummary.hostStatusText.contains("下一步：时空信箱边界"), "host status should name next step")
assertCondition(completionSummary.primaryActionTitle == "下一步", "primary action should guide users while steps remain")
assertCondition(
    RoadshowDemoRoute.nextIncompleteStep(userDefaults: completionDefaults)?.id == "time_mailbox",
    "next incomplete step lookup should return first pending route step"
)
let checklistText = RoadshowDemoRoute.completionChecklistText(userDefaults: completionDefaults)
assertCondition(checklistText.contains("路演验收进度 2/6"), "checklist text should include progress header")
assertCondition(checklistText.contains("[x] 语音陪伴与数字人"), "checklist text should mark completed steps")
assertCondition(checklistText.contains("[ ] 时空信箱边界"), "checklist text should mark pending steps")
assertCondition(checklistText.contains("证据：screens/03_memory_voice_digital_human.png"), "checklist text should include step evidence file")
assertCondition(checklistText.contains("证据：screens/07_family_care_dashboard_member.png"), "checklist text should include care dashboard evidence file")
for step in steps {
    completionDefaults.set(true, forKey: RoadshowDemoRoute.completionKey(for: step.id))
}
let completedSummary = RoadshowDemoRoute.completionSummary(userDefaults: completionDefaults)
assertCondition(completedSummary.completedCount == steps.count, "completed summary should count all completed steps")
assertCondition(completedSummary.completionPercent == 100, "completed summary should report 100 percent")
assertCondition(completedSummary.nextStepID == nil, "completed summary should not expose a next step")
assertCondition(completedSummary.hostStatusText.contains("六步闭环已完成"), "completed summary should expose closed-loop status")
assertCondition(completedSummary.primaryActionTitle == "复盘", "primary action should review after all steps complete")
RoadshowDemoRoute.resetCompletions(userDefaults: completionDefaults)
assertCondition(
    RoadshowDemoRoute.completionSummary(userDefaults: completionDefaults).completedCount == 0,
    "completion reset should clear all route step states"
)

print("RoadshowRoute verification passed")

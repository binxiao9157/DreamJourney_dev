#!/usr/bin/env python3
from pathlib import Path
import sys
import re

root = Path(".")
home_vc = (root / "DreamJourney/Sources/Modules/Home/AIRecordingViewController.swift").read_text()
banner = (root / "DreamJourney/Sources/Common/UI/RoadshowModeBannerView.swift").read_text()
route_vc = (root / "DreamJourney/Sources/Modules/Home/RoadshowDemoRouteViewController.swift").read_text()
route = (root / "DreamJourney/Sources/Services/RoadshowDemoRoute.swift").read_text()

checks = [
    (
        "home screen should not own a roadshow banner view in the real testing experience",
        "private let roadshowBannerView = RoadshowModeBannerView()" not in home_vc,
    ),
    (
        "home screen should not mount the roadshow guide layout",
        "roadshowBannerTopConstraint" not in home_vc
        and "roadshowBannerHeightConstraint" not in home_vc,
    ),
    (
        "home screen should not expose roadshow route actions in the main experience",
        "openRoadshowRoute()" not in home_vc
        and "continueRoadshowStep()" not in home_vc,
    ),
    (
        "banner should expose a route checklist button with an accessibility label",
        'config.title = "清单"' in banner and 'accessibilityLabel = "查看演示清单"' in banner,
    ),
    (
        "banner should expose a continue button for one-tap next phase",
        'config.title = "下一步"' in banner
        and 'accessibilityLabel = "进入下一步演示"' in banner
        and "var onContinueTapped: (() -> Void)?" in banner
        and "onContinueTapped?()" in banner,
    ),
    (
        "banner should render route progress and next-step guide status",
        "RoadshowDemoRoute.CompletionSummary" in banner
        and "summary.nextStepTitle" in banner
        and "summary.compactProgressText" in banner
        and "summary.primaryActionTitle" in banner,
    ),
    (
        "banner should protect small-screen readability",
        "adjustsFontSizeToFitWidth = true" in banner
        and "minimumScaleFactor = 0.82" in banner
        and "buttonRow.distribution = .fillEqually" in banner
        and "continueButton.heightAnchor.constraint(equalToConstant: 32)" in banner
        and "routeButton.heightAnchor.constraint(equalToConstant: 32)" in banner,
    ),
    (
        "home presentation guide should hide engineering roadshow copy from the visible banner",
        'titleLabel.text = "演示向导"' in banner
        and "status.title" not in banner
        and "路演模式" not in banner
        and 'detailLabel.text = "下一步：\\(nextTitle)\\n\\(status.userFacingDetail)"' in banner,
    ),
    (
        "home presentation guide actions should use understandable labels when the route view is opened",
        'config.title = "下一步"' in banner
        and 'config.title = "清单"' in banner
        and 'accessibilityLabel = "查看演示清单"' in banner
        and "buttonRow.distribution = .fillEqually" in banner
        and "contentStack.axis = .vertical" in banner,
    ),
    (
        "banner route button should call the controller callback",
        "var onRouteTapped: (() -> Void)?" in banner and "onRouteTapped?()" in banner,
    ),
    (
        "home screen should not wire roadshow continue actions",
        "roadshowBannerView.onContinueTapped" not in home_vc
        and "RoadshowDemoRoute.nextIncompleteStep()" not in home_vc,
    ),
    (
        "home screen should not reopen roadshow route review automatically",
        "guard let step = RoadshowDemoRoute.nextIncompleteStep() else" not in home_vc
        and "openRoadshowRoute()" not in home_vc,
    ),
    (
        "route should keep six phase1 host-facing steps",
        "static func steps() -> [Step]" in route and len(re.findall(r"\bStep\(", route)) == 6,
    ),
    (
        "route cards should expose completion button identifiers from step ids",
        "checkButton.accessibilityIdentifier = step.id" in route_vc,
    ),
    (
        "route completion should persist through stable completion keys",
        "RoadshowDemoRoute.completionKey(for: stepID)" in route_vc
        and "UserDefaults.standard.set(completed" in route_vc,
    ),
    (
        "route progress should show completed count out of all steps",
        "summary.progressText" in route_vc and "summary.hostStatusText" in route_vc,
    ),
    (
        "route progress and evidence command should wrap on small screens",
        "progressLabel.numberOfLines = 0" in route_vc
        and "RoadshowDemoRoute.evidenceReportCommand()" in route_vc
        and "RoadshowDemoRoute.evidenceArchiveCommand()" in route_vc
        and "path.lineBreakMode = .byCharWrapping" in route_vc,
    ),
    (
        "route should expose portable acceptance checklist copy and reset actions",
        "copyAcceptanceChecklist" in route_vc
        and "resetAcceptanceChecklist" in route_vc
        and "RoadshowDemoRoute.completionChecklistText" in route_vc
        and "RoadshowDemoRoute.resetCompletions" in route_vc,
    ),
    (
        "route should expose an in-app evidence center and copy action",
        "makeEvidenceCenterCard()" in route_vc
        and "copyEvidenceGuide" in route_vc
        and "RoadshowDemoRoute.evidenceGuideText" in route_vc
        and "RoadshowDemoRoute.evidenceArtifacts()" in route_vc,
    ),
    (
        "route evidence center should show closure summary and status meanings",
        "RoadshowDemoRoute.evidenceClosureSummary" in route_vc
        and "closureSummary.headline" in route_vc
        and "closureSummary.detail" in route_vc
        and "RoadshowDemoRoute.evidenceStatusGuide()" in route_vc
        and "makeEvidenceStatusRow" in route_vc
        and '"收口状态"' in route_vc,
    ),
    (
        "route model should define stable evidence artifacts and report command",
        "struct EvidenceArtifact" in route
        and "enum Requirement" in route
        and "static func evidenceArtifacts" in route
        and "static func evidenceClosureSummary" in route
        and "static func evidenceStatusGuide" in route
        and "static func evidenceGuideText" in route
        and "static func evidenceReportCommand" in route
        and "static func evidenceArchiveCommand" in route
        and "python3 Scripts/roadshow_evidence_report.py" in route,
    ),
    (
        "route evidence guide should include final archive package command",
        "--archive" in route
        and "archive_inventory.json" in route
        and "归档命令" in route_vc,
    ),
    (
        "route evidence guide should block privacy-review packages from sharing",
        "needs_privacy_review" in route
        and "不外发 evidence 包" in route
        and "token" in route
        and "key" in route
        and "secret" in route,
    ),
    (
        "route cards should expose direct enter actions for each step",
        'enterButton.accessibilityIdentifier = "enter_\\(step.id)"' in route_vc
        and "enterStep(_ sender: UIButton)" in route_vc,
    ),
    (
        "route direct navigation should use targetTabIndex except share export",
        "RoadshowDemoRoute.targetTabIndex(for: stepID)" in route_vc
        and "tabBarController?.selectedIndex = targetIndex" in route_vc
        and 'stepID == "family_share"' in route_vc,
    ),
]

failed = [message for message, passed in checks if not passed]
if failed:
    for message in failed:
        print(f"RoadshowHostRouteUIContract verification failed: {message}", file=sys.stderr)
    sys.exit(1)

print("RoadshowHostRouteUIContract verification passed")

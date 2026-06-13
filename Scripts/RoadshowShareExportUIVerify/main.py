#!/usr/bin/env python3
from pathlib import Path
import sys

root = Path(".")
route_vc = (root / "DreamJourney/Sources/Modules/Home/RoadshowDemoRouteViewController.swift").read_text()
sync_vc = (root / "DreamJourney/Sources/Modules/Knowledge/KBSyncViewController.swift").read_text()
route = (root / "DreamJourney/Sources/Services/RoadshowDemoRoute.swift").read_text()

checks = [
    (
        "roadshow family_share step should keep archive tab as fallback destination",
        '"family_share"' in route and "targetTabIndex: 4" in route,
    ),
    (
        "roadshow route should directly open share export flow",
        'KBSyncViewController(autoPresentExportPicker: true)' in route_vc,
    ),
    (
        "roadshow route should only special-case family_share for direct export",
        'if stepID == "family_share"' in route_vc,
    ),
    (
        "share export should support route-driven auto picker",
        "autoPresentExportPicker" in sync_vc and "didAutoPresentExportPicker" in sync_vc,
    ),
    (
        "share export should keep explicit all-family and member object choices",
        '"全体亲友"' in sync_vc and "forFamilyMemberID: nil" in sync_vc and "member.id" in sync_vc,
    ),
    (
        "share export should still use sanitized share package API",
        "generateSharePackage(forFamilyMemberID: familyMemberID)" in sync_vc,
    ),
    (
        "share export should show a privacy receipt before system share sheet",
        "SharePackagePrivacyReceipt" in sync_vc and "presentPrivacyReceipt" in sync_vc and "presentShareSheet" in sync_vc,
    ),
    (
        "privacy receipt should be a scrollable custom page for small-screen readability",
        "SharePackagePrivacyReceiptViewController" in sync_vc
        and "let scrollView = UIScrollView()" in sync_vc
        and "contentStack.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor)" in sync_vc
        and "messageLabel.numberOfLines = 0" in sync_vc
        and "modalPresentationStyle = .pageSheet" in sync_vc,
    ),
    (
        "privacy receipt should summarize package contents from graph JSON",
        "JSONDecoder().decode(KBLiteGraph.self" in sync_vc and "graph.people.count" in sync_vc,
    ),
    (
        "privacy receipt should explain filtered private and unauthorized content",
        "本机私密内容" in sync_vc and "未授权亲友内容" in sync_vc and "完整对话原文" in sync_vc,
    ),
    (
        "privacy receipt should keep phase1 boundary language",
        "不是复活" in sync_vc and "不是医疗诊断" in sync_vc,
    ),
    (
        "share export should use a JSON activity sheet after receipt confirmation",
        "UIActivityViewController" in sync_vc and '"分享 JSON"' in sync_vc,
    ),
]

failed = [message for message, passed in checks if not passed]
if failed:
    for message in failed:
        print(f"RoadshowShareExportUI verification failed: {message}", file=sys.stderr)
    sys.exit(1)

print("RoadshowShareExportUI verification passed")

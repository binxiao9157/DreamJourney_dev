#!/usr/bin/env python3
from pathlib import Path
import re
import sys

ROOT = Path(__file__).resolve().parents[2]
VC = ROOT / "DreamJourney/Sources/Modules/CareDashboard/CareDashboardViewController.swift"
PHASE1 = ROOT / "Scripts/verify_phase1.sh"


def require(condition: bool, message: str) -> None:
    if not condition:
        print(f"CareDashboardLiveEvidenceUI verification failed: {message}", file=sys.stderr)
        sys.exit(1)


vc = VC.read_text(encoding="utf-8")
phase1 = PHASE1.read_text(encoding="utf-8")

render_match = re.search(r"private func render\(\)[\s\S]*?\n    private func canShareCareReport", vc)
render_body = render_match.group(0) if render_match else ""
status_match = re.search(r"private func makeEvidenceStatusCard\([\s\S]*?\n    private func makeMetricGrid", vc)
status_body = status_match.group(0) if status_match else ""

require("makeEvidenceStatusCard" in vc, "care dashboard should have a persistent live evidence status card")
require(
    "stackView.addArrangedSubview(makeEvidenceStatusCard(snapshot))" in render_body
    and render_body.find("makePrivacyNotice") < render_body.find("makeEvidenceStatusCard"),
    "live evidence status should render for both sufficient and insufficient care snapshots",
)
required_status_fragments = [
    "真实验收状态",
    "本机授权发言 \\(localEligibleUserTurnCount) 轮",
    "当前快照 \\(snapshotSourceText)",
    "\\(remoteSnapshotStatusText)",
    "只展示脱敏聚合指标，不展示原始聊天内容",
]
for fragment in required_status_fragments:
    require(fragment in status_body, f"live evidence status card missing {fragment!r}")

require(
    "CareDashboardLiveEvidenceUIVerify/main.py" in phase1,
    "phase1 verification should include care dashboard live evidence UI coverage",
)

print("CareDashboardLiveEvidenceUI verification passed")

#!/usr/bin/env python3
from pathlib import Path
import re
import sys

ROOT = Path(__file__).resolve().parents[2]
MODELS = ROOT / "DreamJourney/Sources/Services/CareDashboard/CareSignalModels.swift"
ANALYZER = ROOT / "DreamJourney/Sources/Services/CareDashboard/CareSignalAnalyzer.swift"
PUBLISHER = ROOT / "DreamJourney/Sources/Services/CareDashboard/CareDashboardSnapshotPublisher.swift"
VC = ROOT / "DreamJourney/Sources/Modules/CareDashboard/CareDashboardViewController.swift"
PHASE1 = ROOT / "Scripts/verify_phase1.sh"


def require(condition: bool, message: str) -> None:
    if not condition:
        print(f"CareDashboardSourceAudit verification failed: {message}", file=sys.stderr)
        sys.exit(1)


models = MODELS.read_text(encoding="utf-8")
analyzer = ANALYZER.read_text(encoding="utf-8")
publisher = PUBLISHER.read_text(encoding="utf-8")
vc = VC.read_text(encoding="utf-8")
phase1 = PHASE1.read_text(encoding="utf-8")

require(
    "struct CareSignalSourceAudit" in models,
    "care snapshots should carry a machine-readable source audit",
)
for fragment in [
    "authorizedScopeText",
    "sourceKindText",
    "eligibleUserTurnCount",
    "contentRedactionText",
    "displaySummary",
]:
    require(fragment in models, f"source audit missing {fragment}")

require(
    "let sourceAudit: CareSignalSourceAudit?" in models,
    "CareSignalSnapshot should include optional source audit for backward-compatible backend snapshots",
)
require(
    re.search(r"func analyze\([\s\S]*sourceAudit: CareSignalSourceAudit\?", analyzer),
    "CareSignalAnalyzer should accept source audit and attach it to generated snapshots",
)
require(
    "CareSignalSourceAudit(" in publisher
    and "authorizedScopeText: \"亲友范围\"" in publisher
    and "sourceKindText: \"本机授权对话\"" in publisher
    and "contentRedactionText: \"脱敏聚合\"" in publisher,
    "local care snapshot publisher should build explicit family-circle redacted source audit",
)

status_match = re.search(r"private func makeEvidenceStatusCard\([\s\S]*?\n    private func makeMetricGrid", vc)
status_body = status_match.group(0) if status_match else ""
header_match = re.search(r"private func makeHeader\([\s\S]*?\n    private func viewerDescriptionText", vc)
header_body = header_match.group(0) if header_match else ""
share_match = re.search(r"struct CareDashboardShareReportDescriptor[\s\S]*?private static func metricLines", models)
share_body = share_match.group(0) if share_match else ""

for fragment in [
    "授权来源 \\(sourceAudit.authorizedScopeText)",
    "输入来源 \\(sourceAudit.sourceKindText)",
    "脱敏方式 \\(sourceAudit.contentRedactionText)",
]:
    require(fragment in status_body, f"evidence card should expose source audit fragment {fragment!r}")

require(
    "sourceAudit.displaySummary" in header_body,
    "header should show source audit summary beside data coverage",
)
require(
    "来源审计" in share_body and "sourceAudit?.displaySummary" in share_body,
    "shared care report should include source audit summary",
)
require(
    "CareDashboardSourceAuditVerify/main.py" in phase1,
    "phase1 verification should include care dashboard source audit coverage",
)

print("CareDashboardSourceAudit verification passed")

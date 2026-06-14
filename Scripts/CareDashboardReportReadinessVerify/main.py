#!/usr/bin/env python3
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
VC = ROOT / "DreamJourney/Sources/Modules/CareDashboard/CareDashboardViewController.swift"
MODELS = ROOT / "DreamJourney/Sources/Services/CareDashboard/CareSignalModels.swift"
PHASE1 = ROOT / "Scripts/verify_phase1.sh"


def require(condition, message):
    if not condition:
        print(f"CareDashboardReportReadiness verification failed: {message}", file=sys.stderr)
        sys.exit(1)


vc = VC.read_text()
models = MODELS.read_text()
phase1 = PHASE1.read_text()

require(
    "struct CareDashboardReportReadiness" in models
    and "enum CareDashboardReportReadinessPolicy" in models,
    "care dashboard should define explicit report-readiness policy",
)
require(
    "minimumUserTurns" in models
    and "minimumActiveDays" in models
    and "snapshot.userTurnCount" in models
    and "snapshot.dailyTrend.count" in models,
    "report readiness should require minimum real user turns and active days",
)
require(
    "reportReadiness(for: snapshot)" in vc
    and "CareDashboardReportReadinessPolicy.evaluate" in vc,
    "care dashboard view should use the readiness policy",
)
require(
    "canRenderCareInsight(snapshot)" in vc
    and "makeReportReadinessCard" in vc,
    "care dashboard should show preliminary insights before report is share-ready",
)
require(
    "家庭安心报采样中" in vc
    and "还需" in models,
    "UI should explain missing real data instead of overclaiming a weekly report",
)
require(
    "readiness.isReady" in vc
    and "真实关怀数据还在采样" in vc,
    "share action should block export until report readiness is met",
)
require(
    "CareDashboardReportReadinessVerify/main.py" in phase1,
    "phase1 verification should include care report readiness coverage",
)

print("CareDashboardReportReadiness verification passed")

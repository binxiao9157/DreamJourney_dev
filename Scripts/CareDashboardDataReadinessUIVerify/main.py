#!/usr/bin/env python3
from pathlib import Path
import re
import sys

ROOT = Path(__file__).resolve().parents[2]
VC = ROOT / "DreamJourney/Sources/Modules/CareDashboard/CareDashboardViewController.swift"
PUBLISHER = ROOT / "DreamJourney/Sources/Services/CareDashboard/CareDashboardSnapshotPublisher.swift"
PHASE1 = ROOT / "Scripts/verify_phase1.sh"


def require(condition: bool, message: str) -> None:
    if not condition:
        print(f"CareDashboardDataReadinessUI verification failed: {message}", file=sys.stderr)
        sys.exit(1)


vc = VC.read_text(encoding="utf-8")
publisher = PUBLISHER.read_text(encoding="utf-8") if PUBLISHER.exists() else ""
phase1 = PHASE1.read_text(encoding="utf-8")

reload_match = re.search(r"private func reloadSnapshot\([\s\S]*?\n    \}", vc)
reload_body = reload_match.group(0) if reload_match else ""
insufficient_match = re.search(r"private func makeInsufficientDataState\([\s\S]*?\n    \}", vc)
insufficient_body = insufficient_match.group(0) if insufficient_match else ""

require("localEligibleUserTurnCount" in vc, "care dashboard should track local eligible family-circle user turns")
require("remoteSnapshotStatusText" in vc, "care dashboard should track backend snapshot status for device testing")
require(
    "localEligibleUserTurnCount = localResult.eligibleUserTurnCount" in reload_body
    and (
        "eligibleUserTurnCount: eligibleTurns.filter" in publisher
        or (
            "let eligibleUserTurnCount = eligibleTurns.filter" in publisher
            and "eligibleUserTurnCount: eligibleUserTurnCount" in publisher
        )
    ),
    "reload should compute local eligible user-turn count through the shared publisher",
)
require(
    "remoteSnapshotStatusText = DreamJourneyBackendClient.shared.isConfigured" in reload_body
    and "服务器同步：未配置，当前仅本机分析" in reload_body,
    "reload should explain when backend is not configured",
)
require("setRemoteSnapshotStatus" in vc, "backend callbacks should update a persistent sync status")
require("本机可用发言" in insufficient_body, "insufficient-data UI should show local eligible user-turn count")
require("remoteSnapshotStatusText" in insufficient_body, "insufficient-data UI should show backend snapshot status")
require("CareDashboardDataReadinessUIVerify/main.py" in phase1, "phase1 verification should include care dashboard data-readiness UI coverage")

print("CareDashboardDataReadinessUI verification passed")

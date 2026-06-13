#!/usr/bin/env python3
from pathlib import Path
import re
import sys

ROOT = Path(__file__).resolve().parents[2]
VC = ROOT / "DreamJourney/Sources/Modules/CareDashboard/CareDashboardViewController.swift"
PHASE1 = ROOT / "Scripts/verify_phase1.sh"


def require(condition: bool, message: str) -> None:
    if not condition:
        print(f"CareDashboardBackendAccessStatusUI verification failed: {message}", file=sys.stderr)
        sys.exit(1)


vc = VC.read_text(encoding="utf-8")
phase1 = PHASE1.read_text(encoding="utf-8")

require(
    "private func isCareSnapshotAccessFailure(_ error: Error) -> Bool" in vc,
    "care dashboard should classify backend access/permission failures",
)
require(
    "private func careSnapshotAccessFailureMessage(for error: Error) -> String" in vc,
    "care dashboard should format backend access failures into product copy",
)
require(
    "亲友权限未生效或已撤回" in vc,
    "care dashboard should tell testers when family access is pending or revoked",
)
require(
    "后端返回 HTTP 403" in vc and "family member access is not active" in vc,
    "access-failure classifier should include HTTP 403 and backend family-access denial text",
)

sync_match = re.search(r"private func syncSnapshotToBackend[\s\S]*?private func setRemoteSnapshotStatus", vc)
latest_match = re.search(r"private func fetchLatestSnapshotFromBackend[\s\S]*?private func fetchSnapshotHistoryFromBackend", vc)
history_match = re.search(r"private func fetchSnapshotHistoryFromBackend[\s\S]*?private func applyRemoteSnapshotIfUseful", vc)

require(sync_match is not None, "syncSnapshotToBackend should exist")
require(latest_match is not None, "fetchLatestSnapshotFromBackend should exist")
require(history_match is not None, "fetchSnapshotHistoryFromBackend should exist")

sync_body = sync_match.group(0)
latest_body = latest_match.group(0)
history_body = history_match.group(0)

require(
    "careSnapshotAccessFailureMessage(for: error)" in sync_body,
    "sync failure should show access-aware status copy",
)
require(
    "careSnapshotAccessFailureMessage(for: error)" in latest_body,
    "latest fetch failure should show access-aware status copy",
)
require(
    "isCareSnapshotAccessFailure(error)" in history_body,
    "history failure should branch on access denial",
)
require(
    "fetchLatestSnapshotFromBackend()" in history_body and "return" in history_body,
    "history access denial should preserve the access-denied status instead of overwriting it with latest fetch fallback",
)
require(
    "CareDashboardBackendAccessStatusUIVerify/main.py" in phase1,
    "phase1 verification should include care dashboard access-status UI coverage",
)

print("CareDashboardBackendAccessStatusUI verification passed")

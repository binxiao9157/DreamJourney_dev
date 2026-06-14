#!/usr/bin/env python3
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
PUBLISHER = ROOT / "DreamJourney/Sources/Services/CareDashboard/CareDashboardSnapshotPublisher.swift"
CARE_VERIFY = ROOT / "Scripts/CareDashboardVerify/main.swift"
PHASE1 = ROOT / "Scripts/verify_phase1.sh"


def require(condition, message):
    if not condition:
        print(f"CareDashboardMemberPublish verification failed: {message}", file=sys.stderr)
        sys.exit(1)


publisher = PUBLISHER.read_text()
care_verify = CARE_VERIFY.read_text()
phase1 = PHASE1.read_text()

require("func backgroundPublishTargets(from turns: [ConversationTurn]) -> [String?]" in publisher,
        "publisher should compute all background publish targets")
require("var targets: [String?] = [nil]" in publisher,
        "publisher should keep the all-family snapshot target")
require("turn.privacyMetadata.scope == .familyCircle" in publisher,
        "publisher should derive member targets only from family-circle turns")
require("visibility.allowedMemberIDs" in publisher and "seenMemberIDs" in publisher,
        "publisher should publish once per explicitly allowed family member")
require("for viewerFamilyMemberID in targets" in publisher,
        "conversation-end publishing should iterate all targets")
require("viewerFamilyMemberID: viewerFamilyMemberID" in publisher,
        "each target should build and upload its own viewer-specific snapshot")
require("target=\\(targetDescription)" in publisher,
        "background publish logs should include the target for real-device diagnosis")
require("familyVisibility.allows(memberID: familyMemberID)" in (ROOT / "DreamJourney/Sources/Services/Privacy/MemoryPrivacyScope.swift").read_text(),
        "privacy policy should still enforce selected-member visibility")
require(
    "visibleTurns.map(\\.text) == [\"全体亲友可见：今天睡得还可以。\", \"女儿可见：最近有点孤单。\"]" in care_verify,
    "care input policy should support selected-member filtering",
)
require("CareDashboardMemberPublishVerify/main.py" in phase1,
        "phase1 verification should include member-specific publish coverage")

print("CareDashboardMemberPublish verification passed")

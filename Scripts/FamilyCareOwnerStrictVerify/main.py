#!/usr/bin/env python3
from pathlib import Path
import re
import sys

ROOT = Path(__file__).resolve().parents[2]
REPO = ROOT / "DreamJourney/Sources/Services/FamilyRepository.swift"
PHASE1 = ROOT / "Scripts/verify_phase1.sh"


def require(condition: bool, message: str) -> None:
    if not condition:
        print(f"FamilyCareOwnerStrict verification failed: {message}", file=sys.stderr)
        sys.exit(1)


repo = REPO.read_text(encoding="utf-8")
phase1 = PHASE1.read_text(encoding="utf-8")

match = re.search(r"func careOwnerUserID\(for viewerFamilyMemberID:[\s\S]*?\n    func acceptLocalInvitation", repo)
body = match.group(0) if match else ""

require(body, "FamilyRepository.careOwnerUserID(for:) should exist")
require(
    "explicitMemberID" in body
    and "trimmingCharacters(in: .whitespacesAndNewlines)" in body,
    "careOwnerUserID should normalize explicit viewer member id",
)
require(
    "if explicitMemberID?.isEmpty == false" in body
    and "return nil" in body,
    "explicit invalid viewer member id should return nil instead of falling back to current user",
)
require(
    "let candidateMemberID" in body
    and "explicitMemberID" in body
    and "currentViewerIdentity()?.familyMemberID" in body,
    "implicit viewer identity may still fall back to current user only when no explicit id was supplied",
)
require(
    "FamilyCareOwnerStrictVerify/main.py" in phase1,
    "phase1 verification should include strict family care-owner coverage",
)

print("FamilyCareOwnerStrict verification passed")

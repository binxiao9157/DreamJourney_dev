#!/usr/bin/env python3
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
VC = ROOT / "DreamJourney/Sources/Modules/MemoryArchive/MemoryArchiveViewController.swift"
EVIDENCE = ROOT / "DreamJourney/Sources/Services/MemoryArchive/MemoryArchiveKnowledgeEvidence.swift"
PROJECT = ROOT / "DreamJourney.xcodeproj/project.pbxproj"
PHASE1 = ROOT / "Scripts/verify_phase1.sh"


def require(condition, message):
    if not condition:
        print(f"MemoryArchiveKnowledgeEvidence verification failed: {message}", file=sys.stderr)
        sys.exit(1)


require(EVIDENCE.exists(), "archive knowledge evidence builder should exist")

vc = VC.read_text()
evidence = EVIDENCE.read_text()
project = PROJECT.read_text()
phase1 = PHASE1.read_text()

require(
    "struct MemoryArchiveKnowledgeEvidence" in evidence
    and "enum MemoryArchiveKnowledgeEvidenceBuilder" in evidence,
    "evidence builder should expose a value model and builder",
)
require(
    "sourceRefs.contains" in evidence
    and ".memoryArchiveItem" in evidence
    and "sourceRef.id == item.id" in evidence,
    "evidence builder should match KBLite entities by archive item sourceRef",
)
require(
    "people" in evidence and "places" in evidence and "events" in evidence and "facts" in evidence,
    "evidence should group generated entities by KBLite category",
)
require(
    "isArchiveMetadataOnlyFact" in evidence
    and '!isArchiveMetadataOnlyFact($0.statement)' in evidence,
    "evidence builder should not present archive save-only metadata facts as structured knowledge",
)
require(
    "查看建库证据" in vc
    and "presentKnowledgeEvidence(for: item)" in vc,
    "archive item action sheet should expose a knowledge evidence entry",
)
require(
    "MemoryArchiveKnowledgeEvidenceBuilder.build" in vc
    and "KBLiteManager.shared.displayGraphForLocalBrowsing()" in vc
    and "该素材暂未生成结构化知识" in vc,
    "archive screen should render source-specific KBLite evidence and empty state",
)
require(
    "MemoryArchiveKnowledgeEvidence.swift in Sources" in project,
    "Xcode project should compile archive knowledge evidence builder",
)
require(
    "MemoryArchiveKnowledgeEvidenceVerify/main.py" in phase1,
    "phase1 verification should include archive knowledge evidence coverage",
)
require(
    "MemoryArchiveKnowledgeEvidenceBehaviorVerify/main.swift" in phase1,
    "phase1 verification should include behavior coverage for archive evidence filtering",
)

print("MemoryArchiveKnowledgeEvidence verification passed")

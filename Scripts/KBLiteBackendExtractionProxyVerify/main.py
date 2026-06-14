#!/usr/bin/env python3
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "Scripts"))
from backend_repo import backend_file
CLIENT = ROOT / "DreamJourney/Sources/Services/DreamJourneyBackendClient.swift"
MANAGER = ROOT / "DreamJourney/Sources/Services/KBLiteManager.swift"
BACKEND_MAIN = backend_file(ROOT, "app/main.py")
BACKEND_DEEPSEEK = backend_file(ROOT, "app/services/deepseek.py")
PHASE1 = ROOT / "Scripts/verify_phase1.sh"


def require(condition: bool, message: str) -> None:
    if not condition:
        print(f"KBLiteBackendExtractionProxy verification failed: {message}", file=sys.stderr)
        sys.exit(1)


client = CLIENT.read_text(encoding="utf-8")
manager = MANAGER.read_text(encoding="utf-8")
backend_main = BACKEND_MAIN.read_text(encoding="utf-8")
backend_deepseek = BACKEND_DEEPSEEK.read_text(encoding="utf-8")
phase1 = PHASE1.read_text(encoding="utf-8")

for fragment in [
    "func extractKnowledge",
    'path: "kb/extract"',
    "struct KBExtractionResponse: Decodable",
    "let extraction: KBExtractionResult",
]:
    require(fragment in client, f"iOS backend client missing {fragment!r}")

for fragment in [
    "requestBackendExtraction",
    "DreamJourneyBackendClient.shared.extractKnowledge",
    "fallbackToLocalDeepSeekExtraction",
    "remotePrivacyMetadata",
]:
    require(fragment in manager, f"KBLiteManager should prefer backend extraction and keep fallback: {fragment!r}")

for fragment in [
    '@app.post("/kb/extract")',
    "DeepSeekKnowledgeExtractionProxy",
    "sanitize_knowledge_extraction_payload",
    "dryRun",
]:
    require(fragment in backend_main, f"backend /kb/extract route missing {fragment!r}")

for fragment in [
    "class DeepSeekKnowledgeExtractionProxy",
    "def request_extraction",
    "def parse_extraction",
    "strict JSON",
    "严格的 JSON",
]:
    require(fragment in backend_deepseek, f"backend DeepSeek knowledge proxy missing {fragment!r}")

require(
    "KBLiteBackendExtractionProxyVerify/main.py" in phase1,
    "phase1 verification should include backend extraction proxy coverage",
)

print("KBLiteBackendExtractionProxy verification passed")

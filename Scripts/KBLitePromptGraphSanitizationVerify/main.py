#!/usr/bin/env python3
from pathlib import Path
import re
import sys

ROOT = Path(__file__).resolve().parents[2]
MANAGER = ROOT / "DreamJourney/Sources/Services/KBLiteManager.swift"
GAP_DETECTOR = ROOT / "DreamJourney/Sources/Services/KBLiteGapDetector.swift"
FACADE = ROOT / "DreamJourney/Sources/Services/Stage1MemoryFacade.swift"
DIALOG = ROOT / "DreamJourney/Sources/Services/DialogEngineManager.swift"
PHASE1 = ROOT / "Scripts/verify_phase1.sh"


def require(condition: bool, message: str) -> None:
    if not condition:
        print(f"KBLitePromptGraphSanitization verification failed: {message}", file=sys.stderr)
        sys.exit(1)


manager = MANAGER.read_text(encoding="utf-8")
gap_detector = GAP_DETECTOR.read_text(encoding="utf-8")
facade = FACADE.read_text(encoding="utf-8")
dialog = DIALOG.read_text(encoding="utf-8")
phase1 = PHASE1.read_text(encoding="utf-8")

context_match = re.search(r"func buildContextString\(query:[\s\S]*?\n    // MARK: - Public API: Image Analysis", manager)
context_body = context_match.group(0) if context_match else ""
greeting_match = re.search(r"func buildGreetingHint\(\) -> String \{[\s\S]*?\n    \}", manager)
greeting_body = greeting_match.group(0) if greeting_match else ""
detect_match = re.search(r"func detectAllGaps\(surface:[\s\S]*?\n    \}", gap_detector)
detect_body = detect_match.group(0) if detect_match else ""
top_match = re.search(r"func topGaps\(_ n: Int = 5\)[\s\S]*?\n    \}", gap_detector)
top_body = top_match.group(0) if top_match else ""
dashboard_match = re.search(r"func dashboardSnapshot\(\)[\s\S]*?\n    \}", facade)
dashboard_body = dashboard_match.group(0) if dashboard_match else ""
prompt_snapshot_match = re.search(r"func promptArchiveSnapshot\(\) -> KBLiteGraph \{[\s\S]*?\n    \}", facade)
prompt_snapshot_body = prompt_snapshot_match.group(0) if prompt_snapshot_match else ""
grounding_plan_match = re.search(r"private func logMemoryGroundingPlan\(for query: String\)[\s\S]*?\n    \}", dialog)
grounding_plan_body = grounding_plan_match.group(0) if grounding_plan_match else ""
rag_send_match = re.search(r"private func sendMemoryRAGIfAvailable\(for query: String\)[\s\S]*?\n    \}", dialog)
rag_send_body = rag_send_match.group(0) if rag_send_match else ""
memory_context_match = re.search(r"private func buildMemoryContext\(memory: ConversationMemory\)[\s\S]*?\n    \}", dialog)
memory_context_body = memory_context_match.group(0) if memory_context_match else ""

require(
    "private func search(query: String, in sourceGraph: KBLiteGraph)" in manager,
    "KBLite should support searching inside a sanitized source graph",
)
require(
    "let promptGraph = sanitizedGraph(for: .prompt)" in context_body,
    "prompt context should be built from the sanitized prompt graph",
)
require(
    "search(query: q, in: promptGraph)" in context_body,
    "query prompt context should search the sanitized prompt graph",
)
require(
    "relatedFacts(\n                        in: promptGraph" in context_body,
    "related prompt facts should come from the sanitized prompt graph",
)
require(
    "promptGraph.people" in context_body and "promptGraph.events" in context_body,
    "recent prompt fallback should read sanitized people and events",
)
require(
    "let promptGraph = sanitizedGraph(for: .prompt)" in greeting_body,
    "greeting hints should be built from the sanitized prompt graph",
)
require(
    "promptGraph.people" in greeting_body and "promptGraph.events" in greeting_body,
    "greeting hints should not read raw graph people/events",
)
require(
    "KBLiteManager.shared.sanitizedGraph(for: $0)" in gap_detector,
    "gap detection should sanitize the graph for the requested surface",
)
require(
    "KBLiteManager.shared.displayGraphForLocalBrowsing()" in gap_detector,
    "surface-less gap detection should still strip legacy/demo and generic kinship entities",
)
require(
    "func topGaps(_ n: Int = 5, surface: MemoryUseSurface = .prompt)" in gap_detector
    and "detectAllGaps(surface: surface)" in gap_detector,
    "top prompt gaps should use prompt-safe graph data",
)
require(
    "gapDetector.topGaps(5, surface: .prompt)" in dashboard_body,
    "dashboard gaps should use the same cleaned prompt graph as the visible snapshot",
)
require(
    "func promptArchiveSnapshot() -> KBLiteGraph" in facade
    and "knowledgeBase.sanitizedGraph(for: .prompt)" in prompt_snapshot_body,
    "dialog generation should have a prompt-only archive snapshot",
)
require(
    "Stage1MemoryFacade.shared.promptArchiveSnapshot()" in grounding_plan_body,
    "dialog grounding logs should use prompt-safe archive data",
)
require(
    "Stage1MemoryFacade.shared.promptArchiveSnapshot()" in rag_send_body,
    "dialog realtime RAG payload should use prompt-safe archive data",
)
require(
    "Stage1MemoryFacade.shared.promptArchiveSnapshot()" in memory_context_body,
    "dialog startup memory context should use prompt-safe archive data",
)
require(
    "MemoryArchiveMetadataOnlyDepositVerify/main.py" in phase1
    and "KBLitePromptGraphSanitizationVerify/main.py" in phase1,
    "phase1 verification should include archive metadata and prompt graph sanitization coverage",
)

print("KBLitePromptGraphSanitization verification passed")

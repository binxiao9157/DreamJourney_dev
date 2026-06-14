#!/usr/bin/env python3
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[2]
GRAPH_VIEW = ROOT / "DreamJourney/Sources/Modules/Knowledge/KBGraphViewController.swift"
PHASE1 = ROOT / "Scripts/verify_phase1.sh"


def require(condition: bool, message: str) -> None:
    if not condition:
        print(f"KnowledgeGraphLiveUpdate verification failed: {message}", file=sys.stderr)
        sys.exit(1)


source = GRAPH_VIEW.read_text(encoding="utf-8")
phase1 = PHASE1.read_text(encoding="utf-8")

require(
    "NotificationCenter.default.addObserver(self" in source
    and "name: .kbLiteDidUpdate" in source,
    "graph view should observe KBLite updates while it is open",
)
require(
    "@objc private func onKBUpdated()" in source
    and "rebuildGraph()" in source,
    "graph view should rebuild itself when KBLite finishes background extraction",
)
require(
    "private func rebuildGraph()" in source
    and "clearGraphViews()" in source
    and "buildGraph()" in source,
    "graph rebuild should clear old nodes/edges before building the latest graph",
)
require(
    "private func clearGraphViews()" in source
    and "nodeViews.values.forEach" in source
    and "edges.forEach" in source
    and "emptyLabel.removeFromSuperview()" in source,
    "graph cleanup should remove stale nodes, edges and empty-state UI",
)
require(
    "deinit" in source and "NotificationCenter.default.removeObserver(self)" in source,
    "graph view should remove its KBLite update observer",
)
require(
    "KnowledgeGraphLiveUpdateVerify/main.py" in phase1,
    "phase1 verification should include live graph update coverage",
)

print("KnowledgeGraphLiveUpdate verification passed")

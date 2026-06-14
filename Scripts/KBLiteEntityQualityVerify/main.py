#!/usr/bin/env python3
from pathlib import Path
import re
import sys

source = Path("DreamJourney/Sources/Services/KBLiteManager.swift").read_text()
knowledge_view = Path("DreamJourney/Sources/Modules/Knowledge/KnowledgeBaseViewController.swift").read_text()
graph_view = Path("DreamJourney/Sources/Modules/Knowledge/KBGraphViewController.swift").read_text()
layout_engine = Path("DreamJourney/Sources/Modules/Knowledge/KBGraphLayoutEngine.swift").read_text()
facade = Path("DreamJourney/Sources/Services/Stage1MemoryFacade.swift").read_text()

checks = [
    (
        "image/person description extraction must not return bare kinship labels as person names",
        "return rel" not in re.search(
            r"private func extractPersonNameFromDescription[\s\S]*?\n    \}",
            source,
        ).group(0),
    ),
    (
        "KBLite should expose a reusable generic-kinship filter for display and imports",
        "isGenericKinshipDisplayName" in source,
    ),
    (
        "KBLite should expose a local display graph that strips legacy seed and generic kinship entities",
        "displayGraphForLocalBrowsing" in source and "removeLegacyOrLowQualityEntities" in source,
    ),
    (
        "knowledge base should read from the cleaned local display graph",
        "displayGraphForLocalBrowsing" in knowledge_view and "private var displayGraph" in knowledge_view,
    ),
    (
        "knowledge graph should read from the cleaned local display graph",
        "displayGraphForLocalBrowsing" in graph_view,
    ),
    (
        "knowledge graph should not inject a synthetic self node in real-data browsing",
        "__self__" not in graph_view,
    ),
    (
        "knowledge graph should not invent all-person relationships from the current user",
        "relatedPersonIds: people.map" not in graph_view,
    ),
    (
        "knowledge graph layout should not infer relationship edges from the raw graph",
        "KBLiteManager.shared.graph.events" not in layout_engine
        and "computeLayout(for people: [KBPerson], graph: KBLiteGraph)" in layout_engine,
    ),
    (
        "dashboard snapshots should use the cleaned local display graph for stats",
        "displayGraphForLocalBrowsing" in facade
        and "stats: Self.statsSummary(for: graph)" in facade
        and "isEmpty: Self.isEmpty(graph)" in facade,
    ),
    (
        "knowledge graph empty state should guide users to add concrete names instead of bare kinship labels",
        "具体姓名" in graph_view and "妈妈/奶奶" in graph_view,
    ),
    (
        "KBLite should hide isolated bare kinship facts from local browsing",
        "isGenericKinshipOnlyFact" in source,
    ),
    (
        "KBLite should hide unresolved generic kinship facts from local browsing/imports",
        "isUnresolvedGenericKinshipFact" in source,
    ),
]

failed = [message for message, passed in checks if not passed]
if failed:
    for message in failed:
        print(f"KBLiteEntityQuality verification failed: {message}", file=sys.stderr)
    sys.exit(1)

print("KBLiteEntityQuality verification passed")

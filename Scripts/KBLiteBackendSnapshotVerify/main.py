#!/usr/bin/env python3
from pathlib import Path
import sys

root = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(root / "Scripts"))
from backend_repo import backend_file
client = (root / "DreamJourney/Sources/Services/DreamJourneyBackendClient.swift").read_text()
manager = (root / "DreamJourney/Sources/Services/KBLiteManager.swift").read_text()
phase1 = (root / "Scripts/verify_phase1.sh").read_text()
backend = (backend_file(root, "app/main.py")).read_text()

checks = [
    (
        "iOS client should expose kb snapshot fetch",
        "func fetchKnowledgeBaseSnapshot(" in client,
    ),
    (
        "iOS client should call the backend kb snapshot endpoint",
        'path: "kb/snapshot/' in client or "kb/snapshot/\\(" in client,
    ),
    (
        "iOS client should decode a typed KBLite snapshot response",
        "struct KBSnapshotResponse: Decodable" in client and "let graph: KBLiteGraph" in client,
    ),
    (
        "KBLite should bootstrap from backend when configured",
        "bootstrapFromBackendIfNeeded" in manager,
    ),
    (
        "KBLite should merge newer remote snapshots into the local graph",
        "applyRemoteSnapshotIfUseful" in manager,
    ),
    (
        "backend should expose kb snapshot fetch endpoint",
        '@app.get("/kb/snapshot/{user_id}")' in backend,
    ),
    (
        "phase1 verification should cover KBLite backend snapshot restore",
        "KBLiteBackendSnapshotVerify" in phase1,
    ),
]

failed = [message for message, passed in checks if not passed]
if failed:
    for message in failed:
        print(f"KBLiteBackendSnapshot verification failed: {message}", file=sys.stderr)
    sys.exit(1)

print("KBLiteBackendSnapshot verification passed")

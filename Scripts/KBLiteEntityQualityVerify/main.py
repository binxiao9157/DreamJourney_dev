#!/usr/bin/env python3
from pathlib import Path
import re
import sys

source = Path("DreamJourney/Sources/Services/KBLiteManager.swift").read_text()
knowledge_view = Path("DreamJourney/Sources/Modules/Knowledge/KnowledgeBaseViewController.swift").read_text()

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
        "knowledge base people list should hide bare kinship labels such as 妈妈",
        "isGenericKinshipDisplayName" in knowledge_view,
    ),
]

failed = [message for message, passed in checks if not passed]
if failed:
    for message in failed:
        print(f"KBLiteEntityQuality verification failed: {message}", file=sys.stderr)
    sys.exit(1)

print("KBLiteEntityQuality verification passed")

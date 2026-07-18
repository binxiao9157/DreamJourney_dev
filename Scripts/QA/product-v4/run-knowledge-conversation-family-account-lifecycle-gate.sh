#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
cd "$ROOT_DIR"

python3 Scripts/QA/product-v4/knowledge-conversation-family-account-lifecycle-check.py

xcrun swiftc -frontend -parse \
  DreamJourney/Sources/Services/ConversationMemoryManager.swift \
  DreamJourney/Sources/Services/KBLiteManager.swift \
  DreamJourney/Sources/Services/KnowledgeSyncCoordinator.swift \
  DreamJourney/Sources/Services/FamilyRepository.swift

git diff --check -- \
  DreamJourney/Sources/Services/ConversationMemoryManager.swift \
  DreamJourney/Sources/Services/KBLiteManager.swift \
  DreamJourney/Sources/Services/KnowledgeSyncCoordinator.swift \
  DreamJourney/Sources/Services/FamilyRepository.swift \
  Scripts/QA/product-v4/knowledge-conversation-family-account-lifecycle-check.py \
  Scripts/QA/product-v4/run-knowledge-conversation-family-account-lifecycle-gate.sh

echo "Knowledge/Conversation/Family account lifecycle gate passed"

#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
cd "$ROOT_DIR"

python3 Scripts/QA/product-v4/knowledge-family-account-deletion-purge-check.py

bash Scripts/QA/product-v4/run-knowledge-conversation-family-account-lifecycle-gate.sh
bash Scripts/QA/product-v4/run-account-lifecycle-coordinator-gate.sh
bash Scripts/QA/product-v4/run-account-lifecycle-module-registry-gate.sh

xcrun swiftc -frontend -parse \
  DreamJourney/Sources/Services/KBLiteManager.swift \
  DreamJourney/Sources/Services/KnowledgeSyncCoordinator.swift \
  DreamJourney/Sources/Services/ConversationMemoryManager.swift \
  DreamJourney/Sources/Services/FamilyRepository.swift

git diff --check -- \
  DreamJourney/Sources/Services/KBLiteManager.swift \
  DreamJourney/Sources/Services/KnowledgeSyncCoordinator.swift \
  DreamJourney/Sources/Services/ConversationMemoryManager.swift \
  DreamJourney/Sources/Services/FamilyRepository.swift \
  Scripts/QA/product-v4/knowledge-family-account-deletion-purge-check.py \
  Scripts/QA/product-v4/run-knowledge-family-account-deletion-purge-gate.sh

echo "PASS: WI-S0-01-08C Knowledge/Family account deletion purge gate"

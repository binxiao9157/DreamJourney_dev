#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
BUILD_DIR="${TMPDIR:-/tmp}/dreamjourney-v4-conversation-owner-storage"

mkdir -p "$BUILD_DIR"

swiftc -parse-as-library \
  "$ROOT_DIR/DreamJourney/Sources/Services/ConversationLocalStorage.swift" \
  "$ROOT_DIR/Scripts/QA/product-v4/conversation-owner-storage-model-smoke.swift" \
  -o "$BUILD_DIR/conversation-owner-storage-model-smoke"

"$BUILD_DIR/conversation-owner-storage-model-smoke"
python3 "$ROOT_DIR/Scripts/QA/product-v4/conversation-owner-storage-static-check.py"

echo "Conversation owner storage gate passed"

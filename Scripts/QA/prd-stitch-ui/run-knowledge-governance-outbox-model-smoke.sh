#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../../.." && pwd)"
OUTPUT_DIR="${OUTPUT_DIR:-$ROOT_DIR/tmp/visual-qa/prd-stitch-ui/knowledge-governance-outbox-model-smoke}"
BIN_PATH="$OUTPUT_DIR/knowledge-governance-outbox-model-smoke"

mkdir -p "$OUTPUT_DIR"

swiftc \
  -parse-as-library \
  "$ROOT_DIR/DreamJourney/Sources/Services/KBLiteModels.swift" \
  "$ROOT_DIR/DreamJourney/Sources/Services/EchoKnowledgeContextPolicy.swift" \
  "$ROOT_DIR/DreamJourney/Sources/Services/KnowledgeLocalStoragePolicy.swift" \
  "$ROOT_DIR/DreamJourney/Sources/Services/KnowledgeThreeWayMerge.swift" \
  "$SCRIPT_DIR/knowledge-governance-outbox-model-smoke.swift" \
  -o "$BIN_PATH"

"$BIN_PATH"

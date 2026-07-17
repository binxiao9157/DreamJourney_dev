#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../../.." && pwd)"
OUTPUT_DIR="${OUTPUT_DIR:-$ROOT_DIR/tmp/visual-qa/prd-stitch-ui/knowledge-widget-snapshot-store-model-smoke}"
BIN_PATH="$OUTPUT_DIR/knowledge-widget-snapshot-store-model-smoke"

mkdir -p "$OUTPUT_DIR"

swiftc \
  -parse-as-library \
  "$ROOT_DIR/DreamJourney/Sources/App/AccountLease.swift" \
  "$ROOT_DIR/DreamJourney/Sources/App/AccountSessionActor.swift" \
  "$ROOT_DIR/DreamJourney/Sources/Services/KBLiteModels.swift" \
  "$ROOT_DIR/DreamJourney/Sources/Services/KnowledgeWidgetPrivacyPolicy.swift" \
  "$ROOT_DIR/DreamJourney/Sources/Services/KnowledgeWidgetSnapshotStore.swift" \
  "$SCRIPT_DIR/knowledge-widget-snapshot-store-model-smoke.swift" \
  -o "$BIN_PATH"

"$BIN_PATH"

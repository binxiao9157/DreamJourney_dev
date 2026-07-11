#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../../.." && pwd)"
OUTPUT_DIR="${OUTPUT_DIR:-$ROOT_DIR/tmp/visual-qa/prd-stitch-ui/knowledge-widget-snapshot-reader-model-smoke}"
BIN_PATH="$OUTPUT_DIR/knowledge-widget-snapshot-reader-model-smoke"

mkdir -p "$OUTPUT_DIR"

swiftc \
  -parse-as-library \
  "$ROOT_DIR/DreamJourneyWidget/SharedModels.swift" \
  "$ROOT_DIR/DreamJourneyWidget/WidgetKnowledgeSnapshotReader.swift" \
  "$SCRIPT_DIR/knowledge-widget-snapshot-reader-model-smoke.swift" \
  -o "$BIN_PATH"

"$BIN_PATH"

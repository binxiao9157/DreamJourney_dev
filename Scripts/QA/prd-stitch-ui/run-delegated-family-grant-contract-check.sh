#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../../.." && pwd)"
OUTPUT_DIR="${OUTPUT_DIR:-$ROOT_DIR/tmp/visual-qa/prd-stitch-ui/delegated-family-grant-contract-check}"
BIN_PATH="$OUTPUT_DIR/delegated-family-grant-contract-check"

mkdir -p "$OUTPUT_DIR"

swiftc \
  -parse-as-library \
  "$ROOT_DIR/DreamJourney/Sources/Services/FamilyRelationshipAuthorizationPolicy.swift" \
  "$ROOT_DIR/DreamJourney/Sources/Services/MemoryModel.swift" \
  "$SCRIPT_DIR/delegated-family-grant-contract-check.swift" \
  -o "$BIN_PATH"

"$BIN_PATH" "$ROOT_DIR"

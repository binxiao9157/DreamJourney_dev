#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../../.." && pwd)"
OUTPUT_DIR="${OUTPUT_DIR:-$ROOT_DIR/tmp/visual-qa/product-v4/identity-challenge-client-model-smoke}"
BIN_PATH="$OUTPUT_DIR/identity-challenge-client-model-smoke"

mkdir -p "$OUTPUT_DIR"

swiftc \
  -parse-as-library \
  "$ROOT_DIR/DreamJourney/Sources/Services/BackendIdentityChallenge.swift" \
  "$SCRIPT_DIR/identity-challenge-client-model-smoke.swift" \
  -o "$BIN_PATH"

"$BIN_PATH"

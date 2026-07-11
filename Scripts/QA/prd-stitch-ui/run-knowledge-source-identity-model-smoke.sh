#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

swiftc \
  "$ROOT_DIR/DreamJourney/Sources/Services/KBLiteModels.swift" \
  "$ROOT_DIR/Scripts/QA/prd-stitch-ui/knowledge-source-identity-model-smoke.swift" \
  -o "$TMP_DIR/knowledge-source-identity-model-smoke"

"$TMP_DIR/knowledge-source-identity-model-smoke"

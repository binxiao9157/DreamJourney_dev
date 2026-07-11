#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
BUILD_DIR="$ROOT_DIR/tmp/visual-qa/prd-stitch-ui/family-authorization-freshness-model"
mkdir -p "$BUILD_DIR"

swiftc \
  "$ROOT_DIR/DreamJourney/Sources/Services/FamilyRelationshipAuthorizationPolicy.swift" \
  "$ROOT_DIR/Scripts/QA/prd-stitch-ui/family-authorization-freshness-model-smoke.swift" \
  -o "$BUILD_DIR/family-authorization-freshness-model-smoke"

"$BUILD_DIR/family-authorization-freshness-model-smoke"

#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../../.." && pwd)"

cd "$ROOT_DIR"
swiftc \
  DreamJourney/Sources/Services/FamilyRelationshipAuthorizationPolicy.swift \
  "$SCRIPT_DIR/family-context-reconciliation-model-smoke.swift" \
  -o /tmp/family-context-reconciliation-model-smoke
/tmp/family-context-reconciliation-model-smoke

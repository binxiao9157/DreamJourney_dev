#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../../.." && pwd)"
WORKSPACE_ROOT="$(cd "$ROOT_DIR/.." && pwd)"
BACKEND_ROOT="${BACKEND_ROOT:-$WORKSPACE_ROOT/DreamJourneyBackend}"

"$SCRIPT_DIR/run-knowledge-governance-model-smoke.sh"
"$SCRIPT_DIR/run-knowledge-governance-client-check.sh"
"$SCRIPT_DIR/run-knowledge-governance-outbox-model-smoke.sh"
"$SCRIPT_DIR/run-knowledge-governance-coordinator-check.sh"
swift "$SCRIPT_DIR/knowledge-governance-release-boundary-check.swift" "$ROOT_DIR"
"$SCRIPT_DIR/run-knowledge-three-way-merge-model-smoke.sh"
"$SCRIPT_DIR/run-knowledge-proposal-model-smoke.sh"
"$SCRIPT_DIR/run-knowledge-context-policy-model-smoke.sh"

if [[ ! -x "$BACKEND_ROOT/scripts/run-backend-knowledge-governance-source-cascade-smoke.sh" ]]; then
  echo "Backend governance runner missing: $BACKEND_ROOT" >&2
  exit 1
fi

BACKEND_ROOT="$BACKEND_ROOT" \
  "$BACKEND_ROOT/scripts/run-backend-knowledge-governance-source-cascade-smoke.sh"

echo "Knowledge governance cross-repository gate passed"

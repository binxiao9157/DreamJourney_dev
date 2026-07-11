#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../../.." && pwd)"
WORKSPACE_ROOT="$(cd "$ROOT_DIR/.." && pwd)"
BACKEND_ROOT="${BACKEND_ROOT:-$WORKSPACE_ROOT/DreamJourneyBackend}"

"$SCRIPT_DIR/run-knowledge-change-feed-pagination-model-smoke.sh"
swift "$SCRIPT_DIR/knowledge-change-feed-pagination-coordinator-check.swift" "$ROOT_DIR"

if [[ ! -x "$BACKEND_ROOT/scripts/run-backend-knowledge-change-feed-pagination-smoke.sh" ]]; then
  echo "Backend pagination runner missing: $BACKEND_ROOT" >&2
  exit 1
fi
"$BACKEND_ROOT/scripts/run-backend-knowledge-change-feed-pagination-smoke.sh"

echo "Knowledge change feed pagination cross-repository gate passed"

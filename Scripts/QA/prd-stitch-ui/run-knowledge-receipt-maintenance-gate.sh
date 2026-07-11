#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../../.." && pwd)"
WORKSPACE_ROOT="$(cd "$ROOT_DIR/.." && pwd)"
export BACKEND_ROOT="${BACKEND_ROOT:-$WORKSPACE_ROOT/DreamJourneyBackend}"

swift "$SCRIPT_DIR/knowledge-receipt-maintenance-contract-check.swift" "$ROOT_DIR"

BACKEND_RUNNER="$BACKEND_ROOT/scripts/run-backend-knowledge-receipt-maintenance-smoke.sh"
if [[ ! -x "$BACKEND_RUNNER" ]]; then
  echo "Backend knowledge receipt maintenance runner missing: $BACKEND_RUNNER" >&2
  exit 1
fi

"$BACKEND_RUNNER"

echo "Knowledge receipt maintenance cross-repository gate passed"

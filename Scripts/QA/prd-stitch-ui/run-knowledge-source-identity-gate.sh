#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../../.." && pwd)"
WORKSPACE_ROOT="$(cd "$ROOT_DIR/.." && pwd)"
BACKEND_ROOT="${BACKEND_ROOT:-$WORKSPACE_ROOT/DreamJourneyBackend}"

"$SCRIPT_DIR/run-knowledge-source-identity-model-smoke.sh"
swift "$SCRIPT_DIR/knowledge-source-identity-client-check.swift" "$ROOT_DIR"

BACKEND_RUNNER="$BACKEND_ROOT/scripts/run-backend-knowledge-source-identity-smoke.sh"
if [[ ! -x "$BACKEND_RUNNER" ]]; then
  echo "Backend knowledge source identity runner missing: $BACKEND_RUNNER" >&2
  exit 1
fi

"$BACKEND_RUNNER"

echo "Knowledge source identity cross-repository gate passed"

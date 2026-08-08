#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../../.." && pwd)"
WORKSPACE_ROOT="$(cd "$ROOT_DIR/.." && pwd)"
BACKEND_ROOT="${BACKEND_ROOT:-$WORKSPACE_ROOT/DreamJourneyBackend}"
PRD_QA_DIR="$ROOT_DIR/Scripts/QA/prd-stitch-ui"
BACKEND_RUNNER="$BACKEND_ROOT/scripts/run-backend-voice-clone-r5-provider-boundary-gate.sh"

if [[ ! -x "$BACKEND_RUNNER" ]]; then
  echo "Backend voice-clone R5 Provider boundary runner missing or not executable: $BACKEND_RUNNER" >&2
  exit 1
fi

# This gate is deliberately provider-free and device-free. It proves that the
# server owns operation authority while iOS consumes the same fail-closed
# matrix without calling a real voice slot or audio runtime.
swift "$PRD_QA_DIR/voice-clone-runtime-capability-check.swift" "$ROOT_DIR"
swift "$PRD_QA_DIR/voice-clone-c1-c2-contract-check.swift" "$ROOT_DIR"
"$BACKEND_RUNNER"

echo "Voice clone R5 Provider boundary gate passed"

#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../../.." && pwd)"
WORKSPACE_ROOT="$(cd "$ROOT_DIR/.." && pwd)"
BACKEND_ROOT="${BACKEND_ROOT:-$WORKSPACE_ROOT/DreamJourneyBackend}"
PRD_QA_DIR="$ROOT_DIR/Scripts/QA/prd-stitch-ui"
BACKEND_RUNNER="$BACKEND_ROOT/scripts/run-backend-voice-clone-r5-echo-binding-gate.sh"

if [[ ! -x "$BACKEND_RUNNER" ]]; then
  echo "Backend R5 Echo binding runner missing or not executable: $BACKEND_RUNNER" >&2
  exit 1
fi

# The gate is device-free and Provider-free. It proves that one Echo PCM result
# is bound to the active owner, role, profile generation, and exact reply text,
# then exercises the existing cancellation/audio-owner fault-injection path.
swift "$PRD_QA_DIR/echo-voice-synthesis-binding-check.swift" "$ROOT_DIR"
swift "$PRD_QA_DIR/voice-clone-runtime-fault-injection-smoke-check.swift" "$ROOT_DIR"
"$BACKEND_RUNNER"
"$PRD_QA_DIR/run-voice-clone-c2-runtime-fault-injection-gate.sh"

echo "Voice clone R5 Echo binding gate passed"

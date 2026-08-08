#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../../.." && pwd)"
WORKSPACE_ROOT="$(cd "$ROOT_DIR/.." && pwd)"
BACKEND_ROOT="${BACKEND_ROOT:-$WORKSPACE_ROOT/DreamJourneyBackend}"

BACKEND_RUNNER="$BACKEND_ROOT/scripts/run-backend-voice-clone-c1-lifecycle-gate.sh"
if [[ ! -x "$BACKEND_RUNNER" ]]; then
  echo "Backend voice-clone C1 lifecycle runner missing or not executable: $BACKEND_RUNNER" >&2
  exit 1
fi

# No simulator, device, audio provider, sample upload, or production slot is
# needed here. The backend runner uses fake deletion observations only.
swift "$SCRIPT_DIR/voice-clone-c1-c2-contract-check.swift" "$ROOT_DIR"
"$BACKEND_RUNNER"

echo "Voice clone C1/C2 non-device gate passed"

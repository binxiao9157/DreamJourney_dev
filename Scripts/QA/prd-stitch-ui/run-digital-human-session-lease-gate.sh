#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../../.." && pwd)"
WORKSPACE_ROOT="$(cd "$ROOT_DIR/.." && pwd)"
BACKEND_ROOT="${BACKEND_ROOT:-$WORKSPACE_ROOT/DreamJourneyBackend}"

RUN_ID="${RUN_ID:-$(date +%Y%m%d-%H%M%S)-digital-human-session-lease}"
OUTPUT_ROOT="${OUTPUT_ROOT:-$ROOT_DIR/tmp/visual-qa/prd-stitch-ui/digital-human-session-lease-gate}"
OUTPUT_DIR="$OUTPUT_ROOT/$RUN_ID"
REPORT_PATH="$OUTPUT_DIR/report.md"
COMMAND_LOG="$OUTPUT_DIR/commands.log"
DERIVED_DATA_PATH="${DERIVED_DATA_PATH:-$OUTPUT_DIR/DerivedDataRuntimeStubSmoke}"

mkdir -p "$OUTPUT_DIR"
touch "$COMMAND_LOG"
cd "$ROOT_DIR"

run_step() {
  local name="$1"
  shift
  local log_path="$1"
  shift

  echo "== $name ==" | tee -a "$COMMAND_LOG"
  printf '+ ' >> "$COMMAND_LOG"
  printf '%q ' "$@" >> "$COMMAND_LOG"
  printf '\n' >> "$COMMAND_LOG"
  if "$@" > "$log_path" 2>&1; then
    echo "- $name: passed" >> "$REPORT_PATH"
  else
    echo "- $name: failed" >> "$REPORT_PATH"
    cat "$log_path" >&2
    exit 1
  fi
}

run_shell_step() {
  local name="$1"
  shift
  local log_path="$1"
  shift
  local command="$*"

  echo "== $name ==" | tee -a "$COMMAND_LOG"
  echo "+ $command" >> "$COMMAND_LOG"
  if bash -lc "$command" > "$log_path" 2>&1; then
    echo "- $name: passed" >> "$REPORT_PATH"
  else
    echo "- $name: failed" >> "$REPORT_PATH"
    cat "$log_path" >&2
    exit 1
  fi
}

cat > "$REPORT_PATH" <<EOF
# Digital Human Session Lease Non-Device Gate

Run ID: \`$RUN_ID\`

## Scope

- Backend in-memory and Postgres-adapter tests for lease reuse, heartbeat, release, expiry, and capacity arbitration.
- iOS static guard for heartbeat scheduling, stale-response release, unified runtime release, and user-stop preservation.
- Simulator runtime stub smoke for create, heartbeat, and release.
- No true-device or real Tencent cloud-render validation is performed.

## Results

EOF

[[ -x "$BACKEND_ROOT/scripts/run-digital-human-session-lease-smoke.sh" ]] || {
  echo "Backend lease smoke is missing: $BACKEND_ROOT/scripts/run-digital-human-session-lease-smoke.sh" >&2
  exit 1
}

run_step \
  "Backend session lease tests" \
  "$OUTPUT_DIR/backend-session-lease-tests.log" \
  "$BACKEND_ROOT/scripts/run-digital-human-session-lease-smoke.sh"

run_step \
  "iOS session lease static guard" \
  "$OUTPUT_DIR/ios-session-lease-static.log" \
  swift "$SCRIPT_DIR/digital-human-session-lease-check.swift" "$ROOT_DIR"

run_shell_step \
  "Simulator runtime create-heartbeat-release smoke" \
  "$OUTPUT_DIR/runtime-stub-smoke.log" \
  "RUN_ID='${RUN_ID}-runtime-stub' OUTPUT_ROOT='$OUTPUT_DIR/runtime-stub' DERIVED_DATA_PATH='$DERIVED_DATA_PATH' '$SCRIPT_DIR/run-digital-human-runtime-stub-smoke.sh'"

run_step \
  "iOS git diff whitespace check" \
  "$OUTPUT_DIR/ios-git-diff-check.log" \
  git diff --check

run_step \
  "Backend git diff whitespace check" \
  "$OUTPUT_DIR/backend-git-diff-check.log" \
  git -C "$BACKEND_ROOT" diff --check

cat >> "$REPORT_PATH" <<EOF

## Evidence

- Commands: \`commands.log\`
- Backend tests: \`backend-session-lease-tests.log\`
- iOS guard: \`ios-session-lease-static.log\`
- Runtime stub smoke: \`runtime-stub/${RUN_ID}-runtime-stub/\`
- Runtime stub wrapper log: \`runtime-stub-smoke.log\`

## Boundary

This gate proves the local contract and simulator lifecycle only. Tencent quota behavior, rendered avatar continuity, real audio, lip movement, interruption, and microphone recovery remain true-device acceptance items.

EOF

echo "Digital-human session lease gate completed: $REPORT_PATH"

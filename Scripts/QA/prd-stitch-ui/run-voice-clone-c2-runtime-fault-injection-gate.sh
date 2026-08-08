#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../../.." && pwd)"

RUN_ID="${RUN_ID:-$(date +%Y%m%d-%H%M%S)-voice-clone-c2-runtime-fault}"
OUTPUT_ROOT="${OUTPUT_ROOT:-$ROOT_DIR/tmp/visual-qa/prd-stitch-ui/voice-clone-c2-runtime-fault-injection-gate}"
OUTPUT_DIR="$OUTPUT_ROOT/$RUN_ID"
REPORT_PATH="$OUTPUT_DIR/report.md"

mkdir -p "$OUTPUT_DIR"
cd "$ROOT_DIR"

fail() {
  {
    echo
    echo "## Result"
    echo
    echo "- Status: failed"
    echo "- Reason: $*"
  } >> "$REPORT_PATH"
  echo "[voice-clone-c2-runtime-fault-injection-gate] $*" >&2
  exit 1
}

run_gate() {
  local title="$1"
  local subdir="$2"
  shift 2
  echo "[voice-clone-c2-runtime-fault-injection-gate] Running $title..."
  {
    echo
    echo "## $title"
    echo
    echo "- Output: \`$subdir/$RUN_ID/\`"
  } >> "$REPORT_PATH"
  RUN_ID="$RUN_ID" OUTPUT_ROOT="$OUTPUT_DIR/$subdir" "$@" || fail "$title failed"
}

cat > "$REPORT_PATH" <<REPORT
# Voice clone C2 runtime fault-injection gate

- Run ID: \`$RUN_ID\`
- Output dir: \`$OUTPUT_DIR\`

This non-device gate verifies that revoked or stale voice-clone PCM cannot
enter the Tencent audio-drive runtime, and that cancellation and failure leave
audio ownership and continuous Echo conversation in a deterministic state.

REPORT

run_gate \
  "Static contract check" \
  "static-contract" \
  swift "$SCRIPT_DIR/voice-clone-runtime-fault-injection-smoke-check.swift" "$ROOT_DIR"

run_gate \
  "Voice clone runtime fault-injection UIQA smoke" \
  "runtime-fault-injection" \
  env DERIVED_DATA_PATH="$OUTPUT_DIR/DerivedDataVoiceCloneRuntimeFaultInjectionSmoke" \
  "$SCRIPT_DIR/run-voice-clone-runtime-fault-injection-smoke.sh"

run_gate \
  "Echo audio-owner coordinator UIQA smoke" \
  "audio-owner-coordinator" \
  env DERIVED_DATA_PATH="$OUTPUT_DIR/DerivedDataEchoAudioOwnerCoordinatorSmoke" \
  "$SCRIPT_DIR/run-echo-audio-owner-coordinator-uiqa-smoke.sh"

run_gate \
  "Echo continuous-turn UIQA smoke" \
  "continuous-turn" \
  env DERIVED_DATA_PATH="$OUTPUT_DIR/DerivedDataEchoContinuousTurnUIQASmoke" \
  "$SCRIPT_DIR/run-echo-continuous-turn-uiqa-smoke.sh"

{
  echo
  echo "## Result"
  echo
  echo "- Status: passed"
  echo "- Voice clone C2 runtime fault-injection gate: passed"
} >> "$REPORT_PATH"

echo "[voice-clone-c2-runtime-fault-injection-gate] Voice clone C2 runtime fault-injection gate: passed"
echo "[voice-clone-c2-runtime-fault-injection-gate] Report: $REPORT_PATH"

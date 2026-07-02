#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../../.." && pwd)"

RUN_ID="${RUN_ID:-$(date +%Y%m%d-%H%M%S)-digital-human-voice-clone-combo}"
OUTPUT_ROOT="${OUTPUT_ROOT:-$ROOT_DIR/tmp/visual-qa/prd-stitch-ui/digital-human-voice-clone-combo-gate}"
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
  echo "[digital-human-voice-clone-combo-gate] $*" >&2
  exit 1
}

run_gate() {
  local title="$1"
  local subdir="$2"
  shift 2
  echo "[digital-human-voice-clone-combo-gate] Running $title..."
  {
    echo
    echo "## $title"
    echo
    echo "- Output: \`$subdir/$RUN_ID/\`"
  } >> "$REPORT_PATH"
  RUN_ID="$RUN_ID" OUTPUT_ROOT="$OUTPUT_DIR/$subdir" "$@" || fail "$title failed"
}

cat > "$REPORT_PATH" <<REPORT
# Digital human + voice clone combo gate

- Run ID: \`$RUN_ID\`
- Output dir: \`$OUTPUT_DIR\`

This non-device gate verifies the deployable chain before true-device QA:

1. Backend Tencent digital-human session contract.
2. Backend voice-clone deployed synthesis contract.
3. iOS voice-clone synthesis runtime contract.
4. Tencent backend PCM-drive mock path and stop/interruption cleanup.

REPORT

run_gate \
  "Backend digital-human session smoke" \
  "backend-digital-human-session-smoke" \
  "$SCRIPT_DIR/run-backend-digital-human-session-smoke.sh"

run_gate \
  "Backend voice clone deployed smoke" \
  "backend-voice-clone-deployed-smoke" \
  "$SCRIPT_DIR/run-backend-voice-clone-deployed-smoke.sh"

run_gate \
  "Voice clone synthesis runtime smoke" \
  "voice-clone-synthesis-runtime-smoke" \
  env DERIVED_DATA_PATH="$OUTPUT_DIR/DerivedDataVoiceCloneSynthesisRuntimeSmoke" \
  "$SCRIPT_DIR/run-voice-clone-synthesis-runtime-smoke.sh"

run_gate \
  "Tencent backend PCM-drive mock smoke" \
  "tencent-backend-pcm-drive-mock-smoke" \
  env DERIVED_DATA_PATH="$OUTPUT_DIR/DerivedDataTencentBackendPCMDriveMockSmoke" \
  "$SCRIPT_DIR/run-tencent-backend-pcm-drive-mock-smoke.sh"

{
  echo
  echo "## Result"
  echo
  echo "- Status: passed"
  echo "- Digital human + voice clone combo gate: passed"
} >> "$REPORT_PATH"

echo "[digital-human-voice-clone-combo-gate] Digital human + voice clone combo gate: passed"
echo "[digital-human-voice-clone-combo-gate] Report: $REPORT_PATH"

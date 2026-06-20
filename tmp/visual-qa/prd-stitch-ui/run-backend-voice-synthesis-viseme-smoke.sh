#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../../.." && pwd)"
WORKSPACE_ROOT="$(cd "$ROOT_DIR/.." && pwd)"
BACKEND_ROOT="${BACKEND_ROOT:-$WORKSPACE_ROOT/DreamJourneyBackend}"

RUN_ID="${RUN_ID:-$(date +%Y%m%d-%H%M%S)-backend-voice-synthesis-viseme}"
OUTPUT_ROOT="${OUTPUT_ROOT:-$ROOT_DIR/tmp/visual-qa/prd-stitch-ui/backend-voice-synthesis-viseme-smoke}"
OUTPUT_DIR="$OUTPUT_ROOT/$RUN_ID"
RESULT_PATH="$OUTPUT_DIR/backend-voice-synthesis-viseme-smoke-result.json"
LOG_PATH="$OUTPUT_DIR/backend-voice-synthesis-viseme-smoke.log"
REPORT_PATH="$OUTPUT_DIR/report.md"

mkdir -p "$OUTPUT_DIR"

fail() {
  local reason="$1"
  cat > "$REPORT_PATH" <<EOF
# Backend Voice Synthesis Viseme Smoke

Run ID: \`$RUN_ID\`

Status: failed

Reason: $reason

## Evidence

- Result JSON: \`backend-voice-synthesis-viseme-smoke-result.json\`
- Log: \`backend-voice-synthesis-viseme-smoke.log\`

EOF
  echo "[BACKEND_VOICE_SYNTHESIS_VISEME_SMOKE] $reason" >&2
  if [[ -s "$LOG_PATH" ]]; then
    tail -100 "$LOG_PATH" >&2 || true
  fi
  exit 1
}

[[ -d "$BACKEND_ROOT" ]] || fail "Backend root not found: $BACKEND_ROOT"

PYTHON_BIN="${PYTHON_BIN:-python3}"
if [[ -x "$BACKEND_ROOT/.venv/bin/python" ]]; then
  PYTHON_BIN="$BACKEND_ROOT/.venv/bin/python"
fi

echo "[BACKEND_VOICE_SYNTHESIS_VISEME_SMOKE] Running local FastAPI mock provider smoke..."
if ! "$PYTHON_BIN" "$SCRIPT_DIR/backend-voice-synthesis-viseme-smoke.py" "$ROOT_DIR" "$BACKEND_ROOT" > "$RESULT_PATH" 2> "$LOG_PATH"; then
  fail "Backend voice synthesis viseme smoke failed."
fi

grep -Eq '"completed"[[:space:]]*:[[:space:]]*true' "$RESULT_PATH" \
  || fail "Smoke did not complete."
grep -Eq '"source"[[:space:]]*:[[:space:]]*"providerVisemeTimeline"' "$RESULT_PATH" \
  || fail "providerVisemeTimeline source missing."
grep -Eq '"lipSyncFrameCount"[[:space:]]*:[[:space:]]*[1-9]' "$RESULT_PATH" \
  || fail "Provider timeline should include lip-sync frames."
grep -Eq '"currentMouthShape"[[:space:]]*:[[:space:]]*"(aa|oh|ee|open)"' "$RESULT_PATH" \
  || fail "Provider timeline should expose a non-neutral current mouth shape."
grep -Eq '"missingTimelineFallbackAccepted"[[:space:]]*:[[:space:]]*true' "$RESULT_PATH" \
  || fail "Missing provider timeline fallback contract was not accepted."

python3 - "$RESULT_PATH" "$REPORT_PATH" "$RUN_ID" "$BACKEND_ROOT" <<'PY'
import json
import sys

result_path, report_path, run_id, backend_root = sys.argv[1:5]
with open(result_path, "r", encoding="utf-8") as handle:
    result = json.load(handle)

provider = result.get("providerTimeline") or {}
runtime = result.get("runtimeLipSyncTimeline") or {}
report = f"""# Backend Voice Synthesis Viseme Smoke

Run ID: `{run_id}`

Status: passed

## Scope

- Local FastAPI `/voice/synthesis` smoke with a mock provider returning `visemeTimeline`.
- Local FastAPI `/voice/synthesis` smoke with the provider timeline omitted, preserving the metering fallback contract.
- Runtime contract check for `voiceClone.lipSyncTimeline`.

## Result

- Backend root: `{backend_root}`
- Runtime lip-sync field: `{runtime.get("field")}`
- Runtime fallback mode: `{runtime.get("fallbackMode")}`
- Provider timeline source: `{provider.get("source")}`
- Lip-sync frame count: `{provider.get("lipSyncFrameCount")}`
- Current mouth shape sample: `{provider.get("currentMouthShape")}`
- Missing timeline fallback accepted: `{result.get("missingTimelineFallbackAccepted")}`

## Evidence

- Result JSON: `backend-voice-synthesis-viseme-smoke-result.json`
- Log: `backend-voice-synthesis-viseme-smoke.log`
"""
with open(report_path, "w", encoding="utf-8") as handle:
    handle.write(report)
PY

cat "$RESULT_PATH"
echo
echo "[BACKEND_VOICE_SYNTHESIS_VISEME_SMOKE] Report: $REPORT_PATH"

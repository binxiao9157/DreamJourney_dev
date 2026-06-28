#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../../.." && pwd)"

RUN_ID="${RUN_ID:-$(date +%Y%m%d-%H%M%S)-digital-human-tts-viseme-gate}"
OUTPUT_ROOT="${OUTPUT_ROOT:-$ROOT_DIR/tmp/visual-qa/prd-stitch-ui/digital-human-tts-viseme-gate}"
OUTPUT_DIR="$OUTPUT_ROOT/$RUN_ID"
REPORT_PATH="$OUTPUT_DIR/report.md"
COMMAND_LOG="$OUTPUT_DIR/commands.log"
RESULT_PATH="$OUTPUT_DIR/digital-human-tts-viseme-gate-result.json"

mkdir -p "$OUTPUT_DIR"
touch "$COMMAND_LOG"

fail() {
  local reason="$1"
  cat > "$REPORT_PATH" <<EOF
# Digital Human TTS / Viseme Gate

Run ID: \`$RUN_ID\`

Status: failed

Reason: $reason

## Evidence

- Command log: \`commands.log\`
- Result JSON: \`digital-human-tts-viseme-gate-result.json\`
- Backend smoke: \`backend-voice-synthesis-viseme-smoke/$RUN_ID/\`
- Provider timeline UIQA: \`digital-human-live-panel-smoke/$RUN_ID-provider-viseme/\`
- Metering fallback UIQA: \`digital-human-live-panel-smoke/$RUN_ID-metering-fallback/\`

EOF
  echo "[DIGITAL_HUMAN_TTS_VISEME_GATE] $reason" >&2
  exit 1
}

run_step() {
  local name="$1"
  shift
  echo "== $name ==" | tee -a "$COMMAND_LOG"
  echo "$*" >> "$COMMAND_LOG"
  "$@"
}

BACKEND_RESULT="$OUTPUT_DIR/backend-voice-synthesis-viseme-smoke/$RUN_ID/backend-voice-synthesis-viseme-smoke-result.json"
PROVIDER_RESULT="$OUTPUT_DIR/digital-human-live-panel-smoke/$RUN_ID-provider-viseme/digital-human-live-panel-smoke-result.json"
FALLBACK_RESULT="$OUTPUT_DIR/digital-human-live-panel-smoke/$RUN_ID-metering-fallback/digital-human-live-panel-smoke-result.json"

run_step "Backend mock voice synthesis viseme smoke" \
  env RUN_ID="$RUN_ID" \
    OUTPUT_ROOT="$OUTPUT_DIR/backend-voice-synthesis-viseme-smoke" \
    "$SCRIPT_DIR/run-backend-voice-synthesis-viseme-smoke.sh"

run_step "Digital human provider viseme timeline UIQA smoke" \
  env RUN_ID="$RUN_ID-provider-viseme" \
    OUTPUT_ROOT="$OUTPUT_DIR/digital-human-live-panel-smoke" \
    DERIVED_DATA_PATH="$OUTPUT_DIR/DerivedDataDigitalHumanProviderViseme" \
    DIGITAL_HUMAN_LIPSYNC_MODE=providerVisemeTimeline \
    "$SCRIPT_DIR/run-digital-human-live-panel-smoke.sh"

run_step "Digital human AVAudioPlayer metering fallback UIQA smoke" \
  env RUN_ID="$RUN_ID-metering-fallback" \
    OUTPUT_ROOT="$OUTPUT_DIR/digital-human-live-panel-smoke" \
    DERIVED_DATA_PATH="$OUTPUT_DIR/DerivedDataDigitalHumanMeteringFallback" \
    DIGITAL_HUMAN_LIPSYNC_MODE=avAudioPlayerMetering \
    "$SCRIPT_DIR/run-digital-human-live-panel-smoke.sh"

python3 - "$BACKEND_RESULT" "$PROVIDER_RESULT" "$FALLBACK_RESULT" "$RESULT_PATH" "$REPORT_PATH" "$RUN_ID" <<'PY'
import json
import sys

backend_path, provider_path, fallback_path, result_path, report_path, run_id = sys.argv[1:7]

def load(path):
    with open(path, "r", encoding="utf-8") as handle:
        return json.load(handle)

backend = load(backend_path)
provider = load(provider_path)
fallback = load(fallback_path)

def require(condition, message):
    if not condition:
        raise AssertionError(message)

require(backend.get("completed") is True, "backend smoke did not complete")
require((backend.get("providerTimeline") or {}).get("lipSyncFrameCount", 0) > 0, "backend provider timeline has no frames")
require(backend.get("missingTimelineFallbackAccepted") is True, "backend missing timeline fallback was not accepted")

require(provider.get("completed") is True, "provider UIQA smoke did not complete")
require(provider.get("lipSyncSource") == "providerVisemeTimeline", "provider UIQA lipSyncSource mismatch")
require(provider.get("audioLevelSource") == "providerVisemeTimeline", "provider UIQA audioLevelSource mismatch")
require(int(provider.get("lipSyncFrameCount") or 0) > 0, "provider UIQA lipSyncFrameCount missing")
require(provider.get("currentMouthShape") not in ("", "neutral", None), "provider UIQA mouth shape did not change")

require(fallback.get("completed") is True, "fallback UIQA smoke did not complete")
require(fallback.get("audioLevelSource") == "avAudioPlayerMetering", "fallback UIQA audioLevelSource mismatch")
require(int(fallback.get("meteringSampleCount") or 0) > 0, "fallback UIQA collected no metering samples")

result = {
    "completed": True,
    "runId": run_id,
    "backend": {
        "providerTimeline": backend.get("providerTimeline"),
        "missingTimelineFallbackAccepted": backend.get("missingTimelineFallbackAccepted"),
    },
    "providerUIQA": {
        "lipSyncSource": provider.get("lipSyncSource"),
        "audioLevelSource": provider.get("audioLevelSource"),
        "lipSyncFrameCount": provider.get("lipSyncFrameCount"),
        "currentMouthShape": provider.get("currentMouthShape"),
    },
    "meteringFallbackUIQA": {
        "audioLevelSource": fallback.get("audioLevelSource"),
        "meteringSampleCount": fallback.get("meteringSampleCount"),
        "currentMouthShape": fallback.get("currentMouthShape"),
    },
}
with open(result_path, "w", encoding="utf-8") as handle:
    json.dump(result, handle, ensure_ascii=False, indent=2)

report = f"""# Digital Human TTS / Viseme Gate

Run ID: `{run_id}`

Status: passed

## Scope

- Backend mock `/voice/synthesis` returns `visemeTimeline`.
- Backend mock `/voice/synthesis` without `visemeTimeline` preserves metering fallback contract.
- iOS UIQA feeds a mock `VoiceCloneSynthesisResult` timeline into the digital-human panel.
- iOS UIQA verifies provider timeline source and AVAudioPlayer metering fallback source.

## Result

- Backend provider frame count: `{(backend.get("providerTimeline") or {}).get("lipSyncFrameCount")}`
- Backend missing timeline fallback accepted: `{backend.get("missingTimelineFallbackAccepted")}`
- Provider UIQA lip-sync source: `{provider.get("lipSyncSource")}`
- Provider UIQA mouth shape: `{provider.get("currentMouthShape")}`
- Metering fallback source: `{fallback.get("audioLevelSource")}`
- Metering sample count: `{fallback.get("meteringSampleCount")}`

## Evidence

- Command log: `commands.log`
- Result JSON: `digital-human-tts-viseme-gate-result.json`
- Backend smoke: `backend-voice-synthesis-viseme-smoke/{run_id}/`
- Provider timeline UIQA: `digital-human-live-panel-smoke/{run_id}-provider-viseme/`
- Metering fallback UIQA: `digital-human-live-panel-smoke/{run_id}-metering-fallback/`
"""
with open(report_path, "w", encoding="utf-8") as handle:
    handle.write(report)
PY

cat "$RESULT_PATH"
echo
echo "[DIGITAL_HUMAN_TTS_VISEME_GATE] Report: $REPORT_PATH"

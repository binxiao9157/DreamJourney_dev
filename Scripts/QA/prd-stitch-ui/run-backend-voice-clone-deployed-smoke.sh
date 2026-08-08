#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../../.." && pwd)"
WORKSPACE_ROOT="$(cd "$ROOT_DIR/.." && pwd)"
BACKEND_ROOT="${BACKEND_ROOT:-$WORKSPACE_ROOT/DreamJourneyBackend}"

RUN_ID="${RUN_ID:-$(date +%Y%m%d-%H%M%S)-backend-voice-clone-deployed}"
MARKER="${MARKER:-$RUN_ID}"
USER_ID="${USER_ID:-voice_clone_${RUN_ID//[^A-Za-z0-9]/_}}"
OUTPUT_ROOT="${OUTPUT_ROOT:-$ROOT_DIR/tmp/visual-qa/prd-stitch-ui/backend-voice-clone-deployed-smoke}"
OUTPUT_DIR="$OUTPUT_ROOT/$RUN_ID"
RESULT_PATH="$OUTPUT_DIR/backend-voice-clone-deployed-smoke-result.json"
LOG_PATH="$OUTPUT_DIR/backend-voice-clone-deployed-smoke.log"
REPORT_PATH="$OUTPUT_DIR/report.md"

mkdir -p "$OUTPUT_DIR"

log() {
  echo "[BACKEND_VOICE_CLONE_DEPLOYED_SMOKE] $*"
}

xcconfig_value() {
  local key="$1"
  local file="$2"
  [[ -f "$file" ]] || return 0
  awk -F= -v key="$key" '
    $0 !~ /^[[:space:]]*\/\// && $1 ~ "^[[:space:]]*" key "[[:space:]]*$" {
      value=$2
      sub(/[[:space:]]*\/\/.*/, "", value)
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", value)
      print value
      exit
    }
  ' "$file"
}

normalize_xcconfig_url() {
  local value="${1:-}"
  value="${value//:\/\$()\//:\/\/}"
  printf '%s' "$value"
}

fail() {
  local reason="$1"
  local token_status="not configured"
  local user_token_status="not configured"
  if [[ -n "${BACKEND_API_TOKEN:-}" ]]; then
    token_status="configured, value intentionally omitted"
  fi
  if [[ -n "${BACKEND_USER_ACCESS_TOKEN:-}" ]]; then
    user_token_status="configured, value intentionally omitted"
  fi
  cat > "$REPORT_PATH" <<EOF
# Backend Voice Clone Deployed Smoke

Run ID: \`$RUN_ID\`

Status: blocked

Reason: $reason

## Environment

- Backend root: \`$BACKEND_ROOT\`
- Backend base URL: \`${BACKEND_BASE_URL:-not configured}\`
- Backend API token: $token_status
- Backend user access token: $user_token_status
- Ready voice profile: \`${VOICE_CLONE_READY_PROFILE_ID:-not configured}\`
- Ready voice profile owner: \`${VOICE_CLONE_READY_PROFILE_USER_ID:-not configured}\`
- Non-ready diagnostic voice profile: \`${VOICE_CLONE_NON_READY_PROFILE_ID:-not configured}\`
- User ID: \`$USER_ID\`

## Evidence

- Result JSON: \`backend-voice-clone-deployed-smoke-result.json\`
- Log: \`backend-voice-clone-deployed-smoke.log\`

EOF
  echo "[BACKEND_VOICE_CLONE_DEPLOYED_SMOKE] $reason" >&2
  if [[ -s "$LOG_PATH" ]]; then
    tail -80 "$LOG_PATH" >&2 || true
  fi
  exit 1
}

resolve_deployed_backend_config() {
  python3 - "$BACKEND_ROOT" "${DEPLOYED_BACKEND_ACCESS_DOC:-}" <<'PY'
import re
import sys
from pathlib import Path

backend_root = Path(sys.argv[1])
explicit = sys.argv[2].strip()
candidates = []
if explicit:
    candidates.append(Path(explicit))
candidates.extend([
    backend_root / "private/deployed-backend-access.md",
    backend_root / "deployed-backend-access.md",
])

for path in candidates:
    if not path.exists():
        continue
    content = path.read_text(encoding="utf-8")
    base_url = ""
    token = ""
    for line in content.splitlines():
        stripped = line.strip()
        if stripped.startswith("DreamJourneyBackendBaseURL="):
            base_url = stripped.split("=", 1)[1].strip().strip("'\"")
        elif stripped.startswith("BACKEND_API_TOKEN="):
            token = stripped.split("=", 1)[1].strip().strip("'\"")
        elif stripped.startswith("DreamJourneyBackendAPIToken=") and not token:
            token = stripped.split("=", 1)[1].strip().strip("'\"")
    if not base_url:
        match = re.search(r"https?://[A-Za-z0-9._~:/?#\[\]@!$&'()*+,;=%-]+", content)
        base_url = match.group(0).rstrip("/,") if match else ""
    if base_url or token:
        print(f"base_url={base_url}")
        print(f"token={token}")
        raise SystemExit(0)

raise SystemExit(0)
PY
}

BACKEND_XCCONFIG="$ROOT_DIR/DreamJourney/Config/Backend.local.xcconfig"
XCCONFIG_BASE_URL="$(normalize_xcconfig_url "$(xcconfig_value DREAMJOURNEY_BACKEND_BASE_URL "$BACKEND_XCCONFIG")")"
XCCONFIG_API_TOKEN="$(xcconfig_value DREAMJOURNEY_BACKEND_API_TOKEN "$BACKEND_XCCONFIG")"

CONFIG_OUTPUT="$(resolve_deployed_backend_config || true)"
DOC_BASE_URL="$(printf '%s\n' "$CONFIG_OUTPUT" | awk -F= '/^base_url=/{print substr($0, 10); exit}')"
DOC_API_TOKEN="$(printf '%s\n' "$CONFIG_OUTPUT" | awk -F= '/^token=/{print substr($0, 7); exit}')"

BACKEND_BASE_URL="${BACKEND_BASE_URL:-${XCCONFIG_BASE_URL:-$DOC_BASE_URL}}"
BACKEND_API_TOKEN="${BACKEND_API_TOKEN:-${XCCONFIG_API_TOKEN:-$DOC_API_TOKEN}}"

[[ -n "$BACKEND_BASE_URL" ]] || fail "BACKEND_BASE_URL is required. Export it, configure Backend.local.xcconfig, or provide deployed-backend-access.md."
[[ -n "$BACKEND_API_TOKEN" ]] || fail "BACKEND_API_TOKEN is required. Export it, configure Backend.local.xcconfig, or provide deployed-backend-access.md."
[[ "$BACKEND_API_TOKEN" != YOUR_* ]] || fail "BACKEND_API_TOKEN is still a placeholder."
[[ -n "${BACKEND_USER_ACCESS_TOKEN:-}" ]] || fail "BACKEND_USER_ACCESS_TOKEN is required. Use a short-lived access token for VOICE_CLONE_READY_PROFILE_USER_ID; the machine token cannot authorize user-owned voice routes."
[[ -n "${VOICE_CLONE_READY_PROFILE_ID:-}" ]] || fail "VOICE_CLONE_READY_PROFILE_ID is required because trial voice slots can expire or exhaust training attempts."
[[ -n "${VOICE_CLONE_READY_PROFILE_USER_ID:-}" ]] || fail "VOICE_CLONE_READY_PROFILE_USER_ID is required because synthesis now enforces persisted profile ownership."

log "Running deployed backend voice clone smoke against $BACKEND_BASE_URL..."
if ! BACKEND_BASE_URL="$BACKEND_BASE_URL" \
    BACKEND_API_TOKEN="$BACKEND_API_TOKEN" \
    BACKEND_USER_ACCESS_TOKEN="$BACKEND_USER_ACCESS_TOKEN" \
    VOICE_CLONE_READY_PROFILE_ID="$VOICE_CLONE_READY_PROFILE_ID" \
    VOICE_CLONE_READY_PROFILE_USER_ID="$VOICE_CLONE_READY_PROFILE_USER_ID" \
    VOICE_CLONE_NON_READY_PROFILE_ID="${VOICE_CLONE_NON_READY_PROFILE_ID:-}" \
    VOICE_CLONE_NON_READY_PROFILE_USER_ID="${VOICE_CLONE_NON_READY_PROFILE_USER_ID:-}" \
    python3 "$SCRIPT_DIR/backend-voice-clone-deployed-smoke.py" \
      "$ROOT_DIR" \
      "$USER_ID" \
      "$MARKER" > "$RESULT_PATH" 2> "$LOG_PATH"; then
  fail "Backend voice clone deployed smoke failed. See backend-voice-clone-deployed-smoke.log."
fi

python3 - "$RESULT_PATH" "$REPORT_PATH" "$RUN_ID" "$BACKEND_BASE_URL" "$USER_ID" <<'PY'
import json
import sys

result_path, report_path, run_id, base_url, user_id = sys.argv[1:6]
with open(result_path, "r", encoding="utf-8") as handle:
    result = json.load(handle)

runtime = result.get("runtimeVoiceClone") or {}
ready = result.get("readyProbe") or {}
ready_synthesis = ready.get("synthesis") or {}
non_ready = result.get("nonReadyProbe") or {}
health = result.get("health") or {}

report = f"""# Backend Voice Clone Deployed Smoke

Run ID: `{run_id}`

Status: passed

## Environment

- Backend base URL: `{base_url}`
- Backend API token: configured, value intentionally omitted
- Backend user access token: configured, value intentionally omitted
- Backend store: `{health.get("store")}`
- User ID: `{user_id}`

## Scope

- `/config/runtime.voiceClone` provider readiness.
- Ready voice profile synthesis through `/voice/synthesis`.
- Tencent audio-drive output mode: `tencentAudioDrive`.
- PCM contract: `pcm16kMono`, 16kHz, 16-bit, mono.
- Non-ready voice diagnostic path when configured.
- Raw audio data is not written to the report; result JSON marks `audioDataOmitted=true`.

## Runtime

- Provider: `{runtime.get("provider")}`
- Training provider ready: `{runtime.get("realProviderReady")}`
- Synthesis provider ready: `{runtime.get("synthesisProviderReady")}`
- Speaker ID mode: `{runtime.get("speakerIdMode")}`
- Speaker pool count: `{runtime.get("speakerIdPoolCount")}`
- TTS resource ID: `{runtime.get("ttsResourceId")}`
- Tencent audio-drive supported: `{runtime.get("tencentAudioDriveSupported")}`

## Ready Probe

- Voice profile: `{ready.get("voiceProfileId")}`
- Profile owner: `{ready.get("userId")}`
- Sample status: `{ready.get("sampleStatus")}`
- Provider status: `{ready.get("providerStatus")}`
- Provider log ID: `{ready.get("providerLogId")}`
- Output mode: `{ready_synthesis.get("outputMode")}`
- Audio format: `{ready_synthesis.get("audioFormat")}`
- Byte count: `{ready_synthesis.get("byteCount")}`
- Raw audio omitted: `{ready_synthesis.get("audioDataOmitted")}`

## Non-ready Diagnostic Probe

- Voice profile: `{non_ready.get("voiceProfileId")}`
- Sample status: `{non_ready.get("sampleStatus")}`
- Provider status: `{non_ready.get("providerStatus")}`
- Provider log ID: `{non_ready.get("providerLogId")}`
- Diagnostic failure: `{non_ready.get("diagnosticFailure")}`

## Evidence

- Result JSON: `backend-voice-clone-deployed-smoke-result.json`
- Log: `backend-voice-clone-deployed-smoke.log`

"""
with open(report_path, "w", encoding="utf-8") as handle:
    handle.write(report)
PY

log "Result: $RESULT_PATH"
log "Report: $REPORT_PATH"

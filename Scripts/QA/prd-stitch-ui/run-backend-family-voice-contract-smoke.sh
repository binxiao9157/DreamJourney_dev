#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../../.." && pwd)"
WORKSPACE_ROOT="$(cd "$ROOT_DIR/.." && pwd)"
BACKEND_ROOT="${BACKEND_ROOT:-$WORKSPACE_ROOT/DreamJourneyBackend}"

RUN_ID="${RUN_ID:-$(date +%Y%m%d-%H%M%S)-backend-family-voice-contract}"
MARKER="${MARKER:-$RUN_ID}"
USER_ID="${USER_ID:-family_voice_${RUN_ID//[^A-Za-z0-9]/_}}"
OUTPUT_ROOT="${OUTPUT_ROOT:-$ROOT_DIR/tmp/visual-qa/prd-stitch-ui/backend-family-voice-contract-smoke}"
OUTPUT_DIR="$OUTPUT_ROOT/$RUN_ID"
RESULT_PATH="$OUTPUT_DIR/backend-family-voice-contract-smoke-result.json"
LOG_PATH="$OUTPUT_DIR/backend-family-voice-contract-smoke.log"
REPORT_PATH="$OUTPUT_DIR/report.md"

mkdir -p "$OUTPUT_DIR"

log() {
  echo "[BACKEND_FAMILY_VOICE_CONTRACT_SMOKE] $*"
}

fail() {
  local reason="$1"
  local token_status="not configured"
  if [[ -n "${BACKEND_API_TOKEN:-}" ]]; then
    token_status="configured, value intentionally omitted"
  fi
  cat > "$REPORT_PATH" <<EOF
# Backend Family / Voice Contract Smoke

Run ID: \`$RUN_ID\`

Status: blocked

Reason: $reason

## Environment

- Backend root: \`$BACKEND_ROOT\`
- Backend base URL: \`${BACKEND_BASE_URL:-not configured}\`
- Backend API token: $token_status
- User ID: \`$USER_ID\`

## Evidence

- Result JSON: \`backend-family-voice-contract-smoke-result.json\`
- Log: \`backend-family-voice-contract-smoke.log\`

EOF
  echo "[BACKEND_FAMILY_VOICE_CONTRACT_SMOKE] $reason" >&2
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

CONFIG_OUTPUT="$(resolve_deployed_backend_config || true)"
DOC_BASE_URL="$(printf '%s\n' "$CONFIG_OUTPUT" | awk -F= '/^base_url=/{print substr($0, 10); exit}')"
DOC_API_TOKEN="$(printf '%s\n' "$CONFIG_OUTPUT" | awk -F= '/^token=/{print substr($0, 7); exit}')"

BACKEND_BASE_URL="${BACKEND_BASE_URL:-$DOC_BASE_URL}"
BACKEND_API_TOKEN="${BACKEND_API_TOKEN:-$DOC_API_TOKEN}"

[[ -n "$BACKEND_BASE_URL" ]] || fail "BACKEND_BASE_URL is required. Export it or provide deployed-backend-access.md."
[[ -n "$BACKEND_API_TOKEN" ]] || fail "BACKEND_API_TOKEN is required. Export it or provide deployed-backend-access.md."

log "Running deployed backend family/voice contract smoke against $BACKEND_BASE_URL..."
if ! BACKEND_BASE_URL="$BACKEND_BASE_URL" \
    BACKEND_API_TOKEN="$BACKEND_API_TOKEN" \
    python3 "$SCRIPT_DIR/backend-family-voice-contract-smoke.py" \
      "$ROOT_DIR" \
      "$USER_ID" \
      "$MARKER" > "$RESULT_PATH" 2> "$LOG_PATH"; then
  fail "Backend family/voice contract smoke failed. See backend-family-voice-contract-smoke.log."
fi

python3 - "$RESULT_PATH" "$REPORT_PATH" "$RUN_ID" "$BACKEND_BASE_URL" "$USER_ID" <<'PY'
import json
import sys

result_path, report_path, run_id, base_url, user_id = sys.argv[1:6]
with open(result_path, "r", encoding="utf-8") as handle:
    result = json.load(handle)

health = result.get("health") or {}
runtime_archive = result.get("runtimeArchive") or {}
voice = result.get("voiceProfileLifecycle") or {}
family_modes = result.get("listedFamilyModes") or []

report = f"""# Backend Family / Voice Contract Smoke

Run ID: `{run_id}`

Status: passed

## Environment

- Backend base URL: `{base_url}`
- Backend API token: configured, value intentionally omitted
- Backend store: `{health.get("store")}`
- User ID: `{user_id}`
- Runtime media provider: `{runtime_archive.get("storageProvider")}`
- Runtime provider mode: `{runtime_archive.get("providerMode")}`

## Scope

- family digital-human deployed contract: `/family/invite` and `/family/members/{{userId}}`.
- voice profile lifecycle deployed contract: `/voice/profiles`, disable, and delete.
- Verifies `sunlight/阳光`, `star/星辰`, and `silent/静默` are persisted and listed.
- Verifies invalid `digitalHumanMode` is rejected.
- Verifies voice clone shell remains a hidden mock contract with no public release visibility.

## Evidence

- Result JSON: `backend-family-voice-contract-smoke-result.json`
- Log: `backend-family-voice-contract-smoke.log`
- Family modes: `{family_modes}`
- Voice lifecycle: created=`{voice.get("created")}`, listed=`{voice.get("listed")}`, disabled=`{voice.get("disabled")}`, deleted=`{voice.get("deleted")}`

"""
with open(report_path, "w", encoding="utf-8") as handle:
    handle.write(report)
PY

log "Result: $RESULT_PATH"
log "Report: $REPORT_PATH"

#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../../.." && pwd)"
WORKSPACE_ROOT="$(cd "$ROOT_DIR/.." && pwd)"
BACKEND_ROOT="${BACKEND_ROOT:-$WORKSPACE_ROOT/DreamJourneyBackend}"

RUN_ID="${RUN_ID:-$(date +%Y%m%d-%H%M%S)-backend-digital-human-session}"
MARKER="${MARKER:-$RUN_ID}"
USER_ID="${USER_ID:-digital_human_${RUN_ID//[^A-Za-z0-9]/_}}"
OUTPUT_ROOT="${OUTPUT_ROOT:-$ROOT_DIR/tmp/visual-qa/prd-stitch-ui/backend-digital-human-session-smoke}"
OUTPUT_DIR="$OUTPUT_ROOT/$RUN_ID"
RESULT_PATH="$OUTPUT_DIR/backend-digital-human-session-smoke-result.json"
LOG_PATH="$OUTPUT_DIR/backend-digital-human-session-smoke.log"
REPORT_PATH="$OUTPUT_DIR/report.md"

mkdir -p "$OUTPUT_DIR"

log() {
  echo "[BACKEND_DIGITAL_HUMAN_SESSION_SMOKE] $*"
}

fail() {
  local reason="$1"
  local token_status="not configured"
  if [[ -n "${BACKEND_API_TOKEN:-}" ]]; then
    token_status="configured, value intentionally omitted"
  fi
  cat > "$REPORT_PATH" <<EOF
# Backend Digital Human Session Smoke

Run ID: \`$RUN_ID\`

Status: blocked

Reason: $reason

## Environment

- Backend root: \`$BACKEND_ROOT\`
- Backend base URL: \`${BACKEND_BASE_URL:-not configured}\`
- Backend API token: $token_status
- User ID: \`$USER_ID\`

## Evidence

- Result JSON: \`backend-digital-human-session-smoke-result.json\`
- Log: \`backend-digital-human-session-smoke.log\`

EOF
  echo "[BACKEND_DIGITAL_HUMAN_SESSION_SMOKE] $reason" >&2
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

log "Running deployed backend digital-human session smoke against $BACKEND_BASE_URL..."
if ! BACKEND_BASE_URL="$BACKEND_BASE_URL" \
    BACKEND_API_TOKEN="$BACKEND_API_TOKEN" \
    python3 "$SCRIPT_DIR/backend-digital-human-session-smoke.py" \
      "$USER_ID" \
      "$MARKER" > "$RESULT_PATH" 2> "$LOG_PATH"; then
  fail "Backend digital-human session smoke failed. See backend-digital-human-session-smoke.log."
fi

python3 - "$RESULT_PATH" "$REPORT_PATH" "$RUN_ID" "$BACKEND_BASE_URL" "$USER_ID" <<'PY'
import json
import sys

result_path, report_path, run_id, base_url, user_id = sys.argv[1:6]
with open(result_path, "r", encoding="utf-8") as handle:
    result = json.load(handle)

health = result.get("health") or {}
runtime = result.get("runtimeDigitalHuman") or {}
session = result.get("session") or {}

report = f"""# Backend Digital Human Session Smoke

Run ID: `{run_id}`

Status: passed

## Environment

- Backend base URL: `{base_url}`
- Backend API token: configured, value intentionally omitted
- Backend store: `{health.get("store")}`
- User ID: `{user_id}`

## Scope

- `/config/runtime.digitalHuman` reports the scoped credential broker as unavailable.
- `/digital-human/sessions` fails closed with `digital_human_credential_broker_unavailable`.
- Runtime and session responses are value-free and carry `Cache-Control: no-store`.
- Static Tencent appkey/accesstoken values are never returned to iOS.
- Blocked requests do not allocate or reuse a digital-human lease.
- `silent` lifecycle mode is rejected before render session creation.
- Backend runtime keeps `defaultReleaseVisible=false` and explicitly degrades to text Echo.

## Evidence

- Result JSON: `backend-digital-human-session-smoke-result.json`
- Log: `backend-digital-human-session-smoke.log`
- Runtime provider mode: `{runtime.get("providerMode")}`
- Runtime credential mode: `{runtime.get("credentialMode")}`
- Runtime credential broker status: `{runtime.get("credentialBrokerStatus")}`
- Runtime fallback mode: `{runtime.get("fallbackMode")}`
- Runtime SDK adapter linked: `{runtime.get("sdkAdapterLinked")}`
- Runtime session lease enabled: `{runtime.get("sessionLeaseEnabled")}`
- Runtime session lease TTL seconds: `{runtime.get("sessionLeaseTTLSeconds")}`
- Session status: `{session.get("status")}`
- Session blocked code: `{session.get("code")}`
- Session credential mode: `{session.get("credentialMode")}`
- Session provider ready: `{session.get("providerReady")}`
- Session release visible: `{session.get("releaseVisible")}`
- Session fallback mode: `{session.get("fallbackMode")}`
- Session response no-store: `{session.get("responseNoStore")}`
- Session response value-free: `{session.get("valueFree")}`
- Repeated request stayed blocked: `{session.get("repeatedRequestStayedBlocked")}`
- Silent mode rejected: `{result.get("silentModeRejected")}`

"""
with open(report_path, "w", encoding="utf-8") as handle:
    handle.write(report)
PY

log "Result: $RESULT_PATH"
log "Report: $REPORT_PATH"

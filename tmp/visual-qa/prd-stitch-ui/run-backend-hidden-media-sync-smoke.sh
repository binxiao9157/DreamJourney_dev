#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../../.." && pwd)"
WORKSPACE_ROOT="$(cd "$ROOT_DIR/.." && pwd)"
BACKEND_ROOT="${BACKEND_ROOT:-$WORKSPACE_ROOT/DreamJourneyBackend}"

RUN_ID="${RUN_ID:-$(date +%Y%m%d-%H%M%S)-backend-hidden-media-sync}"
MARKER="${MARKER:-$RUN_ID}"
USER_ID="${USER_ID:-hidden_media_sync_${RUN_ID//[^A-Za-z0-9]/_}}"
OUTPUT_ROOT="${OUTPUT_ROOT:-$ROOT_DIR/tmp/visual-qa/prd-stitch-ui/backend-hidden-media-sync-smoke}"
OUTPUT_DIR="$OUTPUT_ROOT/$RUN_ID"
RESULT_PATH="$OUTPUT_DIR/backend-hidden-media-sync-smoke-result.json"
LOG_PATH="$OUTPUT_DIR/backend-hidden-media-sync-smoke.log"
REPORT_PATH="$OUTPUT_DIR/report.md"

mkdir -p "$OUTPUT_DIR"

log() {
  echo "[BACKEND_HIDDEN_MEDIA_SYNC_SMOKE] $*"
}

fail() {
  local reason="$1"
  local token_status="not configured"
  if [[ -n "${BACKEND_API_TOKEN:-}" ]]; then
    token_status="configured, value intentionally omitted"
  fi
  cat > "$REPORT_PATH" <<EOF
# Backend Hidden Media Sync Smoke

Run ID: \`$RUN_ID\`

Status: blocked

Reason: $reason

## Environment

- Backend root: \`$BACKEND_ROOT\`
- Backend base URL: \`${BACKEND_BASE_URL:-not configured}\`
- Backend API token: $token_status
- User ID: \`$USER_ID\`

## Evidence

- Result JSON: \`backend-hidden-media-sync-smoke-result.json\`
- Log: \`backend-hidden-media-sync-smoke.log\`

EOF
  echo "[BACKEND_HIDDEN_MEDIA_SYNC_SMOKE] $reason" >&2
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

log "Running hidden media sync smoke against $BACKEND_BASE_URL..."
if ! BACKEND_BASE_URL="$BACKEND_BASE_URL" \
    BACKEND_API_TOKEN="$BACKEND_API_TOKEN" \
    python3 "$SCRIPT_DIR/backend-hidden-media-sync-smoke.py" \
      "$ROOT_DIR" \
      "$USER_ID" \
      "$MARKER" > "$RESULT_PATH" 2> "$LOG_PATH"; then
  fail "Backend hidden media sync smoke failed. See backend-hidden-media-sync-smoke.log."
fi

python3 - "$RESULT_PATH" "$REPORT_PATH" "$RUN_ID" "$BACKEND_BASE_URL" "$USER_ID" <<'PY'
import json
import sys

result_path, report_path, run_id, base_url, user_id = sys.argv[1:6]
with open(result_path, "r", encoding="utf-8") as handle:
    result = json.load(handle)

health = result.get("health") or {}
runtime_archive = result.get("runtimeArchive") or {}
audio = result.get("listedAudio") or {}
video = result.get("listedVideo") or {}
letter = result.get("listedTimeLetter") or {}
audio_metadata = audio.get("metadata") or {}
video_metadata = video.get("metadata") or {}
letter_metadata = letter.get("metadata") or {}

report = f"""# Backend Hidden Media Sync Smoke

Run ID: `{run_id}`

Status: passed

## Environment

- Backend base URL: `{base_url}`
- Backend API token: configured, value intentionally omitted
- User ID: `{user_id}`
- Backend store: `{health.get("store")}`
- Runtime media provider: `{runtime_archive.get("storageProvider")}`
- Runtime provider mode: `{runtime_archive.get("providerMode")}`
- Runtime requires client upload: `{runtime_archive.get("requiresClientUpload")}`

## Scope

- Mock audio payload -> `/archive/media/upload-intent` -> `/archive/items` -> `GET /archive/items/{{userId}}`
- Mock video payload -> `/archive/media/upload-intent` -> `/archive/items` -> `GET /archive/items/{{userId}}`
- `/config/runtime.archive` provider switch contract for mockObjectStorage vs future object storage provider.
- Time-letter sealed payload -> `/archive/items` -> `GET /archive/items/{{userId}}`
- Verifies field roundtrip for upload object metadata, transcript, thumbnail object key, and delivery metadata.
- Verifies privacy filtering for local/raw media paths before payloads are treated as backend-visible contracts.

## Evidence

- Result JSON: `backend-hidden-media-sync-smoke-result.json`
- Log: `backend-hidden-media-sync-smoke.log`
- Created IDs: `{result.get("createdIds")}`
- Audio uploadStatus: `{audio_metadata.get("uploadStatus")}`
- Audio objectKey present: `{bool(audio_metadata.get("objectKey"))}`
- Video uploadStatus: `{video_metadata.get("uploadStatus")}`
- Video thumbnailObjectKey present: `{bool(video.get("thumbnailObjectKey"))}`
- Time-letter deliveryState: `{letter.get("deliveryState")}`
- Time-letter deliveryPolicy: `{letter.get("deliveryPolicy")}`
- Time-letter deliveryStatus: `{letter.get("deliveryStatus")}`
- Time-letter provider state: `{letter_metadata.get("deliveryProviderState")}`

"""
with open(report_path, "w", encoding="utf-8") as handle:
    handle.write(report)
PY

log "Result: $RESULT_PATH"
log "Report: $REPORT_PATH"

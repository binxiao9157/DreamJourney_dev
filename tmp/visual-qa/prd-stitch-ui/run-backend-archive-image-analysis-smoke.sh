#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../../.." && pwd)"
WORKSPACE_ROOT="$(cd "$ROOT_DIR/.." && pwd)"
BACKEND_ROOT="${BACKEND_ROOT:-$WORKSPACE_ROOT/DreamJourneyBackend}"

RUN_ID="${RUN_ID:-$(date +%Y%m%d-%H%M%S)-backend-archive-image-analysis}"
MARKER="${MARKER:-$RUN_ID}"
USER_ID="${USER_ID:-archive_image_analysis_${RUN_ID//[^A-Za-z0-9]/_}}"
OUTPUT_ROOT="${OUTPUT_ROOT:-$ROOT_DIR/tmp/visual-qa/prd-stitch-ui/backend-archive-image-analysis-smoke}"
OUTPUT_DIR="$OUTPUT_ROOT/$RUN_ID"
RESULT_PATH="$OUTPUT_DIR/backend-archive-image-analysis-smoke-result.json"
LOG_PATH="$OUTPUT_DIR/backend-archive-image-analysis-smoke.log"
REPORT_PATH="$OUTPUT_DIR/report.md"
IMAGE_PATH="${IMAGE_PATH:-$ROOT_DIR/DreamJourney/Assets.xcassets/default_memory_1.imageset/memory.jpg}"

mkdir -p "$OUTPUT_DIR"

log() {
  echo "[BACKEND_ARCHIVE_IMAGE_ANALYSIS_SMOKE] $*"
}

fail() {
  local reason="$1"
  local token_status="not configured"
  if [[ -n "${BACKEND_API_TOKEN:-}" ]]; then
    token_status="configured, value intentionally omitted"
  fi
  cat > "$REPORT_PATH" <<EOF
# Backend Archive Image Analysis Smoke

Run ID: \`$RUN_ID\`

Status: blocked

Reason: $reason

## Environment

- Backend root: \`$BACKEND_ROOT\`
- Backend base URL: \`${BACKEND_BASE_URL:-not configured}\`
- Backend API token: $token_status
- User ID: \`$USER_ID\`
- Image fixture: \`$IMAGE_PATH\`

## Evidence

- Result JSON: \`backend-archive-image-analysis-smoke-result.json\`
- Log: \`backend-archive-image-analysis-smoke.log\`

EOF
  echo "[BACKEND_ARCHIVE_IMAGE_ANALYSIS_SMOKE] $reason" >&2
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
[[ -f "$IMAGE_PATH" ]] || fail "Image fixture not found: $IMAGE_PATH"

log "Running deployed backend image-analysis smoke against $BACKEND_BASE_URL..."
if ! BACKEND_BASE_URL="$BACKEND_BASE_URL" \
    BACKEND_API_TOKEN="$BACKEND_API_TOKEN" \
    python3 "$SCRIPT_DIR/backend-archive-image-analysis-smoke.py" \
      "$ROOT_DIR" \
      "$USER_ID" \
      "$MARKER" \
      "$IMAGE_PATH" > "$RESULT_PATH" 2> "$LOG_PATH"; then
  fail "Backend archive image-analysis smoke failed. See backend-archive-image-analysis-smoke.log."
fi

python3 - "$RESULT_PATH" "$REPORT_PATH" "$RUN_ID" "$BACKEND_BASE_URL" "$USER_ID" "$IMAGE_PATH" <<'PY'
import json
import sys

result_path, report_path, run_id, base_url, user_id, image_path = sys.argv[1:7]
with open(result_path, "r", encoding="utf-8") as handle:
    result = json.load(handle)

analysis = result.get("analysis_result") or {}
listed = result.get("listed_item") or {}

def count(name):
    value = listed.get(name)
    return len(value) if isinstance(value, list) else 0

report = f"""# Backend Archive Image Analysis Smoke

Run ID: `{run_id}`

Status: passed

## Environment

- Backend base URL: `{base_url}`
- Backend API token: configured, value intentionally omitted
- User ID: `{user_id}`
- Image fixture: `{image_path}`
- Backend store: `{(result.get("health") or {}).get("store")}`

## Scope

- 相册导入 -> /archive/image-analysis -> /archive/items -> GET /archive/items
- Verifies deployed FastAPI/Postgres health.
- Sends the app memory image fixture for real backend image analysis.
- Persists the returned analysis fields through `/archive/items`.
- Re-reads the same archive item and validates structured clue fields.

## Evidence

- Result JSON: `backend-archive-image-analysis-smoke-result.json`
- Log: `backend-archive-image-analysis-smoke.log`
- analysisStatus: `{listed.get("analysisStatus")}`
- detectedPeople count: `{count("detectedPeople")}`
- detectedLocations count: `{count("detectedLocations")}`
- detectedScenes count: `{count("detectedScenes")}`
- tags count: `{count("tags")}`
- analysisFailureReason: `{listed.get("analysisFailureReason")}`
- analysisRetryable: `{listed.get("analysisRetryable")}`

## Returned Clues

- detectedPeople: `{listed.get("detectedPeople")}`
- detectedLocations: `{listed.get("detectedLocations")}`
- detectedScenes: `{listed.get("detectedScenes")}`
- tags: `{listed.get("tags")}`
- summary present: `{bool(analysis.get("analysisSummary"))}`

"""
with open(report_path, "w", encoding="utf-8") as handle:
    handle.write(report)
PY

log "Result: $RESULT_PATH"
log "Report: $REPORT_PATH"

#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../../.." && pwd)"
WORKSPACE_ROOT="$(cd "$ROOT_DIR/.." && pwd)"
BACKEND_ROOT="${BACKEND_ROOT:-$WORKSPACE_ROOT/DreamJourneyBackend}"

RUN_ID="${RUN_ID:-$(date +%Y%m%d-%H%M%S)-backend-time-letter-lifecycle}"
MARKER="${MARKER:-$RUN_ID}"
USER_ID="${USER_ID:-time_letter_lifecycle_${RUN_ID//[^A-Za-z0-9]/_}}"
OUTPUT_ROOT="${OUTPUT_ROOT:-$ROOT_DIR/tmp/visual-qa/prd-stitch-ui/backend-time-letter-lifecycle-smoke}"
OUTPUT_DIR="$OUTPUT_ROOT/$RUN_ID"
RESULT_PATH="$OUTPUT_DIR/backend-time-letter-lifecycle-smoke-result.json"
LOG_PATH="$OUTPUT_DIR/backend-time-letter-lifecycle-smoke.log"
REPORT_PATH="$OUTPUT_DIR/report.md"

mkdir -p "$OUTPUT_DIR"

log() {
  echo "[BACKEND_TIME_LETTER_LIFECYCLE_SMOKE] $*"
}

fail() {
  local reason="$1"
  local token_status="not configured"
  if [[ -n "${BACKEND_API_TOKEN:-}" ]]; then
    token_status="configured, value intentionally omitted"
  fi
  cat > "$REPORT_PATH" <<EOF
# Backend Time Letter Lifecycle Smoke

Run ID: \`$RUN_ID\`

Status: blocked

Reason: $reason

## Environment

- Backend root: \`$BACKEND_ROOT\`
- Backend base URL: \`${BACKEND_BASE_URL:-not configured}\`
- Backend API token: $token_status
- User ID: \`$USER_ID\`

## Evidence

- Result JSON: \`backend-time-letter-lifecycle-smoke-result.json\`
- Log: \`backend-time-letter-lifecycle-smoke.log\`

EOF
  echo "[BACKEND_TIME_LETTER_LIFECYCLE_SMOKE] $reason" >&2
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

log "Running time-letter lifecycle smoke against $BACKEND_BASE_URL..."
if ! BACKEND_BASE_URL="$BACKEND_BASE_URL" \
    BACKEND_API_TOKEN="$BACKEND_API_TOKEN" \
    python3 "$SCRIPT_DIR/backend-time-letter-lifecycle-smoke.py" \
      "$ROOT_DIR" \
      "$USER_ID" \
      "$MARKER" > "$RESULT_PATH" 2> "$LOG_PATH"; then
  fail "Backend time-letter lifecycle smoke failed. See backend-time-letter-lifecycle-smoke.log."
fi

python3 - "$RESULT_PATH" "$REPORT_PATH" "$RUN_ID" "$BACKEND_BASE_URL" "$USER_ID" <<'PY'
import json
import sys

result_path, report_path, run_id, base_url, user_id = sys.argv[1:6]
with open(result_path, "r", encoding="utf-8") as handle:
    result = json.load(handle)

sealed = result.get("listedAfterSeal") or {}
draft_delete_response = result.get("draftDeleteResponse") or {}
sealed_delete_response = result.get("sealedDeleteResponse") or {}
metadata = sealed.get("metadata") or {}
health = result.get("health") or {}
dispatch_due = result.get("dispatchDue") or {}
dispatch_due_repeat = result.get("dispatchDueRepeat") or {}
listed_after_dispatch = result.get("listedAfterDispatch") or {}
listed_future_after_dispatch = result.get("listedFutureAfterDispatch") or {}
owner_mailbox = result.get("ownerMailbox") or []
recipient_mailbox = result.get("recipientMailbox") or []
recipient_detail = result.get("recipientDetail") or {}
owner_detail = result.get("ownerDetail") or {}
future_detail = result.get("futureDetail") or {}
non_recipient_detail = result.get("nonRecipientDetail") or {}
recipient_mailbox_after_read = result.get("recipientMailboxAfterRead") or []
recipient_mailbox_after_archive = result.get("recipientMailboxAfterArchive") or []

report = f"""# Backend Time Letter Lifecycle Smoke

Run ID: `{run_id}`

Status: passed

## Environment

- Backend base URL: `{base_url}`
- Backend API token: configured, value intentionally omitted
- User ID: `{user_id}`
- Health store: `{health.get("store", "unknown")}`

## Contract

- POST draft timeLetter metadata to `/archive/items`.
- POST edited draft with the same `id`; backend must update instead of duplicating.
- DELETE draft `/archive/items/{{userId}}/{{itemId}}`; backend must remove the draft row.
- POST sealed state with the same `id`; backend must preserve exactly one latest row.
- DELETE sealed `/archive/items/{{userId}}/{{itemId}}`; backend must reject with 409.

## Result

- Draft item ID: `{result.get("draftItemId")}`
- Sealed item ID: `{result.get("sealedItemId")}`
- Listed after seal deliveryState: `{sealed.get("deliveryState")}`
- Listed after seal timeLetterStatus: `{metadata.get("timeLetterStatus")}`
- Open at: `{sealed.get("openAt")}`
- Recipients: `{sealed.get("recipients")}`
- Delivery status: `{sealed.get("deliveryStatus")}`
- Draft delete status: `{draft_delete_response.get("status")}`
- Sealed delete detail: `{sealed_delete_response.get("detail")}`
- Listed after sealed delete count: `{result.get("listedAfterSealedDeleteCount")}`
- Dispatch-due status: `{dispatch_due.get("status")}`
- Dispatch-due item/reminder count: `{dispatch_due.get("itemCount")}` / `{dispatch_due.get("reminderCount")}`
- Dispatch-due repeat item/reminder count: `{dispatch_due_repeat.get("itemCount")}` / `{dispatch_due_repeat.get("reminderCount")}`
- Delivered item status: `{listed_after_dispatch.get("deliveryStatus")}`
- Future item status: `{listed_future_after_dispatch.get("deliveryStatus")}`
- Owner mailbox reminder count: `{len(owner_mailbox)}`
- Recipient mailbox reminder count: `{len(recipient_mailbox)}`
- Recipient future mailbox count: `{result.get("recipientFutureMailboxCount")}`
- Recipient user ID: `{result.get("recipientUserId")}`
- Recipient detail status/role: `{recipient_detail.get("status")}` / `{(recipient_detail.get("access") or {}).get("role")}`
- Owner detail role: `{(owner_detail.get("access") or {}).get("role")}`
- Future detail blocked: `{future_detail.get("detail")}`
- Non-recipient detail blocked: `{non_recipient_detail.get("detail")}`
- Recipient mailbox status after read: `{(recipient_mailbox_after_read[0] if recipient_mailbox_after_read else {}).get("status")}`
- Recipient mailbox status after archive: `{(recipient_mailbox_after_archive[0] if recipient_mailbox_after_archive else {}).get("status")}`

## Evidence

- Result JSON: `backend-time-letter-lifecycle-smoke-result.json`
- Log: `backend-time-letter-lifecycle-smoke.log`

"""

with open(report_path, "w", encoding="utf-8") as handle:
    handle.write(report)
PY

log "Report: $REPORT_PATH"

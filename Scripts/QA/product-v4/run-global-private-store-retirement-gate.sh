#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
QA_DIR="$ROOT_DIR/Scripts/QA/product-v4"

ACCOUNT_LEASE_GATE="$QA_DIR/run-account-lease-runtime-gate.sh"
ARCHIVE_WI05_GATE="$QA_DIR/run-archive-local-storage-gate.sh"
CONVERSATION_GATE="$QA_DIR/run-conversation-owner-storage-gate.sh"
MEMOIR_GATE="$QA_DIR/run-memoir-owner-storage-gate.sh"
MEMORY_MAP_GATE="$QA_DIR/run-memory-map-owner-storage-gate.sh"
ACCOUNT_PRIVATE_MEDIA_GATE="$QA_DIR/run-account-private-media-store-gate.sh"
RETIREMENT_STATIC_CHECK="$QA_DIR/global-private-store-retirement-static-check.py"
UIQA_STATIC_CHECK="$QA_DIR/global-private-store-retirement-uiqa-check.py"

missing=0

require_child() {
  local label="$1"
  local path="$2"
  if [[ -f "$path" ]]; then
    return
  fi
  printf 'ERROR: WI-S0-01-06 requires the %s child gate, but it is missing: %s\n' "$label" "$path" >&2
  missing=1
}

require_child "AccountLease WI-S0-01-04" "$ACCOUNT_LEASE_GATE"
require_child "Archive/Media WI-S0-01-05" "$ARCHIVE_WI05_GATE"
require_child "Conversation owner storage" "$CONVERSATION_GATE"
require_child "Memoir owner storage" "$MEMOIR_GATE"
require_child "Memory/Map owner storage" "$MEMORY_MAP_GATE"
require_child "Home account-private media storage" "$ACCOUNT_PRIVATE_MEDIA_GATE"
require_child "global private store retirement static check" "$RETIREMENT_STATIC_CHECK"
require_child "global private store retirement UIQA static check" "$UIQA_STATIC_CHECK"

if (( missing != 0 )); then
  printf 'ERROR: WI-S0-01-06 total gate cannot run until every required child script is present.\n' >&2
  exit 2
fi

printf '[WI-S0-01-06] Running AccountLease prerequisite gate\n'
bash "$ACCOUNT_LEASE_GATE"

printf '[WI-S0-01-06] Running Archive/Media WI-S0-01-05 prerequisite gate\n'
bash "$ARCHIVE_WI05_GATE"

printf '[WI-S0-01-06] Running Conversation owner-storage child gate\n'
bash "$CONVERSATION_GATE"

printf '[WI-S0-01-06] Running Memoir owner-storage child gate\n'
bash "$MEMOIR_GATE"

printf '[WI-S0-01-06] Running Memory/Map owner-storage child gate\n'
bash "$MEMORY_MAP_GATE"

printf '[WI-S0-01-06] Running Home account-private media child gate\n'
bash "$ACCOUNT_PRIVATE_MEDIA_GATE"

printf '[WI-S0-01-06] Running global private store retirement static check\n'
python3 "$RETIREMENT_STATIC_CHECK"

printf '[WI-S0-01-06] Running global private store retirement UIQA static check\n'
python3 "$UIQA_STATIC_CHECK"

printf 'WI-S0-01-06 global private store retirement gate passed\n'

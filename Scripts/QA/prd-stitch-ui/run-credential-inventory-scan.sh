#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../../.." && pwd)"
WORKSPACE_ROOT="$(cd "$ROOT_DIR/.." && pwd)"
BACKEND_ROOT="${BACKEND_ROOT:-$WORKSPACE_ROOT/DreamJourneyBackend}"
SCANNER="$ROOT_DIR/Scripts/QA/product-v4/credential-inventory-scanner.py"
POLICY="$ROOT_DIR/Scripts/QA/product-v4/credential-inventory-policy.json"

RUN_ID="${RUN_ID:-$(date +%Y%m%d-%H%M%S)-credential-inventory}"
OUTPUT_ROOT="${OUTPUT_ROOT:-$ROOT_DIR/tmp/visual-qa/prd-stitch-ui/credential-inventory}"
OUTPUT_DIR="$OUTPUT_ROOT/$RUN_ID"
REPORT_PATH="$OUTPUT_DIR/credential-inventory.json"
CREDENTIAL_SCAN_ENFORCE="${CREDENTIAL_SCAN_ENFORCE:-0}"
CREDENTIAL_SCAN_REQUIRE_RELEASE_ARTIFACTS="${CREDENTIAL_SCAN_REQUIRE_RELEASE_ARTIFACTS:-0}"

mkdir -p "$OUTPUT_DIR"

args=(
  python3 "$SCANNER"
  --policy "$POLICY"
  --surface "SOURCE=$ROOT_DIR"
  --surface "HISTORY=$ROOT_DIR"
  --require-surface SOURCE
  --require-surface HISTORY
  --output "$REPORT_PATH"
)

if [[ -d "$BACKEND_ROOT" ]]; then
  args+=(
    --surface "SOURCE=$BACKEND_ROOT"
    --surface "HISTORY=$BACKEND_ROOT"
    --surface "CONTAINER=$BACKEND_ROOT"
    --require-surface CONTAINER
  )
else
  args+=(--unavailable-surface CONTAINER)
fi

add_roots() {
  local category="$1"
  local raw_roots="$2"
  if [[ -z "$raw_roots" ]]; then
    args+=(--unavailable-surface "$category")
    return
  fi
  local roots=()
  IFS=':' read -r -a roots <<< "$raw_roots"
  local root
  for root in "${roots[@]}"; do
    [[ -n "$root" ]] && args+=(--surface "$category=$root")
  done
}

add_roots APP "${CREDENTIAL_SCAN_APP_ROOTS:-}"
add_roots IPA "${CREDENTIAL_SCAN_IPA_ROOTS:-}"
add_roots DSYM "${CREDENTIAL_SCAN_DSYM_ROOTS:-}"
add_roots RESPONSE "${CREDENTIAL_SCAN_RESPONSE_ROOTS:-}"
add_roots HEADER "${CREDENTIAL_SCAN_HEADER_ROOTS:-}"
add_roots RUNTIME "${CREDENTIAL_SCAN_RUNTIME_ROOTS:-}"
add_roots OSLOG "${CREDENTIAL_SCAN_OSLOG_ROOTS:-}"
add_roots QA "${CREDENTIAL_SCAN_QA_ROOTS:-}"
add_roots BACKUP "${CREDENTIAL_SCAN_BACKUP_ROOTS:-}"

if [[ "$CREDENTIAL_SCAN_REQUIRE_RELEASE_ARTIFACTS" == "1" ]]; then
  args+=(--require-surface APP --require-surface IPA --require-surface DSYM)
fi
if [[ "$CREDENTIAL_SCAN_ENFORCE" == "1" ]]; then
  args+=(--enforce)
fi

"${args[@]}"

echo "[credential-inventory] Value-free report: $REPORT_PATH"

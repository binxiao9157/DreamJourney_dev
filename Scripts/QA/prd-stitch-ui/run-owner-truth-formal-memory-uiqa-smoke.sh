#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../../.." && pwd)"
DERIVED_DATA_PATH="${DERIVED_DATA_PATH:-$ROOT_DIR/tmp/visual-qa/product-v4/DerivedDataFormalMemorySmoke}"
OUTPUT_ROOT="${OUTPUT_ROOT:-$ROOT_DIR/tmp/visual-qa/product-v4/owner-truth-formal-memory-smoke}"
RUN_ID="${RUN_ID:-$(date +%Y%m%d-%H%M%S)}"
OUTPUT_DIR="$OUTPUT_ROOT/$RUN_ID"
INSTALL_DIR="$OUTPUT_DIR/install"
LIST_LOG="$OUTPUT_DIR/list-runtime.log"
DETAIL_LOG="$OUTPUT_DIR/detail-runtime.log"
LIST_SCREENSHOT="$OUTPUT_DIR/01-formal-memory-list.png"
DETAIL_SCREENSHOT="$OUTPUT_DIR/02-formal-memory-detail.png"
RESULT_COPY="$OUTPUT_DIR/owner-truth-formal-memory-uiqa-result.json"

mkdir -p "$OUTPUT_DIR"
cd "$ROOT_DIR"

OUTPUT_DIR="$INSTALL_DIR" \
DERIVED_DATA_PATH="$DERIVED_DATA_PATH" \
LOCAL_BUNDLE_ID="${LOCAL_BUNDLE_ID:-com.yxj.dreamjourney.app}" \
LOCAL_DEVELOPMENT_TEAM="${LOCAL_DEVELOPMENT_TEAM:-2BTR77V3R8}" \
bash "$SCRIPT_DIR/run-installable-simulator-uiqa.sh"

# shellcheck disable=SC1090
source "$INSTALL_DIR/install.env"
RESULT_FILE="$DATA_CONTAINER/Documents/owner-truth-formal-memory-uiqa-result.json"

run_case() {
  local log_file="$1"
  local screenshot="$2"
  shift 2
  rm -f "$RESULT_FILE"
  xcrun simctl launch --console "$SIMULATOR_UDID" "$BUNDLE_ID" \
    DJUITestBypassLogin \
    DJRunOwnerTruthFormalMemorySmoke "$@" > "$log_file" 2>&1 &
  local pid=$!
  local deadline=$((SECONDS + 45))
  while [[ ! -s "$RESULT_FILE" ]]; do
    if (( SECONDS >= deadline )); then
      tail -100 "$log_file" >&2 || true
      kill "$pid" >/dev/null 2>&1 || true
      echo "Timed out waiting for formal-memory UIQA result" >&2
      exit 1
    fi
    sleep 1
  done
  sleep 1
  xcrun simctl io "$SIMULATOR_UDID" screenshot "$screenshot" >/dev/null
  kill "$pid" >/dev/null 2>&1 || true
  xcrun simctl terminate "$SIMULATOR_UDID" "$BUNDLE_ID" >/dev/null 2>&1 || true
}

run_case "$LIST_LOG" "$LIST_SCREENSHOT"
run_case "$DETAIL_LOG" "$DETAIL_SCREENSHOT" DJOwnerTruthFormalMemoryUIQAHoldAtDetail

cp "$RESULT_FILE" "$RESULT_COPY"
grep -Eq '"completed"[[:space:]]*:[[:space:]]*true' "$RESULT_COPY"
grep -Eq '"detailVisible"[[:space:]]*:[[:space:]]*true' "$RESULT_COPY"
grep -Eq '"historyVersionCount"[[:space:]]*:[[:space:]]*3' "$RESULT_COPY"
grep -Eq '"userDeleteAvailable"[[:space:]]*:[[:space:]]*false' "$RESULT_COPY"

echo "Formal-memory UIQA passed"
echo "Result: $RESULT_COPY"
echo "List screenshot: $LIST_SCREENSHOT"
echo "Detail screenshot: $DETAIL_SCREENSHOT"

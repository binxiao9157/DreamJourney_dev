#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../../.." && pwd)"
TIMESTAMP="$(date +%Y%m%d-%H%M%S)"
OUTPUT_DIR="${OUTPUT_DIR:-${OUTPUT_ROOT:-$ROOT_DIR/artifacts/product-confirmed/$TIMESTAMP-pc-b4-uiqa}}"
INSTALL_OUTPUT_DIR="$OUTPUT_DIR/install"
INSTALL_ENV_PATH="$INSTALL_OUTPUT_DIR/install.env"
RESULT_NAME="product-confirmed-message-center-uiqa.json"

mkdir -p "$OUTPUT_DIR"

OUTPUT_DIR="$INSTALL_OUTPUT_DIR" \
  INSTALL_ENV_PATH="$INSTALL_ENV_PATH" \
  LOCAL_BUNDLE_ID="${LOCAL_BUNDLE_ID:-com.yxj.dreamjourney.app}" \
  LOCAL_DEVELOPMENT_TEAM="${LOCAL_DEVELOPMENT_TEAM:-2BTR77V3R8}" \
  bash "$ROOT_DIR/Scripts/QA/prd-stitch-ui/run-installable-simulator-uiqa.sh"

# shellcheck disable=SC1090
source "$INSTALL_ENV_PATH"

wait_for_result() {
  local result_path="$1"
  local attempt
  for attempt in $(seq 1 60); do
    if [[ -s "$result_path" ]]; then
      return 0
    fi
    sleep 0.25
  done
  echo "PC-B4 UIQA result was not produced: $result_path" >&2
  return 1
}

run_scenario() {
  local udid="$1"
  local label="$2"
  local content_size="$3"
  local container
  local result_path

  xcrun simctl ui "$udid" content_size "$content_size"
  xcrun simctl terminate "$udid" "$BUNDLE_ID" >/dev/null 2>&1 || true
  container="$(xcrun simctl get_app_container "$udid" "$BUNDLE_ID" data)"
  result_path="$container/Documents/$RESULT_NAME"
  rm -f "$result_path"

  xcrun simctl launch "$udid" "$BUNDLE_ID" \
    DJUITestBypassLogin \
    DJRunProductConfirmedMessageCenterSmoke >/dev/null
  wait_for_result "$result_path"
  python3 - "$result_path" <<'PY'
import json
import sys

payload = json.load(open(sys.argv[1], encoding="utf-8"))
assert payload.get("completed") is True, payload
assert payload.get("messageCount") == 3, payload
assert payload.get("unreadCount") == 2, payload
assert payload.get("authority") == "backend", payload
assert payload.get("closedKindsExcluded") is True, payload
PY
  cp "$result_path" "$OUTPUT_DIR/$label-result.json"
  xcrun simctl io "$udid" screenshot "$OUTPUT_DIR/$label.png" >/dev/null
  xcrun simctl terminate "$udid" "$BUNDLE_ID" >/dev/null 2>&1 || true
}

run_scenario "$SIMULATOR_UDID" "message-center-standard" "large"
run_scenario "$SIMULATOR_UDID" "message-center-accessibility" "accessibility-extra-large"
xcrun simctl ui "$SIMULATOR_UDID" content_size large

SECONDARY_SIMULATOR_NAME="${SECONDARY_SIMULATOR_NAME:-iPhone 17e}"
SECONDARY_UDID="$(xcrun simctl list devices available | awk -F '[()]' -v name="$SECONDARY_SIMULATOR_NAME" '$0 ~ name { print $2; exit }')"
if [[ -n "$SECONDARY_UDID" && "$SECONDARY_UDID" != "$SIMULATOR_UDID" ]]; then
  SECONDARY_WAS_BOOTED="$(xcrun simctl list devices | awk -v id="$SECONDARY_UDID" '$0 ~ id && $0 ~ /Booted/ { print "yes"; exit }')"
  if [[ -z "$SECONDARY_WAS_BOOTED" ]]; then
    xcrun simctl boot "$SECONDARY_UDID" >/dev/null
  fi
  xcrun simctl bootstatus "$SECONDARY_UDID" -b >/dev/null
  xcrun simctl install "$SECONDARY_UDID" "$APP_PATH"
  run_scenario "$SECONDARY_UDID" "message-center-compact" "large"
  if [[ -z "$SECONDARY_WAS_BOOTED" ]]; then
    xcrun simctl shutdown "$SECONDARY_UDID"
  fi
fi

echo "PC-B4 message center UIQA smoke passed"
echo "Evidence: $OUTPUT_DIR"

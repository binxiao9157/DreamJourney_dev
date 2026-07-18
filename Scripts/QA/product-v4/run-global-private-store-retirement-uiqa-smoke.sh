#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../../.." && pwd)"

RUN_ID="${RUN_ID:-$(date +%Y%m%d-%H%M%S)}"
OUTPUT_ROOT="${OUTPUT_ROOT:-$ROOT_DIR/tmp/visual-qa/product-v4/global-private-store-retirement}"
OUTPUT_DIR="$OUTPUT_ROOT/$RUN_ID"
INSTALL_DIR="$OUTPUT_DIR/install"
DERIVED_DATA_PATH="${DERIVED_DATA_PATH:-$ROOT_DIR/tmp/visual-qa/product-v4/DerivedDataGlobalPrivateStoreRetirement}"
RUNTIME_LOG="$OUTPUT_DIR/runtime.log"
OS_LOG="$OUTPUT_DIR/oslog.log"
RESULT_COPY="$OUTPUT_DIR/global-private-store-retirement-uiqa-result.json"
SCREENSHOT_PATH="$OUTPUT_DIR/01-global-private-store-retirement.png"
RESULT_FILE_NAME="global-private-store-retirement-uiqa-result.json"
COMPLETION_PATTERN="GlobalPrivateStoreRetirementSmoke completed"
LOG_WAIT_TIMEOUT="${LOG_WAIT_TIMEOUT:-60}"

mkdir -p "$OUTPUT_DIR"

fail() {
  echo "[global-private-store-retirement-uiqa] $*" >&2
  tail -80 "$RUNTIME_LOG" 2>/dev/null >&2 || true
  tail -80 "$OS_LOG" 2>/dev/null >&2 || true
  exit 1
}

echo "[global-private-store-retirement-uiqa] Building and installing UIQA app..."
OUTPUT_DIR="$INSTALL_DIR" \
DERIVED_DATA_PATH="$DERIVED_DATA_PATH" \
CONFIGURATION=Debug \
SWIFT_ACTIVE_COMPILATION_CONDITIONS="DEBUG UI_QA_SIMULATOR" \
  "$ROOT_DIR/Scripts/QA/prd-stitch-ui/run-installable-simulator-uiqa.sh"

# shellcheck disable=SC1090
source "$INSTALL_DIR/install.env"
RESULT_FILE="$DATA_CONTAINER/Documents/$RESULT_FILE_NAME"
rm -f "$RESULT_FILE"

CONSOLE_PID=""
OSLOG_PID=""
cleanup() {
  [[ -z "$CONSOLE_PID" ]] || kill "$CONSOLE_PID" >/dev/null 2>&1 || true
  [[ -z "$OSLOG_PID" ]] || kill "$OSLOG_PID" >/dev/null 2>&1 || true
}
trap cleanup EXIT

touch "$RUNTIME_LOG" "$OS_LOG"
xcrun simctl spawn "$SIMULATOR_UDID" log stream \
  --style compact \
  --level debug \
  --predicate 'process == "DreamJourney"' > "$OS_LOG" 2>&1 &
OSLOG_PID="$!"
sleep 1

echo "[global-private-store-retirement-uiqa] Launching A/B runtime isolation harness..."
xcrun simctl launch --console "$SIMULATOR_UDID" "$BUNDLE_ID" \
  DJRunGlobalPrivateStoreRetirementSmoke > "$RUNTIME_LOG" 2>&1 &
CONSOLE_PID="$!"

deadline=$((SECONDS + LOG_WAIT_TIMEOUT))
while [[ ! -s "$RESULT_FILE" ]] \
  && ! grep -q "$COMPLETION_PATTERN" "$RUNTIME_LOG" "$OS_LOG" 2>/dev/null; do
  (( SECONDS < deadline )) || fail "timed out waiting for $COMPLETION_PATTERN"
  sleep 1
done

[[ -s "$RESULT_FILE" ]] || fail "result file was not written"
cp "$RESULT_FILE" "$RESULT_COPY"

python3 - "$RESULT_COPY" <<'PY'
import json
import sys

path = sys.argv[1]
with open(path, encoding="utf-8") as handle:
    result = json.load(handle)

required_true = (
    "completed",
    "conversationAccountIsolation",
    "conversationGenerationContinuity",
    "memoirAccountIsolation",
    "memoryAccountIsolation",
    "mapPresentationAccountIsolation",
    "privatePhotoAccountIsolation",
    "staleLeaseRejected",
    "legacyGlobalConversationQuarantined",
    "legacyHomeMediaRetired",
    "reservedFallbackOwnerRejected",
)
failed = [key for key in required_true if result.get(key) is not True]
if failed:
    raise SystemExit("runtime isolation assertions failed: " + ", ".join(failed))
if result.get("failureReason"):
    raise SystemExit("runtime smoke returned failureReason: " + result["failureReason"])
print(json.dumps(result, ensure_ascii=False, sort_keys=True))
PY

xcrun simctl io "$SIMULATOR_UDID" screenshot "$SCREENSHOT_PATH" >/dev/null
xcrun simctl terminate "$SIMULATOR_UDID" "$BUNDLE_ID" >/dev/null 2>&1 || true

echo "[global-private-store-retirement-uiqa] Runtime log: $RUNTIME_LOG"
echo "[global-private-store-retirement-uiqa] OS log: $OS_LOG"
echo "[global-private-store-retirement-uiqa] Result: $RESULT_COPY"
echo "[global-private-store-retirement-uiqa] Screenshot: $SCREENSHOT_PATH"

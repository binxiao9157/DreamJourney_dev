#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../../.." && pwd)"

RUN_ID="${RUN_ID:-$(date +%Y%m%d-%H%M%S)}"
OUTPUT_ROOT="${OUTPUT_ROOT:-$ROOT_DIR/tmp/visual-qa/product-v4/owner-media-unified-creation-smoke}"
OUTPUT_DIR="$OUTPUT_ROOT/$RUN_ID"
INSTALL_OUTPUT_DIR="$OUTPUT_DIR/install"
DERIVED_DATA_PATH="${DERIVED_DATA_PATH:-$ROOT_DIR/tmp/visual-qa/product-v4/DerivedDataOwnerMediaUnifiedCreationSmoke}"
RUNTIME_LOG="$OUTPUT_DIR/runtime.log"
SCREENSHOT_PATH="$OUTPUT_DIR/01-owner-media-unified-creation.png"
RESULT_COPY_PATH="$OUTPUT_DIR/owner-media-unified-creation-smoke-result.json"
LOG_WAIT_TIMEOUT="${LOG_WAIT_TIMEOUT:-45}"

mkdir -p "$OUTPUT_DIR"
cd "$ROOT_DIR"

fail() {
  printf '[owner-media-unified-creation-smoke] %s\n' "$*" >&2
  [[ -f "$RUNTIME_LOG" ]] && tail -100 "$RUNTIME_LOG" >&2 || true
  exit 1
}

printf '[owner-media-unified-creation-smoke] Building and installing UIQA app...\n'
OUTPUT_DIR="$INSTALL_OUTPUT_DIR" \
DERIVED_DATA_PATH="$DERIVED_DATA_PATH" \
LOCAL_BUNDLE_ID="${LOCAL_BUNDLE_ID:-com.yxj.dreamjourney.app}" \
LOCAL_DEVELOPMENT_TEAM="${LOCAL_DEVELOPMENT_TEAM:-2BTR77V3R8}" \
bash "$ROOT_DIR/Scripts/QA/prd-stitch-ui/run-installable-simulator-uiqa.sh"

# shellcheck disable=SC1090
source "$INSTALL_OUTPUT_DIR/install.env"
RESULT_FILE="$DATA_CONTAINER/Documents/owner-media-unified-creation-smoke-result.json"
rm -f "$RESULT_FILE"

CONSOLE_PID=""
cleanup() {
  [[ -n "$CONSOLE_PID" ]] && kill "$CONSOLE_PID" >/dev/null 2>&1 || true
  xcrun simctl terminate "$SIMULATOR_UDID" "$BUNDLE_ID" >/dev/null 2>&1 || true
}
trap cleanup EXIT

printf '[owner-media-unified-creation-smoke] Launching unified creation preview...\n'
xcrun simctl launch --console "$SIMULATOR_UDID" "$BUNDLE_ID" \
  DJUITestBypassLogin \
  DJRunOwnerMediaUnifiedCreationSmoke > "$RUNTIME_LOG" 2>&1 &
CONSOLE_PID="$!"

deadline=$((SECONDS + LOG_WAIT_TIMEOUT))
while [[ ! -s "$RESULT_FILE" ]]; do
  (( SECONDS < deadline )) || fail "Timed out waiting for UIQA result"
  sleep 1
done

cp "$RESULT_FILE" "$RESULT_COPY_PATH"
python3 - "$RESULT_FILE" <<'PY'
import json
import sys

payload = json.load(open(sys.argv[1], encoding="utf-8"))
expected = ["记录文字", "选择图片", "选择音频", "选择文档", "选择视频"]
if payload.get("completed") is not True:
    raise SystemExit("unified creation smoke did not complete")
if payload.get("publicOptionTitles") != ["添加文字描述", "选择照片"]:
    raise SystemExit("public release creation options drifted")
if payload.get("unifiedOptionTitles") != expected:
    raise SystemExit("closed-pilot unified creation options drifted")
if payload.get("unifiedOptionCount") != 5:
    raise SystemExit("unified creation option count must be five")
if payload.get("usesLargeDetent") is not True or payload.get("allOptionsVisible") is not True:
    raise SystemExit("unified creation sheet is clipped or uses the wrong detent")
if payload.get("backendNetworkStarted") is not False:
    raise SystemExit("visual smoke must not call the backend")
if payload.get("persistentOwnerTruthWriteStarted") is not False:
    raise SystemExit("visual smoke must not persist Owner Truth data")
PY

xcrun simctl io "$SIMULATOR_UDID" screenshot "$SCREENSHOT_PATH" >/dev/null

printf '[owner-media-unified-creation-smoke] Result: %s\n' "$RESULT_COPY_PATH"
printf '[owner-media-unified-creation-smoke] Screenshot: %s\n' "$SCREENSHOT_PATH"
printf '[owner-media-unified-creation-smoke] Runtime log: %s\n' "$RUNTIME_LOG"

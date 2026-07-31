#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../../.." && pwd)"

SCHEME="${SCHEME:-DreamJourney}"
CONFIGURATION="${CONFIGURATION:-Debug}"
SIMULATOR_NAME="${SIMULATOR_NAME:-iPhone 17}"
SWIFT_ACTIVE_COMPILATION_CONDITIONS='DEBUG UI_QA_SIMULATOR'
LOCAL_BUNDLE_ID="${LOCAL_BUNDLE_ID:-com.yxj.dreamjourney.app}"
LOCAL_DEVELOPMENT_TEAM="${LOCAL_DEVELOPMENT_TEAM:-2BTR77V3R8}"
DERIVED_DATA_PATH="${DERIVED_DATA_PATH:-$ROOT_DIR/tmp/visual-qa/product-v4/DerivedDataOwnerTruthInterviewNaturalInputProductSurfaceSmoke}"
OUTPUT_ROOT="${OUTPUT_ROOT:-$ROOT_DIR/tmp/visual-qa/product-v4/owner-truth-interview-natural-input-product-surface-smoke}"
RUN_ID="${RUN_ID:-$(date +%Y%m%d-%H%M%S)}"
OUTPUT_DIR="$OUTPUT_ROOT/$RUN_ID"
BUILD_LOG="$OUTPUT_DIR/build.log"
RUNTIME_LOG="$OUTPUT_DIR/runtime.log"
OS_LOG="$OUTPUT_DIR/oslog.log"
SCREENSHOT_PATH="$OUTPUT_DIR/01-owner-truth-interview-natural-input-product-surface.png"
RESULT_COPY_PATH="$OUTPUT_DIR/owner-truth-interview-natural-input-product-surface-smoke-result.json"
COMPLETION_PATTERN="OwnerTruthInterviewNaturalInputProductSurfaceSmoke completed"
LOG_WAIT_TIMEOUT="${LOG_WAIT_TIMEOUT:-45}"

mkdir -p "$OUTPUT_DIR"
cd "$ROOT_DIR"

fail() {
  printf '[owner-truth-interview-natural-input-product-surface-smoke] %s\n' "$*" >&2
  [[ -f "$RUNTIME_LOG" ]] && tail -80 "$RUNTIME_LOG" >&2 || true
  [[ -f "$OS_LOG" ]] && tail -80 "$OS_LOG" >&2 || true
  exit 1
}

booted_simulator_udid() {
  xcrun simctl list devices booted | awk -F '[()]' '/Booted/ { print $2; exit }'
}

SIMULATOR_UDID="${SIMULATOR_UDID:-$(booted_simulator_udid)}"
if [[ -z "$SIMULATOR_UDID" ]]; then
  xcrun simctl boot "$SIMULATOR_NAME" >/dev/null
  SIMULATOR_UDID="$(booted_simulator_udid)"
fi
[[ -n "$SIMULATOR_UDID" ]] || fail "No booted simulator. Set SIMULATOR_UDID or SIMULATOR_NAME."

printf '[owner-truth-interview-natural-input-product-surface-smoke] Building UIQA app...\n'
printf '[owner-truth-interview-natural-input-product-surface-smoke] Local QA bundle id: %s\n' "$LOCAL_BUNDLE_ID"
printf '[owner-truth-interview-natural-input-product-surface-smoke] Local QA team id: %s\n' "$LOCAL_DEVELOPMENT_TEAM"
xcodebuild \
  -workspace DreamJourney.xcworkspace \
  -scheme "$SCHEME" \
  -configuration "$CONFIGURATION" \
  -sdk iphonesimulator \
  -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath "$DERIVED_DATA_PATH" \
  CODE_SIGNING_ALLOWED=NO \
  SWIFT_ACTIVE_COMPILATION_CONDITIONS="$SWIFT_ACTIVE_COMPILATION_CONDITIONS" \
  DREAMJOURNEY_PRODUCT_BUNDLE_IDENTIFIER="$LOCAL_BUNDLE_ID" \
  DREAMJOURNEY_DEVELOPMENT_TEAM="$LOCAL_DEVELOPMENT_TEAM" \
  EXCLUDED_ARCHS='' \
  ARCHS=arm64 \
  ONLY_ACTIVE_ARCH=NO \
  build > "$BUILD_LOG"

APP_PATH="$DERIVED_DATA_PATH/Build/Products/$CONFIGURATION-iphonesimulator/DreamJourney.app"
[[ -d "$APP_PATH" ]] || fail "Built app not found: $APP_PATH"
BUNDLE_ID="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$APP_PATH/Info.plist")"
[[ -n "$BUNDLE_ID" ]] || fail "Unable to read bundle id from $APP_PATH"
[[ "$BUNDLE_ID" == "$LOCAL_BUNDLE_ID" ]] || fail "Built app bundle id is $BUNDLE_ID, expected $LOCAL_BUNDLE_ID"
[[ "$BUNDLE_ID" != "com.gaominge.dreamjourney.app" ]] || fail "Built app is using the shared default bundle id."

printf '[owner-truth-interview-natural-input-product-surface-smoke] Installing %s on %s...\n' "$BUNDLE_ID" "$SIMULATOR_UDID"
xcrun simctl terminate "$SIMULATOR_UDID" "$BUNDLE_ID" >/dev/null 2>&1 || true
xcrun simctl uninstall "$SIMULATOR_UDID" "$BUNDLE_ID" >/dev/null 2>&1 || true
xcrun simctl install "$SIMULATOR_UDID" "$APP_PATH"
xcrun simctl spawn "$SIMULATOR_UDID" defaults delete "$BUNDLE_ID" >/dev/null 2>&1 || true
DATA_CONTAINER="$(xcrun simctl get_app_container "$SIMULATOR_UDID" "$BUNDLE_ID" data)"
RESULT_FILE="$DATA_CONTAINER/Documents/owner-truth-interview-natural-input-product-surface-smoke-result.json"
rm -f "$RESULT_FILE"

CONSOLE_PID=""
OSLOG_PID=""
cleanup() {
  [[ -n "$CONSOLE_PID" ]] && kill "$CONSOLE_PID" >/dev/null 2>&1 || true
  [[ -n "$OSLOG_PID" ]] && kill "$OSLOG_PID" >/dev/null 2>&1 || true
}
trap cleanup EXIT

touch "$RUNTIME_LOG" "$OS_LOG"
xcrun simctl spawn "$SIMULATOR_UDID" log stream \
  --style compact \
  --level debug \
  --predicate 'process == "DreamJourney"' > "$OS_LOG" 2>&1 &
OSLOG_PID="$!"
sleep 1

printf '[owner-truth-interview-natural-input-product-surface-smoke] Launching in-memory product preview...\n'
xcrun simctl launch --console "$SIMULATOR_UDID" "$BUNDLE_ID" \
  DJUITestBypassLogin \
  DJRunOwnerTruthInterviewNaturalInputProductSurfaceSmoke > "$RUNTIME_LOG" 2>&1 &
CONSOLE_PID="$!"

deadline=$((SECONDS + LOG_WAIT_TIMEOUT))
while [[ ! -s "$RESULT_FILE" ]] && ! grep -q "$COMPLETION_PATTERN" "$RUNTIME_LOG" "$OS_LOG" 2>/dev/null; do
  (( SECONDS < deadline )) || fail "Timed out waiting for $COMPLETION_PATTERN"
  sleep 1
done

[[ -s "$RESULT_FILE" ]] || fail "Result file was not written."
cp "$RESULT_FILE" "$RESULT_COPY_PATH"
cat "$RESULT_FILE"
printf '\n'

grep -Eq '"completed"[[:space:]]*:[[:space:]]*true' "$RESULT_FILE" || fail "Product natural-input sheet did not complete."
grep -Eq '"productEntryVisible"[[:space:]]*:[[:space:]]*true' "$RESULT_FILE" || fail "Product entry should be visible in the in-memory preview."
grep -Eq '"qaEntryVisible"[[:space:]]*:[[:space:]]*false' "$RESULT_FILE" || fail "QA-only entry must remain hidden in the product preview."
grep -Eq '"sheetPresented"[[:space:]]*:[[:space:]]*true' "$RESULT_FILE" || fail "Product natural-input sheet should be presented."
grep -Eq '"sheetTitle"[[:space:]]*:[[:space:]]*"今天想聊点什么？"' "$RESULT_FILE" || fail "Product presentation title drifted."
grep -Eq '"inputRecorded"[[:space:]]*:[[:space:]]*true' "$RESULT_FILE" || fail "In-memory product input should be recorded."
grep -Eq '"summaryState"[[:space:]]*:[[:space:]]*"reviewPending"' "$RESULT_FILE" || fail "Product continuation summary state drifted."
grep -Eq '"summaryStatus"[[:space:]]*:[[:space:]]*"有内容等待你确认"' "$RESULT_FILE" || fail "Product summary status drifted."
grep -Eq '"summaryDetail"[[:space:]]*:[[:space:]]*"确认后才会进入你的记忆。"' "$RESULT_FILE" || fail "Product summary detail drifted."
grep -Eq '"pendingConfirmationEntryVisible"[[:space:]]*:[[:space:]]*true' "$RESULT_FILE" || fail "Pending-confirmation entry should be visible in the approved product preview."
grep -Eq '"transcriptCleared"[[:space:]]*:[[:space:]]*true' "$RESULT_FILE" || fail "Product preview must clear submitted text."
grep -Eq '"productBoundaryControlsVisible"[[:space:]]*:[[:space:]]*true' "$RESULT_FILE" || fail "Product boundary controls should be visible."
grep -Eq '"qaOnlyBoundaryControlsHidden"[[:space:]]*:[[:space:]]*true' "$RESULT_FILE" || fail "QA-only boundary controls must remain hidden."
grep -Eq '"inMemoryPreview"[[:space:]]*:[[:space:]]*true' "$RESULT_FILE" || fail "Smoke must remain an in-memory preview."
grep -Eq '"releasePolicyBypassedForPreview"[[:space:]]*:[[:space:]]*true' "$RESULT_FILE" || fail "Preview policy isolation marker missing."
grep -Eq '"voiceTurnStarted"[[:space:]]*:[[:space:]]*false' "$RESULT_FILE" || fail "Opening the sheet must not start a voice turn."
grep -Eq '"digitalHumanSessionStarted"[[:space:]]*:[[:space:]]*false' "$RESULT_FILE" || fail "Opening the sheet must not start a Digital Human session."
grep -Eq '"backendNetworkStarted"[[:space:]]*:[[:space:]]*false' "$RESULT_FILE" || fail "Opening the preview must not start a backend request."
grep -Eq '"persistentInterviewWriteStarted"[[:space:]]*:[[:space:]]*false' "$RESULT_FILE" || fail "Opening the preview must not write private interview data."
grep -Eq '"DJRunOwnerTruthInterviewNaturalInputProductSurfaceSmoke"' "$RESULT_FILE" || fail "Product surface launch scenario drifted."

xcrun simctl io "$SIMULATOR_UDID" screenshot "$SCREENSHOT_PATH" >/dev/null
xcrun simctl terminate "$SIMULATOR_UDID" "$BUNDLE_ID" >/dev/null 2>&1 || true

printf '[owner-truth-interview-natural-input-product-surface-smoke] Build log: %s\n' "$BUILD_LOG"
printf '[owner-truth-interview-natural-input-product-surface-smoke] Runtime log: %s\n' "$RUNTIME_LOG"
printf '[owner-truth-interview-natural-input-product-surface-smoke] OS log: %s\n' "$OS_LOG"
printf '[owner-truth-interview-natural-input-product-surface-smoke] Result: %s\n' "$RESULT_COPY_PATH"
printf '[owner-truth-interview-natural-input-product-surface-smoke] Screenshot: %s\n' "$SCREENSHOT_PATH"

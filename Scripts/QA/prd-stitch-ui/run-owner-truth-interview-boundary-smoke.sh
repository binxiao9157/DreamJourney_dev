#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../../.." && pwd)"

SCHEME="${SCHEME:-DreamJourney}"
CONFIGURATION="${CONFIGURATION:-Debug}"
SIMULATOR_NAME="${SIMULATOR_NAME:-iPhone 17}"
SWIFT_ACTIVE_COMPILATION_CONDITIONS='DEBUG UI_QA_SIMULATOR'
DERIVED_DATA_PATH="${DERIVED_DATA_PATH:-$ROOT_DIR/tmp/visual-qa/product-v4/DerivedDataOwnerTruthInterviewBoundarySmoke}"
OUTPUT_ROOT="${OUTPUT_ROOT:-$ROOT_DIR/tmp/visual-qa/product-v4/owner-truth-interview-boundary-smoke}"
RUN_ID="${RUN_ID:-$(date +%Y%m%d-%H%M%S)}"
OUTPUT_DIR="$OUTPUT_ROOT/$RUN_ID"
BUILD_LOG="$OUTPUT_DIR/build.log"
RUNTIME_LOG="$OUTPUT_DIR/runtime.log"
OS_LOG="$OUTPUT_DIR/oslog.log"
SCREENSHOT_PATH="$OUTPUT_DIR/01-owner-truth-interview-boundary.png"
RESULT_COPY_PATH="$OUTPUT_DIR/owner-truth-interview-boundary-uiqa-result.json"
COMPLETION_PATTERN="OwnerTruthInterviewBoundarySmoke completed"
LOG_WAIT_TIMEOUT="${LOG_WAIT_TIMEOUT:-45}"

mkdir -p "$OUTPUT_DIR"
cd "$ROOT_DIR"

fail() {
  printf '[owner-truth-interview-boundary-smoke] %s\n' "$*" >&2
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

printf '[owner-truth-interview-boundary-smoke] Building UIQA app...\n'
xcodebuild \
  -workspace DreamJourney.xcworkspace \
  -scheme "$SCHEME" \
  -configuration "$CONFIGURATION" \
  -sdk iphonesimulator \
  -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath "$DERIVED_DATA_PATH" \
  CODE_SIGNING_ALLOWED=NO \
  SWIFT_ACTIVE_COMPILATION_CONDITIONS="$SWIFT_ACTIVE_COMPILATION_CONDITIONS" \
  EXCLUDED_ARCHS='' \
  ARCHS=arm64 \
  ONLY_ACTIVE_ARCH=NO \
  build > "$BUILD_LOG"

APP_PATH="$DERIVED_DATA_PATH/Build/Products/$CONFIGURATION-iphonesimulator/DreamJourney.app"
[[ -d "$APP_PATH" ]] || fail "Built app not found: $APP_PATH"
BUNDLE_ID="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$APP_PATH/Info.plist")"
[[ -n "$BUNDLE_ID" ]] || fail "Unable to read bundle id from $APP_PATH"

printf '[owner-truth-interview-boundary-smoke] Installing %s on %s...\n' "$BUNDLE_ID" "$SIMULATOR_UDID"
xcrun simctl terminate "$SIMULATOR_UDID" "$BUNDLE_ID" >/dev/null 2>&1 || true
xcrun simctl uninstall "$SIMULATOR_UDID" "$BUNDLE_ID" >/dev/null 2>&1 || true
xcrun simctl install "$SIMULATOR_UDID" "$APP_PATH"
xcrun simctl spawn "$SIMULATOR_UDID" defaults delete "$BUNDLE_ID" >/dev/null 2>&1 || true
DATA_CONTAINER="$(xcrun simctl get_app_container "$SIMULATOR_UDID" "$BUNDLE_ID" data)"
RESULT_FILE="$DATA_CONTAINER/Documents/owner-truth-interview-boundary-uiqa-result.json"
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

printf '[owner-truth-interview-boundary-smoke] Launching auto-run harness...\n'
xcrun simctl launch --console "$SIMULATOR_UDID" "$BUNDLE_ID" \
  DJUITestBypassLogin \
  DJEnableOwnerTruthCandidateReviewQA \
  DJRunOwnerTruthInterviewBoundarySmoke > "$RUNTIME_LOG" 2>&1 &
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

grep -Eq '"completed"[[:space:]]*:[[:space:]]*true' "$RESULT_FILE" || fail "Boundary UIQA did not complete."
grep -Eq '"qaGateEnabled"[[:space:]]*:[[:space:]]*true' "$RESULT_FILE" || fail "QA gate should be enabled."
grep -Eq '"boundaryButtonsVisible"[[:space:]]*:[[:space:]]*true' "$RESULT_FILE" || fail "Boundary controls should be visible only in QA."
grep -Eq '"boundary"[[:space:]]*:[[:space:]]*"skipOnce"' "$RESULT_FILE" || fail "skipOnce result missing."
grep -Eq '"boundary"[[:space:]]*:[[:space:]]*"cooldown"' "$RESULT_FILE" || fail "cooldown result missing."
grep -Eq '"boundary"[[:space:]]*:[[:space:]]*"doNotAsk"' "$RESULT_FILE" || fail "doNotAsk result missing."
grep -Eq '"doNotAskRestoreCompleted"[[:space:]]*:[[:space:]]*true' "$RESULT_FILE" || fail "explicit doNotAsk restore result missing."
grep -Eq '"cooldownRestoreCompleted"[[:space:]]*:[[:space:]]*true' "$RESULT_FILE" || fail "elapsed cooldown restore result missing."
grep -Eq '"lifecycle"[[:space:]]*:[[:space:]]*"active"' "$RESULT_FILE" || fail "skipOnce must remain active."
grep -Eq '"lifecycle"[[:space:]]*:[[:space:]]*"paused"' "$RESULT_FILE" || fail "paused boundary result missing."
grep -Eq '"DJRunOwnerTruthInterviewBoundarySmoke"' "$RESULT_FILE" || fail "Boundary launch scenario drifted."
grep -Eq '"DJEnableOwnerTruthCandidateReviewQA"' "$RESULT_FILE" || fail "QA gate launch argument drifted."

xcrun simctl io "$SIMULATOR_UDID" screenshot "$SCREENSHOT_PATH" >/dev/null
xcrun simctl terminate "$SIMULATOR_UDID" "$BUNDLE_ID" >/dev/null 2>&1 || true

printf '[owner-truth-interview-boundary-smoke] Build log: %s\n' "$BUILD_LOG"
printf '[owner-truth-interview-boundary-smoke] Runtime log: %s\n' "$RUNTIME_LOG"
printf '[owner-truth-interview-boundary-smoke] OS log: %s\n' "$OS_LOG"
printf '[owner-truth-interview-boundary-smoke] Result: %s\n' "$RESULT_COPY_PATH"
printf '[owner-truth-interview-boundary-smoke] Screenshot: %s\n' "$SCREENSHOT_PATH"

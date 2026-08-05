#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../../.." && pwd)"

SCHEME="${SCHEME:-DreamJourney}"
CONFIGURATION="${CONFIGURATION:-Debug}"
SIMULATOR_NAME="${SIMULATOR_NAME:-iPhone 17}"
LOCAL_BUNDLE_ID="${LOCAL_BUNDLE_ID:-com.yxj.dreamjourney.app}"
LOCAL_DEVELOPMENT_TEAM="${LOCAL_DEVELOPMENT_TEAM:-2BTR77V3R8}"
SWIFT_ACTIVE_COMPILATION_CONDITIONS='DEBUG UI_QA_SIMULATOR'
DERIVED_DATA_PATH="${DERIVED_DATA_PATH:-$ROOT_DIR/tmp/visual-qa/prd-stitch-ui/DerivedDataVoiceCloneProfileSelectionSmoke}"
OUTPUT_ROOT="${OUTPUT_ROOT:-$ROOT_DIR/tmp/visual-qa/prd-stitch-ui/voice-clone-profile-selection-smoke}"
RUN_ID="${RUN_ID:-$(date +%Y%m%d-%H%M%S)}"
OUTPUT_DIR="$OUTPUT_ROOT/$RUN_ID"
BUILD_LOG="$OUTPUT_DIR/build.log"
RUNTIME_LOG="$OUTPUT_DIR/runtime.log"
OS_LOG="$OUTPUT_DIR/oslog.log"
SCREENSHOT_PATH="$OUTPUT_DIR/01-voice-clone-profile-selection.png"
RESULT_COPY_PATH="$OUTPUT_DIR/voice-clone-profile-selection-smoke-result.json"
RESULT_BASENAME="voice-clone-profile-selection-smoke-result.json"
COMPLETION_PATTERN="VoiceCloneProfileSelectionSmoke completed"
LOG_WAIT_TIMEOUT="${LOG_WAIT_TIMEOUT:-45}"

mkdir -p "$OUTPUT_DIR"
cd "$ROOT_DIR"

fail() {
  echo "[voice-clone-profile-selection-smoke] $*" >&2
  if [[ -f "$RUNTIME_LOG" ]]; then
    echo "[voice-clone-profile-selection-smoke] runtime log tail:" >&2
    tail -80 "$RUNTIME_LOG" >&2 || true
  fi
  if [[ -f "$OS_LOG" ]]; then
    echo "[voice-clone-profile-selection-smoke] os log tail:" >&2
    tail -80 "$OS_LOG" >&2 || true
  fi
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

echo "[voice-clone-profile-selection-smoke] Building UIQA app..."
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
  DREAMJOURNEY_PRODUCT_BUNDLE_IDENTIFIER="$LOCAL_BUNDLE_ID" \
  DREAMJOURNEY_DEVELOPMENT_TEAM="$LOCAL_DEVELOPMENT_TEAM" \
  build > "$BUILD_LOG"

APP_PATH="$DERIVED_DATA_PATH/Build/Products/$CONFIGURATION-iphonesimulator/DreamJourney.app"
[[ -d "$APP_PATH" ]] || fail "Built app not found: $APP_PATH"

BUNDLE_ID="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$APP_PATH/Info.plist")"
[[ -n "$BUNDLE_ID" ]] || fail "Unable to read bundle id from $APP_PATH"
[[ "$BUNDLE_ID" == "$LOCAL_BUNDLE_ID" ]] || fail "Built bundle id $BUNDLE_ID does not match LOCAL_BUNDLE_ID=$LOCAL_BUNDLE_ID"

echo "[voice-clone-profile-selection-smoke] Installing $BUNDLE_ID on $SIMULATOR_UDID..."
xcrun simctl terminate "$SIMULATOR_UDID" "$BUNDLE_ID" >/dev/null 2>&1 || true
xcrun simctl uninstall "$SIMULATOR_UDID" "$BUNDLE_ID" >/dev/null 2>&1 || true
xcrun simctl install "$SIMULATOR_UDID" "$APP_PATH"
xcrun simctl spawn "$SIMULATOR_UDID" defaults delete "$BUNDLE_ID" >/dev/null 2>&1 || true
DATA_CONTAINER="$(xcrun simctl get_app_container "$SIMULATOR_UDID" "$BUNDLE_ID" data)"
RESULT_FILE="$DATA_CONTAINER/Documents/$RESULT_BASENAME"
rm -f "$RESULT_FILE"

CONSOLE_PID=""
OSLOG_PID=""
cleanup() {
  if [[ -n "$CONSOLE_PID" ]]; then
    kill "$CONSOLE_PID" >/dev/null 2>&1 || true
  fi
  if [[ -n "$OSLOG_PID" ]]; then
    kill "$OSLOG_PID" >/dev/null 2>&1 || true
  fi
}
trap cleanup EXIT

touch "$RUNTIME_LOG" "$OS_LOG"
xcrun simctl spawn "$SIMULATOR_UDID" log stream \
  --style compact \
  --level debug \
  --predicate 'process == "DreamJourney"' > "$OS_LOG" 2>&1 &
OSLOG_PID="$!"
sleep 1

echo "[voice-clone-profile-selection-smoke] Launching auto-run harness..."
xcrun simctl launch --console "$SIMULATOR_UDID" "$BUNDLE_ID" DJUITestBypassLogin DJRunVoiceCloneProfileSelectionSmoke > "$RUNTIME_LOG" 2>&1 &
CONSOLE_PID="$!"

deadline=$((SECONDS + LOG_WAIT_TIMEOUT))
while [[ ! -s "$RESULT_FILE" ]] && ! grep -q "$COMPLETION_PATTERN" "$RUNTIME_LOG" "$OS_LOG" 2>/dev/null; do
  if (( SECONDS >= deadline )); then
    fail "Timed out waiting for $COMPLETION_PATTERN"
  fi
  sleep 1
done

[[ -s "$RESULT_FILE" ]] || fail "Result file was not written."
cp "$RESULT_FILE" "$RESULT_COPY_PATH"
cat "$RESULT_FILE"
echo

grep -Eq '"completed"[[:space:]]*:[[:space:]]*true' "$RESULT_FILE" || fail "Smoke did not complete."
grep -Eq '"readyPreferredOverPending"[[:space:]]*:[[:space:]]*true' "$RESULT_FILE" || fail "Ready profile should win over pending."
grep -Eq '"pendingPreferredRespected"[[:space:]]*:[[:space:]]*true' "$RESULT_FILE" || fail "A selected pending profile should remain selected for status display."
grep -Eq '"pendingClearsUsableReady"[[:space:]]*:[[:space:]]*true' "$RESULT_FILE" || fail "A pending profile must clear a previously usable profile."
grep -Eq '"deletedIgnored"[[:space:]]*:[[:space:]]*true' "$RESULT_FILE" || fail "Deleted profile should be ignored."
grep -Eq '"legacyReadyRejectedForEcho"[[:space:]]*:[[:space:]]*true' "$RESULT_FILE" || fail "Legacy ready profiles without the canonical lifecycle must fail closed."
grep -Eq '"usableAfterPending"[[:space:]]*:[[:space:]]*"missing"' "$RESULT_FILE" || fail "Pending profiles must not leave a usable speaker selected."
grep -Eq '"failedProfileCanRetry"[[:space:]]*:[[:space:]]*true' "$RESULT_FILE" || fail "Failed profiles must expose an explicit retry contract."
grep -Eq '"retryReusesSameVoiceProfileId"[[:space:]]*:[[:space:]]*true' "$RESULT_FILE" || fail "Retry must keep the original voice profile ID."
grep -Eq '"retryGenerationAdvanced"[[:space:]]*:[[:space:]]*true' "$RESULT_FILE" || fail "Retry must advance retryGeneration."
grep -Eq '"retryPendingNotUsable"[[:space:]]*:[[:space:]]*true' "$RESULT_FILE" || fail "A retried pending profile must not be usable by Echo before preview acceptance."
grep -Eq '"deletionPendingRevokesUse"[[:space:]]*:[[:space:]]*true' "$RESULT_FILE" || fail "A pending deletion must revoke Echo use before provider cleanup completes."
grep -Eq '"deletionPendingCanRefresh"[[:space:]]*:[[:space:]]*true' "$RESULT_FILE" || fail "A pending deletion must retain a refresh path for provider receipt status."
grep -Eq '"pausedProfileCanDelete"[[:space:]]*:[[:space:]]*true' "$RESULT_FILE" || fail "A paused profile must remain eligible for owner-requested deletion."

xcrun simctl io "$SIMULATOR_UDID" screenshot "$SCREENSHOT_PATH" >/dev/null
xcrun simctl terminate "$SIMULATOR_UDID" "$BUNDLE_ID" >/dev/null 2>&1 || true

echo "[voice-clone-profile-selection-smoke] Build log: $BUILD_LOG"
echo "[voice-clone-profile-selection-smoke] Runtime log: $RUNTIME_LOG"
echo "[voice-clone-profile-selection-smoke] OS log: $OS_LOG"
echo "[voice-clone-profile-selection-smoke] Result: $RESULT_COPY_PATH"
echo "[voice-clone-profile-selection-smoke] Screenshot: $SCREENSHOT_PATH"

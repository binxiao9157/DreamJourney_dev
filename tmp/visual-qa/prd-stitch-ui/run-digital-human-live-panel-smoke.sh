#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../../.." && pwd)"

SCHEME="${SCHEME:-DreamJourney}"
CONFIGURATION="${CONFIGURATION:-Debug}"
SIMULATOR_NAME="${SIMULATOR_NAME:-iPhone 17}"
SWIFT_ACTIVE_COMPILATION_CONDITIONS='DEBUG UI_QA_SIMULATOR'
DERIVED_DATA_PATH="${DERIVED_DATA_PATH:-$ROOT_DIR/tmp/visual-qa/prd-stitch-ui/DerivedDataDigitalHumanLivePanelSmoke}"
OUTPUT_ROOT="${OUTPUT_ROOT:-$ROOT_DIR/tmp/visual-qa/prd-stitch-ui/digital-human-live-panel-smoke}"
RUN_ID="${RUN_ID:-$(date +%Y%m%d-%H%M%S)}"
OUTPUT_DIR="$OUTPUT_ROOT/$RUN_ID"
BUILD_LOG="$OUTPUT_DIR/build.log"
RUNTIME_LOG="$OUTPUT_DIR/runtime.log"
OS_LOG="$OUTPUT_DIR/oslog.log"
SCREENSHOT_PATH="$OUTPUT_DIR/01-digital-human-live-panel.png"
RESULT_COPY_PATH="$OUTPUT_DIR/digital-human-live-panel-smoke-result.json"
COMPLETION_PATTERN="DigitalHumanLivePanelSmoke completed"
LOG_WAIT_TIMEOUT="${LOG_WAIT_TIMEOUT:-60}"
DIGITAL_HUMAN_LIPSYNC_MODE="${DIGITAL_HUMAN_LIPSYNC_MODE:-avAudioPlayerMetering}"

mkdir -p "$OUTPUT_DIR"
cd "$ROOT_DIR"

fail() {
  echo "[digital-human-live-panel-smoke] $*" >&2
  if [[ -f "$RUNTIME_LOG" ]]; then
    echo "[digital-human-live-panel-smoke] runtime log tail:" >&2
    tail -100 "$RUNTIME_LOG" >&2 || true
  fi
  if [[ -f "$OS_LOG" ]]; then
    echo "[digital-human-live-panel-smoke] os log tail:" >&2
    tail -100 "$OS_LOG" >&2 || true
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

echo "[digital-human-live-panel-smoke] Building UIQA app..."
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

echo "[digital-human-live-panel-smoke] Installing $BUNDLE_ID on $SIMULATOR_UDID..."
xcrun simctl terminate "$SIMULATOR_UDID" "$BUNDLE_ID" >/dev/null 2>&1 || true
xcrun simctl uninstall "$SIMULATOR_UDID" "$BUNDLE_ID" >/dev/null 2>&1 || true
xcrun simctl install "$SIMULATOR_UDID" "$APP_PATH"
xcrun simctl spawn "$SIMULATOR_UDID" defaults delete "$BUNDLE_ID" >/dev/null 2>&1 || true
DATA_CONTAINER="$(xcrun simctl get_app_container "$SIMULATOR_UDID" "$BUNDLE_ID" data)"
RESULT_FILE="$DATA_CONTAINER/Documents/digital-human-live-panel-smoke-result.json"
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

echo "[digital-human-live-panel-smoke] Launching auto-run harness..."
LAUNCH_ARGS=(DJRunDigitalHumanLivePanelSmoke)
if [[ "$DIGITAL_HUMAN_LIPSYNC_MODE" == "providerVisemeTimeline" ]]; then
  LAUNCH_ARGS+=(DJDigitalHumanLipSyncProviderVisemeTimeline)
fi
xcrun simctl launch --console "$SIMULATOR_UDID" "$BUNDLE_ID" \
  "${LAUNCH_ARGS[@]}" > "$RUNTIME_LOG" 2>&1 &
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
grep -Eq '"panelVisible"[[:space:]]*:[[:space:]]*true' "$RESULT_FILE" || fail "Panel should be visible in QA smoke."
grep -Eq '"panelReady"[[:space:]]*:[[:space:]]*true' "$RESULT_FILE" || fail "Panel web bridge should be ready."
grep -Eq '"hasRealDigitalHumanAsset"[[:space:]]*:[[:space:]]*true' "$RESULT_FILE" || fail "Smoke must use the bundled real digital human asset."
grep -Eq '"assetVideoReady"[[:space:]]*:[[:space:]]*true' "$RESULT_FILE" || fail "Real digital human video asset should be ready."
grep -Eq '"hasFallbackAvatar"[[:space:]]*:[[:space:]]*false' "$RESULT_FILE" || fail "Fake fallback avatar must not be rendered."
grep -Eq '"stateName"[[:space:]]*:[[:space:]]*"speaking"' "$RESULT_FILE" || fail "Panel should reach speaking state."
grep -Eq '"audioLevel"[[:space:]]*:[[:space:]]*0\.[1-9]' "$RESULT_FILE" || fail "Audio/lip-sync level should drive mouth movement."
if [[ "$DIGITAL_HUMAN_LIPSYNC_MODE" == "providerVisemeTimeline" ]]; then
  grep -Eq '"lipSyncMode"[[:space:]]*:[[:space:]]*"providerVisemeTimeline"' "$RESULT_FILE" || fail "Smoke should run provider viseme timeline mode."
  grep -Eq '"audioLevelSource"[[:space:]]*:[[:space:]]*"providerVisemeTimeline"' "$RESULT_FILE" || fail "Mouth level should be driven by provider viseme timeline in UIQA."
  grep -Eq '"lipSyncSource"[[:space:]]*:[[:space:]]*"providerVisemeTimeline"' "$RESULT_FILE" || fail "Lip-sync source should report provider viseme timeline."
  grep -Eq '"lipSyncFrameCount"[[:space:]]*:[[:space:]]*[1-9]' "$RESULT_FILE" || fail "Provider timeline should contain frames."
  grep -Eq '"currentMouthShape"[[:space:]]*:[[:space:]]*"(aa|oh|ee|open)"' "$RESULT_FILE" || fail "Provider timeline should advance mouth shape."
else
  grep -Eq '"audioLevelSource"[[:space:]]*:[[:space:]]*"avAudioPlayerMetering"' "$RESULT_FILE" || fail "Mouth level should be driven by AVAudioPlayer metering in UIQA."
  grep -Eq '"meteringSampleCount"[[:space:]]*:[[:space:]]*[1-9]' "$RESULT_FILE" || fail "UIQA should collect player metering samples."
fi

xcrun simctl io "$SIMULATOR_UDID" screenshot "$SCREENSHOT_PATH" >/dev/null
xcrun simctl terminate "$SIMULATOR_UDID" "$BUNDLE_ID" >/dev/null 2>&1 || true

echo "[digital-human-live-panel-smoke] Build log: $BUILD_LOG"
echo "[digital-human-live-panel-smoke] Runtime log: $RUNTIME_LOG"
echo "[digital-human-live-panel-smoke] OS log: $OS_LOG"
echo "[digital-human-live-panel-smoke] Result: $RESULT_COPY_PATH"
echo "[digital-human-live-panel-smoke] Screenshot: $SCREENSHOT_PATH"

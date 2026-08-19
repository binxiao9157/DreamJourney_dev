#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../../.." && pwd)"

SCHEME="${SCHEME:-DreamJourney}"
CONFIGURATION="${CONFIGURATION:-Debug}"
SIMULATOR_NAME="${SIMULATOR_NAME:-iPhone 17}"
SWIFT_ACTIVE_COMPILATION_CONDITIONS='DEBUG UI_QA_SIMULATOR'
DERIVED_DATA_PATH="${DERIVED_DATA_PATH:-$ROOT_DIR/tmp/visual-qa/prd-stitch-ui/DerivedDataPublicationLifecycleM2Smoke}"
OUTPUT_ROOT="${OUTPUT_ROOT:-$ROOT_DIR/tmp/visual-qa/prd-stitch-ui/publication-lifecycle-m2-smoke}"
RUN_ID="${RUN_ID:-$(date +%Y%m%d-%H%M%S)}"
OUTPUT_DIR="$OUTPUT_ROOT/$RUN_ID"
BUILD_LOG="$OUTPUT_DIR/build.log"
RUNTIME_LOG="$OUTPUT_DIR/runtime.log"
OS_LOG="$OUTPUT_DIR/oslog.log"
SCREENSHOT_PATH="$OUTPUT_DIR/01-publication-lifecycle-m2.png"
RESULT_COPY_PATH="$OUTPUT_DIR/publication-lifecycle-m2-smoke-result.json"
COMPLETION_PATTERN="PublicationLifecycleM2Smoke completed"
LOG_WAIT_TIMEOUT="${LOG_WAIT_TIMEOUT:-45}"
LOCAL_BUNDLE_ID="${LOCAL_BUNDLE_ID:-com.yxj.dreamjourney.app}"

mkdir -p "$OUTPUT_DIR"
cd "$ROOT_DIR"

fail() {
  echo "[publication-lifecycle-m2-smoke] $*" >&2
  if [[ -f "$RUNTIME_LOG" ]]; then tail -80 "$RUNTIME_LOG" >&2 || true; fi
  if [[ -f "$OS_LOG" ]]; then tail -80 "$OS_LOG" >&2 || true; fi
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

echo "[publication-lifecycle-m2-smoke] Building UIQA app..."
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
  build > "$BUILD_LOG"

APP_PATH="$DERIVED_DATA_PATH/Build/Products/$CONFIGURATION-iphonesimulator/DreamJourney.app"
[[ -d "$APP_PATH" ]] || fail "Built app not found: $APP_PATH"
BUNDLE_ID="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$APP_PATH/Info.plist")"
[[ -n "$BUNDLE_ID" ]] || fail "Unable to read bundle id from $APP_PATH"

echo "[publication-lifecycle-m2-smoke] Installing $BUNDLE_ID on $SIMULATOR_UDID..."
xcrun simctl terminate "$SIMULATOR_UDID" "$BUNDLE_ID" >/dev/null 2>&1 || true
xcrun simctl uninstall "$SIMULATOR_UDID" "$BUNDLE_ID" >/dev/null 2>&1 || true
xcrun simctl install "$SIMULATOR_UDID" "$APP_PATH"
xcrun simctl spawn "$SIMULATOR_UDID" defaults delete "$BUNDLE_ID" >/dev/null 2>&1 || true
DATA_CONTAINER="$(xcrun simctl get_app_container "$SIMULATOR_UDID" "$BUNDLE_ID" data)"
RESULT_FILE="$DATA_CONTAINER/Documents/publication-lifecycle-m2-smoke-result.json"
rm -f "$RESULT_FILE"

CONSOLE_PID=""
OSLOG_PID=""
cleanup() {
  if [[ -n "$CONSOLE_PID" ]]; then kill "$CONSOLE_PID" >/dev/null 2>&1 || true; fi
  if [[ -n "$OSLOG_PID" ]]; then kill "$OSLOG_PID" >/dev/null 2>&1 || true; fi
}
trap cleanup EXIT

touch "$RUNTIME_LOG" "$OS_LOG"
xcrun simctl spawn "$SIMULATOR_UDID" log stream --style compact --level debug --predicate 'process == "DreamJourney"' > "$OS_LOG" 2>&1 &
OSLOG_PID="$!"
sleep 1

echo "[publication-lifecycle-m2-smoke] Launching auto-run harness..."
xcrun simctl launch --console "$SIMULATOR_UDID" "$BUNDLE_ID" \
  DJUITestBypassLogin \
  DJEnablePublicationManagementM2QA \
  DJEnablePublicationVisitorM2QA \
  DJEnablePublicationLifecycleM2QA \
  DJRunPublicationLifecycleM2Smoke > "$RUNTIME_LOG" 2>&1 &
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
grep -Eq '"managementGateEnabled"[[:space:]]*:[[:space:]]*true' "$RESULT_FILE" || fail "Owner management QA gate should be enabled."
grep -Eq '"visitorGateEnabled"[[:space:]]*:[[:space:]]*true' "$RESULT_FILE" || fail "Visitor QA gate should be enabled."
grep -Eq '"lifecycleGateEnabled"[[:space:]]*:[[:space:]]*true' "$RESULT_FILE" || fail "Lifecycle QA gate should be enabled."
grep -Eq '"featureFlagDefaultOff"[[:space:]]*:[[:space:]]*true' "$RESULT_FILE" || fail "M2 feature flag must remain default-off."
grep -Eq '"profileEntryVisible"[[:space:]]*:[[:space:]]*true' "$RESULT_FILE" || fail "Profile QA entry was not rendered."
grep -Eq '"withdrawButtonRendered"[[:space:]]*:[[:space:]]*true' "$RESULT_FILE" || fail "Withdraw control was not rendered."
grep -Eq '"receiptRendered"[[:space:]]*:[[:space:]]*true' "$RESULT_FILE" || fail "Withdrawal receipt was not rendered."
grep -Eq '"grantRevokedRendered"[[:space:]]*:[[:space:]]*true' "$RESULT_FILE" || fail "Revoked grant state was not rendered."
grep -Eq '"fixtureWithdrawalObserved"[[:space:]]*:[[:space:]]*true' "$RESULT_FILE" || fail "Fixture did not observe the withdrawal."
grep -Eq '"visitorShellRendered"[[:space:]]*:[[:space:]]*true' "$RESULT_FILE" || fail "Visitor product shell was not rendered."
grep -Eq '"visitorProjectionRendered"[[:space:]]*:[[:space:]]*true' "$RESULT_FILE" || fail "Visitor public projection was not rendered."
grep -Eq '"visitorOrdinaryVoiceRendered"[[:space:]]*:[[:space:]]*true' "$RESULT_FILE" || fail "Visitor ordinary voice control was not rendered."
grep -Eq '"managementLaunchArgument"[[:space:]]*:[[:space:]]*"DJEnablePublicationManagementM2QA"' "$RESULT_FILE" || fail "Management launch argument drifted."
grep -Eq '"visitorLaunchArgument"[[:space:]]*:[[:space:]]*"DJEnablePublicationVisitorM2QA"' "$RESULT_FILE" || fail "Visitor launch argument drifted."
grep -Eq '"lifecycleLaunchArgument"[[:space:]]*:[[:space:]]*"DJEnablePublicationLifecycleM2QA"' "$RESULT_FILE" || fail "Lifecycle launch argument drifted."

sleep 1
xcrun simctl io "$SIMULATOR_UDID" screenshot "$SCREENSHOT_PATH" >/dev/null
xcrun simctl terminate "$SIMULATOR_UDID" "$BUNDLE_ID" >/dev/null 2>&1 || true

echo "[publication-lifecycle-m2-smoke] Build log: $BUILD_LOG"
echo "[publication-lifecycle-m2-smoke] Runtime log: $RUNTIME_LOG"
echo "[publication-lifecycle-m2-smoke] OS log: $OS_LOG"
echo "[publication-lifecycle-m2-smoke] Result: $RESULT_COPY_PATH"
echo "[publication-lifecycle-m2-smoke] Screenshot: $SCREENSHOT_PATH"

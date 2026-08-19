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
DERIVED_DATA_PATH="${DERIVED_DATA_PATH:-$ROOT_DIR/tmp/visual-qa/prd-stitch-ui/DerivedDataProfileFamilyPersonaReleaseSmoke}"
OUTPUT_ROOT="${OUTPUT_ROOT:-$ROOT_DIR/tmp/visual-qa/prd-stitch-ui/profile-family-persona-release-smoke}"
RUN_ID="${RUN_ID:-$(date +%Y%m%d-%H%M%S)}"
OUTPUT_DIR="$OUTPUT_ROOT/$RUN_ID"
BUILD_LOG="$OUTPUT_DIR/build.log"
RUNTIME_LOG="$OUTPUT_DIR/runtime.log"
OS_LOG="$OUTPUT_DIR/oslog.log"
SCREENSHOT_PATH="$OUTPUT_DIR/01-profile-family-persona-release.png"
RESULT_COPY_PATH="$OUTPUT_DIR/profile-family-persona-release-smoke-result.json"
COMPLETION_PATTERN="ProfileFamilyPersonaReleaseSmoke completed"
LOG_WAIT_TIMEOUT="${LOG_WAIT_TIMEOUT:-45}"

mkdir -p "$OUTPUT_DIR"
cd "$ROOT_DIR"

fail() {
  echo "[profile-family-persona-release-smoke] $*" >&2
  if [[ -f "$RUNTIME_LOG" ]]; then
    echo "[profile-family-persona-release-smoke] runtime log tail:" >&2
    tail -80 "$RUNTIME_LOG" >&2 || true
  fi
  if [[ -f "$OS_LOG" ]]; then
    echo "[profile-family-persona-release-smoke] os log tail:" >&2
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

echo "[profile-family-persona-release-smoke] Building UIQA app..."
xcodebuild \
  -workspace DreamJourney.xcworkspace \
  -scheme "$SCHEME" \
  -configuration "$CONFIGURATION" \
  -sdk iphonesimulator \
  -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath "$DERIVED_DATA_PATH" \
  CODE_SIGNING_ALLOWED=NO \
  DREAMJOURNEY_PRODUCT_BUNDLE_IDENTIFIER="$LOCAL_BUNDLE_ID" \
  DREAMJOURNEY_DEVELOPMENT_TEAM="$LOCAL_DEVELOPMENT_TEAM" \
  SWIFT_ACTIVE_COMPILATION_CONDITIONS="$SWIFT_ACTIVE_COMPILATION_CONDITIONS" \
  EXCLUDED_ARCHS='' \
  ARCHS=arm64 \
  ONLY_ACTIVE_ARCH=NO \
  build > "$BUILD_LOG"

APP_PATH="$DERIVED_DATA_PATH/Build/Products/$CONFIGURATION-iphonesimulator/DreamJourney.app"
[[ -d "$APP_PATH" ]] || fail "Built app not found: $APP_PATH"

BUNDLE_ID="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$APP_PATH/Info.plist")"
[[ -n "$BUNDLE_ID" ]] || fail "Unable to read bundle id from $APP_PATH"

echo "[profile-family-persona-release-smoke] Installing $BUNDLE_ID on $SIMULATOR_UDID..."
xcrun simctl terminate "$SIMULATOR_UDID" "$BUNDLE_ID" >/dev/null 2>&1 || true
xcrun simctl uninstall "$SIMULATOR_UDID" "$BUNDLE_ID" >/dev/null 2>&1 || true
xcrun simctl install "$SIMULATOR_UDID" "$APP_PATH"
xcrun simctl spawn "$SIMULATOR_UDID" defaults delete "$BUNDLE_ID" >/dev/null 2>&1 || true
DATA_CONTAINER="$(xcrun simctl get_app_container "$SIMULATOR_UDID" "$BUNDLE_ID" data)"
RESULT_FILE="$DATA_CONTAINER/Documents/profile-family-persona-release-smoke-result.json"
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

echo "[profile-family-persona-release-smoke] Launching auto-run harness..."
xcrun simctl launch --console "$SIMULATOR_UDID" "$BUNDLE_ID" DJUITestBypassLogin DJRunProfileFamilyPersonaReleaseSmoke > "$RUNTIME_LOG" 2>&1 &
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
grep -Eq '"releaseRowVisible"[[:space:]]*:[[:space:]]*false' "$RESULT_FILE" || fail "Family row should stay hidden in default release mode."
grep -Eq '"familyManagementOnlyRowVisible"[[:space:]]*:[[:space:]]*true' "$RESULT_FILE" || fail "familyManagement should expose the signed-in product row when runtime is publicly ready."
grep -Eq '"familyManagementOnlyCanOpenSwitcher"[[:space:]]*:[[:space:]]*true' "$RESULT_FILE" || fail "familyManagement should open the signed-in family surface when runtime is publicly ready."
grep -Eq '"familySpaceCanOpenSwitcher"[[:space:]]*:[[:space:]]*true' "$RESULT_FILE" || fail "familySpace should open the signed-in family switcher when runtime is publicly ready."
grep -Eq '"hiddenBranchesCanOpenSwitcher"[[:space:]]*:[[:space:]]*true' "$RESULT_FILE" || fail "Hidden QA launch should open persona switcher."
grep -Eq '"profileTabSelected"[[:space:]]*:[[:space:]]*true' "$RESULT_FILE" || fail "Smoke should select the profile tab before screenshot."
grep -Eq '"familyMemberCount"[[:space:]]*:[[:space:]]*[1-9]' "$RESULT_FILE" || fail "Family repository should provide at least one persona option."
grep -Eq '"backendFamilyDigitalHumanMode"[[:space:]]*:[[:space:]]*"star"' "$RESULT_FILE" || fail "Backend-derived family mode should be parsed as star."
grep -Eq '"backendFamilyPersonaContractVersion"[[:space:]]*:[[:space:]]*1' "$RESULT_FILE" || fail "Backend-derived family contract version should be 1."
grep -Eq '"backendFamilyContractMode"[[:space:]]*:[[:space:]]*"mockFamilyPersona"' "$RESULT_FILE" || fail "Backend-derived family contract mode should be mockFamilyPersona."
grep -Eq '"backendFamilyDefaultReleaseVisible"[[:space:]]*:[[:space:]]*false' "$RESULT_FILE" || fail "Backend-derived family member must stay hidden by default."
grep -Eq '"backendFamilyRenderedInRepository"[[:space:]]*:[[:space:]]*true' "$RESULT_FILE" || fail "Backend-derived family member should be rendered through FamilyRepository."
grep -Eq '"backendVoiceProfileId"[[:space:]]*:[[:space:]]*"voice_profile_uiqa_backend"' "$RESULT_FILE" || fail "Backend-derived voice profile id should be consumed."
grep -Eq '"backendVoiceSampleStatus"[[:space:]]*:[[:space:]]*"pending"' "$RESULT_FILE" || fail "Backend-derived voice sample status should be pending."
grep -Eq '"backendVoiceProviderMode"[[:space:]]*:[[:space:]]*"mockContract"' "$RESULT_FILE" || fail "Backend-derived voice provider mode should be mockContract."
grep -Eq '"backendVoiceDefaultReleaseVisible"[[:space:]]*:[[:space:]]*false' "$RESULT_FILE" || fail "Backend-derived voice shell must stay hidden by default."
grep -Eq '"backendVoiceShellRendered"[[:space:]]*:[[:space:]]*true' "$RESULT_FILE" || fail "Backend-derived voice shell should render."
grep -Eq '"hiddenBranchesArgument"[[:space:]]*:[[:space:]]*"DJEnableProfileHiddenBranches"' "$RESULT_FILE" || fail "Hidden launch argument changed."
grep -Eq '"unavailableTitle"[[:space:]]*:[[:space:]]*"家人管理暂不可用"' "$RESULT_FILE" || fail "Unavailable copy changed."

sleep 1
xcrun simctl io "$SIMULATOR_UDID" screenshot "$SCREENSHOT_PATH" >/dev/null
xcrun simctl terminate "$SIMULATOR_UDID" "$BUNDLE_ID" >/dev/null 2>&1 || true

echo "[profile-family-persona-release-smoke] Build log: $BUILD_LOG"
echo "[profile-family-persona-release-smoke] Runtime log: $RUNTIME_LOG"
echo "[profile-family-persona-release-smoke] OS log: $OS_LOG"
echo "[profile-family-persona-release-smoke] Result: $RESULT_COPY_PATH"
echo "[profile-family-persona-release-smoke] Screenshot: $SCREENSHOT_PATH"

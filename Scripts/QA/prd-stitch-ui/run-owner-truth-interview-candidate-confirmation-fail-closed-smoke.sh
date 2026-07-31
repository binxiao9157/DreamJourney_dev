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
DERIVED_DATA_PATH="${DERIVED_DATA_PATH:-$ROOT_DIR/tmp/visual-qa/product-v4/DerivedDataOwnerTruthCandidateConfirmationFailClosedSmoke}"
SMOKE_VARIANT="${SMOKE_VARIANT:-response-mismatch}"
case "$SMOKE_VARIANT" in
  response-mismatch)
    SMOKE_ID="owner-truth-interview-candidate-confirmation-fail-closed-smoke"
    LAUNCH_SCENARIO="DJRunOwnerTruthInterviewCandidateConfirmationFailClosedSmoke"
    RESULT_FILE_NAME="owner-truth-interview-candidate-confirmation-fail-closed-smoke-result.json"
    COMPLETION_PATTERN="OwnerTruthInterviewCandidateConfirmationFailClosedSmoke completed"
    EXPECTED_FAILURE_DISPOSITION="responseMismatch"
    ;;
  source-inactive)
    SMOKE_ID="owner-truth-interview-candidate-confirmation-source-inactive-smoke"
    LAUNCH_SCENARIO="DJRunOwnerTruthInterviewCandidateConfirmationSourceInactiveSmoke"
    RESULT_FILE_NAME="owner-truth-interview-candidate-confirmation-source-inactive-smoke-result.json"
    COMPLETION_PATTERN="OwnerTruthInterviewCandidateConfirmationSourceInactiveSmoke completed"
    EXPECTED_FAILURE_DISPOSITION="sourceInactive"
    ;;
  *)
    printf 'Unsupported SMOKE_VARIANT: %s\n' "$SMOKE_VARIANT" >&2
    exit 2
    ;;
esac
OUTPUT_ROOT="${OUTPUT_ROOT:-$ROOT_DIR/tmp/visual-qa/product-v4/$SMOKE_ID}"
RUN_ID="${RUN_ID:-$(date +%Y%m%d-%H%M%S)}"
OUTPUT_DIR="$OUTPUT_ROOT/$RUN_ID"
BUILD_LOG="$OUTPUT_DIR/build.log"
RUNTIME_LOG="$OUTPUT_DIR/runtime.log"
OS_LOG="$OUTPUT_DIR/oslog.log"
SCREENSHOT_PATH="$OUTPUT_DIR/01-$SMOKE_ID.png"
RESULT_COPY_PATH="$OUTPUT_DIR/$RESULT_FILE_NAME"
LOG_WAIT_TIMEOUT="${LOG_WAIT_TIMEOUT:-45}"

mkdir -p "$OUTPUT_DIR"
cd "$ROOT_DIR"

fail() {
  printf '[%s] %s\n' "$SMOKE_ID" "$*" >&2
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

printf '[%s] Building UIQA app...\n' "$SMOKE_ID"
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
[[ "$BUNDLE_ID" == "$LOCAL_BUNDLE_ID" ]] || fail "Built app bundle id is $BUNDLE_ID, expected $LOCAL_BUNDLE_ID"
[[ "$BUNDLE_ID" != "com.gaominge.dreamjourney.app" ]] || fail "Built app is using the shared default bundle id."

printf '[%s] Installing %s on %s...\n' "$SMOKE_ID" "$BUNDLE_ID" "$SIMULATOR_UDID"
xcrun simctl terminate "$SIMULATOR_UDID" "$BUNDLE_ID" >/dev/null 2>&1 || true
xcrun simctl uninstall "$SIMULATOR_UDID" "$BUNDLE_ID" >/dev/null 2>&1 || true
xcrun simctl install "$SIMULATOR_UDID" "$APP_PATH"
xcrun simctl spawn "$SIMULATOR_UDID" defaults delete "$BUNDLE_ID" >/dev/null 2>&1 || true
DATA_CONTAINER="$(xcrun simctl get_app_container "$SIMULATOR_UDID" "$BUNDLE_ID" data)"
RESULT_FILE="$DATA_CONTAINER/Documents/$RESULT_FILE_NAME"
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

printf '[%s] Launching in-memory confirmation detail fixture...\n' "$SMOKE_ID"
xcrun simctl launch --console "$SIMULATOR_UDID" "$BUNDLE_ID" \
  DJUITestBypassLogin \
  "$LAUNCH_SCENARIO" > "$RUNTIME_LOG" 2>&1 &
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

grep -Eq '"completed"[[:space:]]*:[[:space:]]*true' "$RESULT_FILE" || fail "Fail-closed UIQA did not complete."
grep -Eq '"inMemoryFixture"[[:space:]]*:[[:space:]]*true' "$RESULT_FILE" || fail "Smoke must use the in-memory fixture."
grep -Eq '"candidateRouteNetworkRequests"[[:space:]]*:[[:space:]]*0' "$RESULT_FILE" || fail "Candidate route must not issue a real network request."
grep -Eq '"persistentCandidateWrites"[[:space:]]*:[[:space:]]*0' "$RESULT_FILE" || fail "Candidate route must not write persistent data."
grep -Eq "\"failureDisposition\"[[:space:]]*:[[:space:]]*\"${EXPECTED_FAILURE_DISPOSITION}\"" "$RESULT_FILE" || fail "Smoke did not report the expected fail-closed disposition."
grep -Eq '"initialCandidateVisible"[[:space:]]*:[[:space:]]*true' "$RESULT_FILE" || fail "Fixture candidate did not render before submission."
grep -Eq '"actionRequestCount"[[:space:]]*:[[:space:]]*1' "$RESULT_FILE" || fail "Confirmation action must submit exactly once."
grep -Eq '"confirmationReadCount"[[:space:]]*:[[:space:]]*2' "$RESULT_FILE" || fail "Fail-closed path must begin exactly one fresh read."
grep -Eq '"oldCandidateClearedDuringReload"[[:space:]]*:[[:space:]]*true' "$RESULT_FILE" || fail "Old candidate content remained visible during reload."
grep -Eq '"batchSubmitHiddenDuringReload"[[:space:]]*:[[:space:]]*true' "$RESULT_FILE" || fail "Batch submit must be hidden during fail-closed reload."
grep -Eq '"batchSubmitDisabledDuringReload"[[:space:]]*:[[:space:]]*true' "$RESULT_FILE" || fail "Batch submit must be disabled during fail-closed reload."
grep -Eq '"listInteractionDisabledDuringReload"[[:space:]]*:[[:space:]]*true' "$RESULT_FILE" || fail "Candidate list must be locked during fail-closed reload."
grep -Eq '"refreshDisabledDuringReload"[[:space:]]*:[[:space:]]*true' "$RESULT_FILE" || fail "Refresh must be locked during fail-closed reload."
grep -Eq '"staleActionStatusVisibleDuringReload"[[:space:]]*:[[:space:]]*true' "$RESULT_FILE" || fail "Fail-closed status copy did not remain visible during reload."
case "$SMOKE_VARIANT" in
  response-mismatch)
    grep -Eq '"finalPhase"[[:space:]]*:[[:space:]]*"empty"' "$RESULT_FILE" || fail "Fresh read should resolve to an empty confirmation detail."
    grep -Eq '"finalCandidateCount"[[:space:]]*:[[:space:]]*0' "$RESULT_FILE" || fail "Fresh read must not restore the stale candidate."
    ;;
  source-inactive)
    grep -Eq '"terminalSourceInactiveState"[[:space:]]*:[[:space:]]*true' "$RESULT_FILE" || fail "Source inactive must resolve to a terminal unavailable state."
    grep -Eq '"finalPhase"[[:space:]]*:[[:space:]]*"unavailable"' "$RESULT_FILE" || fail "Source inactive must not fall back to a retryable state."
    grep -Eq '"finalCandidateCount"[[:space:]]*:[[:space:]]*0' "$RESULT_FILE" || fail "Source inactive must clear all candidates."
    grep -Eq '"finalListInteractionEnabled"[[:space:]]*:[[:space:]]*false' "$RESULT_FILE" || fail "Source inactive must lock candidate interaction."
    grep -Eq '"finalRefreshEnabled"[[:space:]]*:[[:space:]]*false' "$RESULT_FILE" || fail "Source inactive must disable refresh."
    grep -Eq '"finalStatusText"[[:space:]]*:[[:space:]]*"本次待确认内容已失效，无法继续确认。"' "$RESULT_FILE" || fail "Source inactive terminal status is missing."
    grep -Eq '"finalEmptyStateText"[[:space:]]*:[[:space:]]*"本次待确认内容已失效，旧线索已清除。"' "$RESULT_FILE" || fail "Source inactive empty state is missing."
    ;;
esac
grep -Fq "\"$LAUNCH_SCENARIO\"" "$RESULT_FILE" || fail "Launch scenario drifted."

xcrun simctl io "$SIMULATOR_UDID" screenshot "$SCREENSHOT_PATH" >/dev/null
xcrun simctl terminate "$SIMULATOR_UDID" "$BUNDLE_ID" >/dev/null 2>&1 || true

printf '[%s] Build log: %s\n' "$SMOKE_ID" "$BUILD_LOG"
printf '[%s] Runtime log: %s\n' "$SMOKE_ID" "$RUNTIME_LOG"
printf '[%s] OS log: %s\n' "$SMOKE_ID" "$OS_LOG"
printf '[%s] Result: %s\n' "$SMOKE_ID" "$RESULT_COPY_PATH"
printf '[%s] Screenshot: %s\n' "$SMOKE_ID" "$SCREENSHOT_PATH"

#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../../.." && pwd)"

SCHEME="${SCHEME:-DreamJourney}"
CONFIGURATION="${CONFIGURATION:-Debug}"
SIMULATOR_NAME="${SIMULATOR_NAME:-iPhone 17}"
SWIFT_ACTIVE_COMPILATION_CONDITIONS='DEBUG UI_QA_SIMULATOR'
DERIVED_DATA_PATH="${DERIVED_DATA_PATH:-$ROOT_DIR/tmp/visual-qa/prd-stitch-ui/DerivedDataArchiveHiddenShellSmoke}"
OUTPUT_ROOT="${OUTPUT_ROOT:-$ROOT_DIR/tmp/visual-qa/prd-stitch-ui/archive-hidden-shell-smoke}"
RUN_ID="${RUN_ID:-$(date +%Y%m%d-%H%M%S)}"
OUTPUT_DIR="$OUTPUT_ROOT/$RUN_ID"
BUILD_LOG="$OUTPUT_DIR/build.log"
RUNTIME_LOG="$OUTPUT_DIR/runtime.log"
OS_LOG="$OUTPUT_DIR/oslog.log"
SCREENSHOT_PATH="$OUTPUT_DIR/01-archive-hidden-shell.png"
RESULT_COPY_PATH="$OUTPUT_DIR/archive-hidden-shell-smoke-result.json"
COMPLETION_PATTERN="ArchiveHiddenShellSmoke completed"
LOG_WAIT_TIMEOUT="${LOG_WAIT_TIMEOUT:-45}"
DETAIL_SNAPSHOT_FILES=(
  "archive-hidden-audio-empty-detail.png"
  "archive-hidden-audio-transcription-failed-detail.png"
  "archive-hidden-video-failed-detail.png"
  "archive-hidden-time-letter-draft-detail.png"
  "archive-hidden-time-letter-sealed-detail.png"
)

mkdir -p "$OUTPUT_DIR"
cd "$ROOT_DIR"

fail() {
  echo "[archive-hidden-shell-smoke] $*" >&2
  if [[ -f "$RUNTIME_LOG" ]]; then
    echo "[archive-hidden-shell-smoke] runtime log tail:" >&2
    tail -80 "$RUNTIME_LOG" >&2 || true
  fi
  if [[ -f "$OS_LOG" ]]; then
    echo "[archive-hidden-shell-smoke] os log tail:" >&2
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

echo "[archive-hidden-shell-smoke] Building UIQA app..."
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

echo "[archive-hidden-shell-smoke] Installing $BUNDLE_ID on $SIMULATOR_UDID..."
xcrun simctl terminate "$SIMULATOR_UDID" "$BUNDLE_ID" >/dev/null 2>&1 || true
xcrun simctl uninstall "$SIMULATOR_UDID" "$BUNDLE_ID" >/dev/null 2>&1 || true
xcrun simctl install "$SIMULATOR_UDID" "$APP_PATH"
xcrun simctl spawn "$SIMULATOR_UDID" defaults delete "$BUNDLE_ID" >/dev/null 2>&1 || true
DATA_CONTAINER="$(xcrun simctl get_app_container "$SIMULATOR_UDID" "$BUNDLE_ID" data)"
RESULT_FILE="$DATA_CONTAINER/Documents/archive-hidden-shell-smoke-result.json"
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

echo "[archive-hidden-shell-smoke] Launching auto-run harness..."
xcrun simctl launch --console "$SIMULATOR_UDID" "$BUNDLE_ID" \
  DJUITestBypassLogin \
  DJEnableArchiveHiddenBranches \
  DJRunArchiveHiddenShellSmoke > "$RUNTIME_LOG" 2>&1 &
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

for snapshot_file in "${DETAIL_SNAPSHOT_FILES[@]}"; do
  snapshot_source="$DATA_CONTAINER/Documents/$snapshot_file"
  [[ -s "$snapshot_source" ]] || fail "Expected detail snapshot was not written: $snapshot_file"
  cp "$snapshot_source" "$OUTPUT_DIR/$snapshot_file"
done

grep -Eq '"completed"[[:space:]]*:[[:space:]]*true' "$RESULT_FILE" || fail "Smoke did not complete."
grep -Eq '"releaseOptionsHidden"[[:space:]]*:[[:space:]]*true' "$RESULT_FILE" || fail "Hidden archive branches must stay hidden in release mode."
grep -Eq '"hiddenOptionsVisible"[[:space:]]*:[[:space:]]*true' "$RESULT_FILE" || fail "Hidden archive branches should be visible in hidden QA mode."
grep -Eq '"audioRestored"[[:space:]]*:[[:space:]]*true' "$RESULT_FILE" || fail "Audio shell item should restore from local storage."
grep -Eq '"audioTranscriptPersisted"[[:space:]]*:[[:space:]]*true' "$RESULT_FILE" || fail "Audio transcript field should persist."
grep -Eq '"videoRestored"[[:space:]]*:[[:space:]]*true' "$RESULT_FILE" || fail "Video shell item should restore from local storage."
grep -Eq '"videoThumbnailPersisted"[[:space:]]*:[[:space:]]*true' "$RESULT_FILE" || fail "Video thumbnail field should persist."
grep -Eq '"videoAnalysisPending"[[:space:]]*:[[:space:]]*true' "$RESULT_FILE" || fail "Video shell should stay in pending analysis state."
grep -Eq '"mediaUploadUploaded"[[:space:]]*:[[:space:]]*true' "$RESULT_FILE" || fail "Audio mock upload should reach uploaded state."
grep -Eq '"mediaUploadFailed"[[:space:]]*:[[:space:]]*true' "$RESULT_FILE" || fail "Video mock upload should retain failed state for retry."
grep -Eq '"timeLetterDraftRestored"[[:space:]]*:[[:space:]]*true' "$RESULT_FILE" || fail "Time-letter draft should restore."
grep -Eq '"timeLetterSealedRestored"[[:space:]]*:[[:space:]]*true' "$RESULT_FILE" || fail "Time-letter sealed state should restore."
grep -Eq '"timeLetterDraftEdited"[[:space:]]*:[[:space:]]*true' "$RESULT_FILE" || fail "Time-letter draft edit should persist."
grep -Eq '"timeLetterDraftDeleted"[[:space:]]*:[[:space:]]*true' "$RESULT_FILE" || fail "Time-letter draft delete should persist."
grep -Eq '"timeLetterDraftSealed"[[:space:]]*:[[:space:]]*true' "$RESULT_FILE" || fail "Time-letter draft seal should persist."
grep -Eq '"mediaDetailEmptyStateVisible"[[:space:]]*:[[:space:]]*true' "$RESULT_FILE" || fail "Hidden audio empty detail state should be visible."
grep -Eq '"mediaDetailFailedStateVisible"[[:space:]]*:[[:space:]]*true' "$RESULT_FILE" || fail "Hidden media failed detail state should be visible."
grep -Eq '"mediaDetailRetryActionVisible"[[:space:]]*:[[:space:]]*true' "$RESULT_FILE" || fail "Hidden media retry detail action should be visible."
grep -Eq '"audioDetailEmptyStateVisible"[[:space:]]*:[[:space:]]*true' "$RESULT_FILE" || fail "Audio empty detail state should be visible."
grep -Eq '"audioDetailTranscriptionFailedStateVisible"[[:space:]]*:[[:space:]]*true' "$RESULT_FILE" || fail "Audio transcription failed state should be visible."
grep -Eq '"audioDetailTranscriptionRetryVisible"[[:space:]]*:[[:space:]]*true' "$RESULT_FILE" || fail "Audio transcription retry copy should be visible."
grep -Eq '"videoDetailThumbnailPlaceholderVisible"[[:space:]]*:[[:space:]]*true' "$RESULT_FILE" || fail "Video thumbnail placeholder should be visible."
grep -Eq '"videoDetailFailedStateVisible"[[:space:]]*:[[:space:]]*true' "$RESULT_FILE" || fail "Video failed detail state should be visible."
grep -Eq '"videoDetailRetryActionVisible"[[:space:]]*:[[:space:]]*true' "$RESULT_FILE" || fail "Video retry action should be visible."
grep -Eq '"hiddenMediaRuntimeCardVisible"[[:space:]]*:[[:space:]]*true' "$RESULT_FILE" || fail "Hidden media runtime capability card should be visible."
grep -Eq '"hiddenMediaRuntimeProviderVisible"[[:space:]]*:[[:space:]]*true' "$RESULT_FILE" || fail "Hidden media runtime provider should be visible."
grep -Eq '"hiddenMediaRuntimeLimitVisible"[[:space:]]*:[[:space:]]*true' "$RESULT_FILE" || fail "Hidden media runtime file-size limit should be visible."
grep -Eq '"hiddenMediaRuntimeUploadModeVisible"[[:space:]]*:[[:space:]]*true' "$RESULT_FILE" || fail "Hidden media runtime upload mode should be visible."
grep -Eq '"hiddenMediaRuntimeMockCopyVisible"[[:space:]]*:[[:space:]]*true' "$RESULT_FILE" || fail "Hidden media runtime mock provider copy should be visible."
grep -Eq '"timeLetterDraftActionsVisible"[[:space:]]*:[[:space:]]*true' "$RESULT_FILE" || fail "Time-letter draft detail actions should be visible."
grep -Eq '"timeLetterSealedStateVisible"[[:space:]]*:[[:space:]]*true' "$RESULT_FILE" || fail "Time-letter sealed detail state should be visible."
grep -Eq '"timeLetterDraftDetailVisible"[[:space:]]*:[[:space:]]*true' "$RESULT_FILE" || fail "Time-letter draft detail state should be visible."
grep -Eq '"timeLetterSealedDetailVisible"[[:space:]]*:[[:space:]]*true' "$RESULT_FILE" || fail "Time-letter sealed detail state should be visible."
grep -Eq '"timeLetterEmptyBodyVisible"[[:space:]]*:[[:space:]]*true' "$RESULT_FILE" || fail "Time-letter empty body state should be visible."
grep -Eq '"audioEmptyDetailSnapshotWritten"[[:space:]]*:[[:space:]]*true' "$RESULT_FILE" || fail "Audio empty detail snapshot should be written."
grep -Eq '"audioTranscriptionFailedDetailSnapshotWritten"[[:space:]]*:[[:space:]]*true' "$RESULT_FILE" || fail "Audio transcription failed detail snapshot should be written."
grep -Eq '"videoFailedDetailSnapshotWritten"[[:space:]]*:[[:space:]]*true' "$RESULT_FILE" || fail "Video failed detail snapshot should be written."
grep -Eq '"timeLetterDraftDetailSnapshotWritten"[[:space:]]*:[[:space:]]*true' "$RESULT_FILE" || fail "Time-letter draft detail snapshot should be written."
grep -Eq '"timeLetterSealedDetailSnapshotWritten"[[:space:]]*:[[:space:]]*true' "$RESULT_FILE" || fail "Time-letter sealed detail snapshot should be written."
grep -Eq '"releaseHiddenEntryPointsBlocked"[[:space:]]*:[[:space:]]*true' "$RESULT_FILE" || fail "Release mode should keep hidden media/time-letter entry points blocked."
grep -Eq '"hiddenBranchesArgument"[[:space:]]*:[[:space:]]*"DJEnableArchiveHiddenBranches"' "$RESULT_FILE" || fail "Hidden archive launch argument changed."

xcrun simctl io "$SIMULATOR_UDID" screenshot "$SCREENSHOT_PATH" >/dev/null
xcrun simctl terminate "$SIMULATOR_UDID" "$BUNDLE_ID" >/dev/null 2>&1 || true

echo "[archive-hidden-shell-smoke] Build log: $BUILD_LOG"
echo "[archive-hidden-shell-smoke] Runtime log: $RUNTIME_LOG"
echo "[archive-hidden-shell-smoke] OS log: $OS_LOG"
echo "[archive-hidden-shell-smoke] Result: $RESULT_COPY_PATH"
echo "[archive-hidden-shell-smoke] Screenshot: $SCREENSHOT_PATH"

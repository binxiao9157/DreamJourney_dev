#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../../.." && pwd)"
RUN_ID="${RUN_ID:-$(date +%Y%m%d-%H%M%S)-release-qa-override-artifact}"
OUTPUT_ROOT="${OUTPUT_ROOT:-$ROOT_DIR/tmp/visual-qa/prd-stitch-ui/release-qa-override-artifact}"
OUTPUT_DIR="$OUTPUT_ROOT/$RUN_ID"
REPORT_PATH="$OUTPUT_DIR/report.md"
STRINGS_PATH="$OUTPUT_DIR/executable-strings.txt"
SYMBOLS_PATH="$OUTPUT_DIR/demangled-symbols.txt"
MATCHES_PATH="$OUTPUT_DIR/forbidden-matches.txt"
APP_PATH="${APP_PATH:-}"

mkdir -p "$OUTPUT_DIR"

fail() {
  {
    echo
    echo "## Result"
    echo
    echo "- Status: failed"
    echo "- Reason: $*"
  } >> "$REPORT_PATH"
  echo "[release-qa-override-artifact] $*" >&2
  exit 1
}

cat > "$REPORT_PATH" <<REPORT
# Release QA Override Artifact Scan

- Run ID: \`$RUN_ID\`
- Configuration: \`Release\`
- SDK: \`iphoneos\`

REPORT

if [[ -z "$APP_PATH" ]]; then
  BUILD_RUN_ID="release-build"
  CONFIGURATION=Release \
  RUN_ID="$BUILD_RUN_ID" \
  OUTPUT_ROOT="$OUTPUT_DIR" \
  DERIVED_DATA_PATH="$OUTPUT_DIR/$BUILD_RUN_ID/DerivedData" \
    "$SCRIPT_DIR/run-iphoneos-generic-build.sh"
  APP_PATH="$OUTPUT_DIR/$BUILD_RUN_ID/DerivedData/Build/Products/Release-iphoneos/DreamJourney.app"
fi

[[ -d "$APP_PATH" ]] || fail "Release app not found: $APP_PATH"

EXECUTABLE_NAME="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleExecutable' "$APP_PATH/Info.plist")"
EXECUTABLE_PATH="$APP_PATH/$EXECUTABLE_NAME"
[[ -f "$EXECUTABLE_PATH" ]] || fail "Release executable not found: $EXECUTABLE_PATH"

LC_ALL=C strings "$EXECUTABLE_PATH" > "$STRINGS_PATH"
(nm -j "$EXECUTABLE_PATH" 2>/dev/null || true) | xcrun swift-demangle > "$SYMBOLS_PATH"

FORBIDDEN_PATTERN='DJ(Run|Show|Seed|Enable|DisableDigitalHumanLivePanel|UseLocalDigitalHumanAssetOverride|TencentBackendPCMDrive|DigitalHumanLipSyncProviderVisemeTimeline|VoiceCloneProbe)'
if rg -n "$FORBIDDEN_PATTERN" "$STRINGS_PATH" > "$MATCHES_PATH"; then
  fail "QA launch arguments are present in the Release executable; see $MATCHES_PATH"
fi

if rg -n 'enableForCurrentLaunch' "$SYMBOLS_PATH" > "$MATCHES_PATH"; then
  fail "process-only QA setter is present in the Release executable; see $MATCHES_PATH"
fi

if /usr/libexec/PlistBuddy \
  -c 'Print :DreamJourneyDigitalHumanAssetVirtualmanKey' \
  "$APP_PATH/Info.plist" >/dev/null 2>&1; then
  fail "legacy local Tencent asset override is present in the Release Info.plist"
fi

{
  echo "## Result"
  echo
  echo "- Status: passed"
  echo "- Release app: \`$APP_PATH\`"
  echo "- QA launch arguments: absent"
  echo "- QA process setter symbol: absent"
  echo "- Persistent Tencent asset override: absent"
} >> "$REPORT_PATH"

rm -f "$MATCHES_PATH"
echo "[release-qa-override-artifact] passed"
echo "[release-qa-override-artifact] Report: $REPORT_PATH"

#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../../.." && pwd)"
RUN_ID="${RUN_ID:-$(date +%Y%m%d-%H%M%S)-public-release-uiqa}"
OUTPUT_ROOT="${OUTPUT_ROOT:-$ROOT_DIR/tmp/visual-qa/prd-stitch-ui/public-release-scope-uiqa}"
OUTPUT_DIR="$OUTPUT_ROOT/$RUN_ID"
INSTALL_DIR="$OUTPUT_DIR/install"
DERIVED_DATA_PATH="${DERIVED_DATA_PATH:-$OUTPUT_DIR/DerivedData}"
RESULT_PATH="$OUTPUT_DIR/result.json"
SCREENSHOT_PATH="$OUTPUT_DIR/01-owner-default-entry.png"
DEEPLINK_LOG="$OUTPUT_DIR/deeplink-negative.log"
RELEASE_XCCONFIG="$OUTPUT_DIR/release-simulator.xcconfig"

mkdir -p "$OUTPUT_DIR"
cat > "$RELEASE_XCCONFIG" <<'XCCONFIG'
SWIFT_ACTIVE_COMPILATION_CONDITIONS = RELEASE RELEASE_SCOPE_SIMULATOR
SWIFT_ACTIVE_COMPILATION_CONDITIONS[sdk=iphonesimulator*] = RELEASE RELEASE_SCOPE_SIMULATOR
XCCONFIG

CONFIGURATION=Release \
SWIFT_ACTIVE_COMPILATION_CONDITIONS='RELEASE RELEASE_SCOPE_SIMULATOR' \
DERIVED_DATA_PATH="$DERIVED_DATA_PATH" \
OUTPUT_DIR="$INSTALL_DIR" \
XCCONFIG_PATH="$RELEASE_XCCONFIG" \
  "$SCRIPT_DIR/run-installable-simulator-uiqa.sh"

# shellcheck disable=SC1090
source "$INSTALL_DIR/install.env"

if /usr/libexec/PlistBuddy -c 'Print :CFBundleURLTypes' "$APP_PATH/Info.plist" >/dev/null 2>&1; then
  echo "Release app unexpectedly registers a custom URL scheme" >&2
  exit 1
fi

EXECUTABLE_NAME="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleExecutable' "$APP_PATH/Info.plist")"
EXECUTABLE_PATH="$APP_PATH/$EXECUTABLE_NAME"
if LC_ALL=C strings "$EXECUTABLE_PATH" | rg -q 'DJ(Run|Show|Seed|Enable|UseLocal)'; then
  echo "Release simulator executable contains QA launch arguments" >&2
  exit 1
fi

USER_HEX="$(python3 - <<'PY'
import json
value = {
    "id": "public-release-owner",
    "nickname": "Release Owner",
    "phone": "",
    "avatarName": "person.circle.fill",
    "gender": None,
    "region": None,
}
print(json.dumps(value, ensure_ascii=True, separators=(",", ":")).encode().hex())
PY
)"
xcrun simctl spawn "$SIMULATOR_UDID" defaults write "$BUNDLE_ID" dj_current_user -data "$USER_HEX"
xcrun simctl spawn "$SIMULATOR_UDID" defaults write "$BUNDLE_ID" dj_is_logged_in -bool true

xcrun simctl launch "$SIMULATOR_UDID" "$BUNDLE_ID" > "$OUTPUT_DIR/launch.log"
sleep 4
xcrun simctl io "$SIMULATOR_UDID" screenshot "$SCREENSHOT_PATH" >/dev/null

hidden_deep_link_bypass_count=0
: > "$DEEPLINK_LOG"
for url in \
  'dreamjourney://time-letter' \
  'dreamjourney://family' \
  'dreamjourney://voice-clone' \
  'dreamjourney://digital-human'
do
  if xcrun simctl openurl "$SIMULATOR_UDID" "$url" >> "$DEEPLINK_LOG" 2>&1; then
    hidden_deep_link_bypass_count=$((hidden_deep_link_bypass_count + 1))
  fi
done

[[ "$hidden_deep_link_bypass_count" -eq 0 ]] || {
  echo "A hidden deep link was accepted by the Release app" >&2
  exit 1
}

python3 - "$RESULT_PATH" "$BUNDLE_ID" "$SCREENSHOT_PATH" "$hidden_deep_link_bypass_count" <<'PY'
import json
import pathlib
import sys

output, bundle_id, screenshot, bypass_count = sys.argv[1:]
result = {
    "schemaVersion": 1,
    "build": {
        "configuration": "Release",
        "platform": "iphonesimulator",
        "bundleId": bundle_id,
        "qaCompilationConditions": False,
    },
    "defaultEntry": {
        "ownerSeeded": True,
        "launchArguments": [],
        "screenshotFile": pathlib.Path(screenshot).name,
    },
    "deepLinks": {
        "registeredCustomSchemes": 0,
        "registeredUniversalLinks": 0,
        "hiddenProbeCount": 4,
        "hiddenDeepLinkBypassCount": int(bypass_count),
    },
}
pathlib.Path(output).write_text(json.dumps(result, ensure_ascii=False, indent=2, sort_keys=True) + "\n")
PY

xcrun simctl terminate "$SIMULATOR_UDID" "$BUNDLE_ID" >/dev/null 2>&1 || true
echo "Public Release Scope UIQA smoke passed"
echo "Result: $RESULT_PATH"
echo "Screenshot: $SCREENSHOT_PATH"

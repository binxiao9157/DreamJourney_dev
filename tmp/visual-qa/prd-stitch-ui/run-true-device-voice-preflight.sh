#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../../.." && pwd)"
RUN_ID="${RUN_ID:-$(date +%Y%m%d-%H%M%S-true-device-voice-preflight)}"
OUTPUT_DIR="$ROOT_DIR/tmp/visual-qa/prd-stitch-ui/true-device-acceptance/$RUN_ID"
REPORT_FILE="$OUTPUT_DIR/report.md"
BUILD_LOG="$OUTPUT_DIR/device-build.log"

mkdir -p "$OUTPUT_DIR"

write_report_header() {
  {
    echo "# True Device Voice Preflight"
    echo
    echo "Run ID: \`$RUN_ID\`"
    echo
    echo "Scope: true-device readiness for microphone, photo picker, speech recognition, backend config, and production voice SDK config."
    echo
  } > "$REPORT_FILE"
}

append_report() {
  printf '%s\n' "$*" >> "$REPORT_FILE"
}

load_local_xcconfig() {
  local file="$1"
  [[ -f "$file" ]] || return 0

  while IFS= read -r line; do
    line="$(printf '%s' "$line" | xargs)"
    [[ "$line" == //* || "$line" == \#* ]] && continue
    [[ "$line" == *"="* ]] || continue

    local name="${line%%=*}"
    local value="${line#*=}"
    name="$(printf '%s' "$name" | xargs)"
    value="$(printf '%s' "$value" | xargs)"
    [[ -n "$name" && -n "$value" ]] || continue

    if [[ -z "${!name:-}" ]]; then
      export "$name=$value"
    fi
  done < "$file"
}

fail() {
  append_report
  append_report "Status: blocked"
  append_report
  append_report "Reason: $*"
  echo "Blocked: $*" >&2
  echo "Report: $REPORT_FILE" >&2
  exit 1
}

require_env() {
  local name="$1"
  local value="${!name:-}"
  if [[ -z "$value" ]]; then
    fail "$name is required for true-device / production voice preflight"
  fi
  if [[ "$value" == YOUR_* || "$value" == '$('* ]]; then
    fail "$name is still a placeholder"
  fi
  append_report "- \`$name\`: set"
}

write_report_header
cd "$ROOT_DIR"

load_local_xcconfig "DreamJourney/Config/Backend.local.xcconfig"
load_local_xcconfig "DreamJourney/Config/VoiceSDK.local.xcconfig"

append_report "## Required Environment"
require_env "DREAMJOURNEY_BACKEND_BASE_URL"
require_env "DREAMJOURNEY_BACKEND_API_TOKEN"
require_env "VOLCENGINE_APP_ID"
require_env "VOLCENGINE_APP_KEY"
require_env "VOLCENGINE_APP_TOKEN"

append_report
append_report "## Privacy Declarations"
for key in NSMicrophoneUsageDescription NSSpeechRecognitionUsageDescription NSPhotoLibraryUsageDescription NSCameraUsageDescription; do
  if ! grep -q "$key" DreamJourney/Resources/Info.plist; then
    fail "$key missing from Info.plist"
  fi
  append_report "- \`$key\`: present"
done

append_report
append_report "## Device Detection"
XCODE_DESTINATIONS="$(xcodebuild -workspace DreamJourney.xcworkspace -scheme DreamJourney -showdestinations 2>/dev/null || true)"
printf '%s\n' "$XCODE_DESTINATIONS" > "$OUTPUT_DIR/xcodebuild-destinations.txt"

DEVICE_ID="${DEVICE_ID:-}"
ONLINE_DEVICE_LINE=""
DEVICE_SOURCE=""

if [[ -n "$DEVICE_ID" ]]; then
  ONLINE_DEVICE_LINE="Provided by DEVICE_ID"
  DEVICE_SOURCE="environment"
fi

if [[ -z "$DEVICE_ID" ]]; then
  ONLINE_DEVICE_LINE="$(
    printf '%s\n' "$XCODE_DESTINATIONS" |
      awk '
        /platform:iOS,/ && $0 !~ /Simulator/ && $0 !~ /placeholder/ && $0 ~ /id:/ { print; exit }
      '
  )"
  if [[ -n "$ONLINE_DEVICE_LINE" ]]; then
    DEVICE_ID="$(printf '%s\n' "$ONLINE_DEVICE_LINE" | sed -E 's/.*id:([^,} ]+).*/\1/')"
    DEVICE_SOURCE="xcodebuild -showdestinations"
  fi
fi

DEVICECTL_LIST="$(xcrun devicectl list devices 2>/dev/null || true)"
printf '%s\n' "$DEVICECTL_LIST" > "$OUTPUT_DIR/devicectl-devices.txt"

if [[ -z "$DEVICE_ID" ]]; then
  ONLINE_DEVICE_LINE="$(
    printf '%s\n' "$DEVICECTL_LIST" |
      awk '
        $0 ~ /(iPhone|iPad)/ && $0 ~ /available/ { print; exit }
      '
  )"
  if [[ -n "$ONLINE_DEVICE_LINE" ]]; then
    DEVICE_ID="$(printf '%s\n' "$ONLINE_DEVICE_LINE" | awk '{ print $3 }')"
    DEVICE_SOURCE="devicectl"
  fi
fi

DEVICE_LIST="$(xcrun xctrace list devices 2>/dev/null || true)"
printf '%s\n' "$DEVICE_LIST" > "$OUTPUT_DIR/xctrace-devices.txt"

if [[ -z "$DEVICE_ID" ]]; then
  ONLINE_DEVICE_LINE="$(
    printf '%s\n' "$DEVICE_LIST" |
      awk '
        /== Devices ==/ { in_devices=1; next }
        /== Devices Offline ==/ { in_devices=0 }
        /== Simulators ==/ { in_devices=0 }
        in_devices && $0 !~ /Mac/ && $0 ~ /\([0-9A-Fa-f-]{8,}\)/ { print; exit }
      '
  )"
  if [[ -n "$ONLINE_DEVICE_LINE" ]]; then
    DEVICE_ID="$(printf '%s\n' "$ONLINE_DEVICE_LINE" | sed -E 's/.*\(([0-9A-Fa-f-]{8,})\).*/\1/')"
    DEVICE_SOURCE="xctrace"
  fi
fi

if [[ -z "$DEVICE_ID" ]]; then
  fail "No online physical iPhone/iPad detected. Connect and trust a device, then rerun this script."
fi

append_report "- Online device: \`$ONLINE_DEVICE_LINE\`"
append_report "- Device source: \`$DEVICE_SOURCE\`"
append_report "- Device destination: \`id=$DEVICE_ID\`"

RUN_DEVICE_BUILD="${RUN_DEVICE_BUILD:-1}"
if [[ "$RUN_DEVICE_BUILD" == "1" ]]; then
  append_report
  append_report "## Device Build"
  # xcodebuild -workspace DreamJourney.xcworkspace -scheme DreamJourney -destination id=<device> build
  set +e
  xcodebuild \
    -workspace DreamJourney.xcworkspace \
    -scheme DreamJourney \
    -configuration Debug \
    -destination "id=$DEVICE_ID" \
    DREAMJOURNEY_BACKEND_BASE_URL="$DREAMJOURNEY_BACKEND_BASE_URL" \
    DREAMJOURNEY_BACKEND_API_TOKEN="$DREAMJOURNEY_BACKEND_API_TOKEN" \
    VOLCENGINE_APP_ID="$VOLCENGINE_APP_ID" \
    VOLCENGINE_APP_KEY="$VOLCENGINE_APP_KEY" \
    VOLCENGINE_APP_TOKEN="$VOLCENGINE_APP_TOKEN" \
    build > "$BUILD_LOG" 2>&1
  BUILD_STATUS=$?
  set -e

  if [[ "$BUILD_STATUS" != "0" ]]; then
    append_report "- Build log: \`$BUILD_LOG\`"
    fail "xcodebuild device build failed"
  fi
  append_report "- Device build: passed"
  append_report "- Build log: \`$BUILD_LOG\`"
else
  append_report
  append_report "## Device Build"
  append_report "- Skipped because \`RUN_DEVICE_BUILD=$RUN_DEVICE_BUILD\`."
fi

append_report
append_report "## Manual True-Device Flow To Run After Preflight"
append_report "1. Launch the built app on the device."
append_report "2. Login/Register -> 记忆档案 -> create text archive."
append_report "3. 记忆档案 -> 选择照片 -> grant/deny/recover photo permission -> verify archive appears in 回响 context."
append_report "4. 回响 -> tap 开始语音 -> grant/deny/recover microphone and speech recognition permissions."
append_report "5. Complete at least one voice turn and capture ASR/TTS logs."
append_report "6. Background and foreground the app, then verify Echo state and archive persistence remain stable."
append_report "7. Save screenshots and device console excerpts under this run directory."
append_report
append_report "Status: preflight passed"

echo "True-device voice preflight passed"
echo "Report: $REPORT_FILE"

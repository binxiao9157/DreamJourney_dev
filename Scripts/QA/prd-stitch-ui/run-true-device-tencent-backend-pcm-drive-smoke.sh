#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../../.." && pwd)"
cd "$ROOT_DIR"

RUN_ID="${RUN_ID:-$(date +%Y%m%d-%H%M%S)-true-device-tencent-backend-pcm-drive}"
OUTPUT_DIR="$ROOT_DIR/tmp/visual-qa/prd-stitch-ui/true-device-tencent-backend-pcm-drive/$RUN_ID"
REPORT_PATH="$OUTPUT_DIR/report.md"
BUILD_LOG="$OUTPUT_DIR/device-build.log"
INSTALL_LOG="$OUTPUT_DIR/device-install.log"
LAUNCH_LOG="$OUTPUT_DIR/device-launch-console.log"
XCODE_DESTINATIONS_LOG="$OUTPUT_DIR/xcodebuild-destinations.txt"
DEVICECTL_DEVICES_LOG="$OUTPUT_DIR/devicectl-devices.txt"
XCTRACE_DEVICES_LOG="$OUTPUT_DIR/xctrace-devices.txt"
DERIVED_DATA_PATH="${DERIVED_DATA_PATH:-$OUTPUT_DIR/DerivedData}"
RUN_SECONDS="${RUN_SECONDS:-55}"

mkdir -p "$OUTPUT_DIR"

append_report() {
  printf '%s\n' "$*" >> "$REPORT_PATH"
}

fail() {
  append_report
  append_report "## Result"
  append_report
  append_report "- Status: failed"
  append_report "- Reason: $*"
  echo "[true-device-tencent-backend-pcm-drive] $*" >&2
  exit 1
}

cat > "$REPORT_PATH" <<REPORT
# True Device Tencent Backend PCM Drive Smoke

- Run ID: \`$RUN_ID\`
- Output dir: \`$OUTPUT_DIR\`
- Console duration seconds: \`$RUN_SECONDS\`
- Voice profile argument: \`${DJ_TENCENT_BACKEND_PCM_VOICE_PROFILE_ID:-optional, not provided}\`

REPORT

append_report "## Device Detection"
XCODE_DESTINATIONS="$(xcodebuild -workspace DreamJourney.xcworkspace -scheme DreamJourney -showdestinations 2>/dev/null || true)"
printf '%s\n' "$XCODE_DESTINATIONS" > "$XCODE_DESTINATIONS_LOG"

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
      awk '/platform:iOS,/ && $0 !~ /Simulator/ && $0 !~ /placeholder/ && $0 ~ /id:/ { print; exit }'
  )"
  if [[ -n "$ONLINE_DEVICE_LINE" ]]; then
    DEVICE_ID="$(printf '%s\n' "$ONLINE_DEVICE_LINE" | sed -E 's/.*id:([^,} ]+).*/\1/')"
    DEVICE_SOURCE="xcodebuild -showdestinations"
  fi
fi

DEVICECTL_LIST="$(xcrun devicectl list devices 2>/dev/null || true)"
printf '%s\n' "$DEVICECTL_LIST" > "$DEVICECTL_DEVICES_LOG"

if [[ -z "$DEVICE_ID" ]]; then
  ONLINE_DEVICE_LINE="$(
    printf '%s\n' "$DEVICECTL_LIST" |
      awk '$0 ~ /(iPhone|iPad)/ && $0 !~ /unavailable/ && $0 ~ /available/ { print; exit }'
  )"
  if [[ -n "$ONLINE_DEVICE_LINE" ]]; then
    DEVICE_ID="$(printf '%s\n' "$ONLINE_DEVICE_LINE" | awk '{ for (i = 1; i <= NF; i++) if ($i ~ /^[0-9A-Fa-f-]{8,}$/) { print $i; exit } }')"
    DEVICE_SOURCE="devicectl"
  fi
fi

DEVICE_LIST="$(xcrun xctrace list devices 2>/dev/null || true)"
printf '%s\n' "$DEVICE_LIST" > "$XCTRACE_DEVICES_LOG"

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
  fail "No online physical iPhone/iPad detected."
fi

append_report "- Online device: \`$ONLINE_DEVICE_LINE\`"
append_report "- Device source: \`$DEVICE_SOURCE\`"
append_report "- Device destination: \`id=$DEVICE_ID\`"

append_report
append_report "## Build"

XCODEBUILD_XCCONFIG_ARGS=()
if [[ -f "DreamJourney/Config/YXJ.local.xcconfig" ]]; then
  XCODEBUILD_XCCONFIG_ARGS=(-xcconfig "DreamJourney/Config/YXJ.local.xcconfig")
  append_report "- Local signing/backend xcconfig: \`DreamJourney/Config/YXJ.local.xcconfig\`"
else
  fail "DreamJourney/Config/YXJ.local.xcconfig is required so the script does not print backend/signing secrets as command-line build settings."
fi

set +e
xcodebuild \
  -workspace DreamJourney.xcworkspace \
  "${XCODEBUILD_XCCONFIG_ARGS[@]}" \
  -scheme DreamJourney \
  -configuration Debug \
  -destination "id=$DEVICE_ID" \
  -derivedDataPath "$DERIVED_DATA_PATH" \
  build > "$BUILD_LOG" 2>&1
BUILD_STATUS=$?
set -e

if [[ "$BUILD_STATUS" != "0" ]]; then
  append_report "- Build log: \`$BUILD_LOG\`"
  fail "xcodebuild device build failed"
fi

APP_PATH="$(find "$DERIVED_DATA_PATH/Build/Products/Debug-iphoneos" -maxdepth 1 -name 'DreamJourney.app' -print -quit)"
if [[ -z "$APP_PATH" || ! -d "$APP_PATH" ]]; then
  fail "DreamJourney.app was not found under derived data."
fi
BUNDLE_ID="$(plutil -extract CFBundleIdentifier raw "$APP_PATH/Info.plist")"
append_report "- Device build: passed"
append_report "- App path: \`$APP_PATH\`"
append_report "- Bundle ID: \`$BUNDLE_ID\`"
append_report "- Build log: \`$BUILD_LOG\`"

append_report
append_report "## Install"
set +e
xcrun devicectl device install app \
  --device "$DEVICE_ID" \
  "$APP_PATH" > "$INSTALL_LOG" 2>&1
INSTALL_STATUS=$?
set -e
if [[ "$INSTALL_STATUS" != "0" ]]; then
  append_report "- Install log: \`$INSTALL_LOG\`"
  fail "device install failed"
fi
append_report "- Install: passed"
append_report "- Install log: \`$INSTALL_LOG\`"

append_report
append_report "## Launch"
LAUNCH_ARGS=(
  DJUITestBypassLogin
  DJShowDigitalHumanLivePanel
  DJRunTencentDigitalHumanBackendPCMDriveSmoke
)
if [[ -n "${DJ_TENCENT_BACKEND_PCM_VOICE_PROFILE_ID:-}" ]]; then
  LAUNCH_ARGS+=("DJTencentBackendPCMDriveVoiceProfileId=$DJ_TENCENT_BACKEND_PCM_VOICE_PROFILE_ID")
fi
if [[ -n "${DJ_TENCENT_BACKEND_PCM_TEXT:-}" ]]; then
  LAUNCH_ARGS+=("DJTencentBackendPCMDriveText=$DJ_TENCENT_BACKEND_PCM_TEXT")
fi

set +e
xcrun devicectl device process launch \
  --device "$DEVICE_ID" \
  --terminate-existing \
  --console \
  "$BUNDLE_ID" \
  "${LAUNCH_ARGS[@]}" > "$LAUNCH_LOG" 2>&1 &
LAUNCH_PID=$!
sleep "$RUN_SECONDS"
kill -INT "$LAUNCH_PID" >/dev/null 2>&1 || true
wait "$LAUNCH_PID" >/dev/null 2>&1
set -e

append_report "- Launch args: \`DJUITestBypassLogin DJShowDigitalHumanLivePanel DJRunTencentDigitalHumanBackendPCMDriveSmoke [voiceProfileId optional]\`"
append_report "- Console log: \`$LAUNCH_LOG\`"

append_report
append_report "## Observed Signals"
for pattern in \
  "requesting backend PCM-drive synthesis" \
  "backend PCM-drive smoke synthesis ready" \
  "sent PCM-drive signal" \
  "sent PCM chunk" \
  "AudioStart" \
  "AudioOver"; do
  if grep -q "$pattern" "$LAUNCH_LOG"; then
    append_report "- \`$pattern\`: observed"
  else
    append_report "- \`$pattern\`: not observed"
  fi
done

if ! grep -q "backend PCM-drive smoke synthesis ready" "$LAUNCH_LOG"; then
  fail "backend synthesis did not complete; inspect $LAUNCH_LOG"
fi
if ! grep -q "sent PCM chunk" "$LAUNCH_LOG"; then
  fail "PCM chunks were not sent; inspect $LAUNCH_LOG"
fi
if ! grep -q "AudioStart" "$LAUNCH_LOG"; then
  fail "Tencent AudioStart was not observed; inspect $LAUNCH_LOG"
fi

append_report
append_report "## Result"
append_report
append_report "- Status: passed"

echo "[true-device-tencent-backend-pcm-drive] Report: $REPORT_PATH"
echo "[true-device-tencent-backend-pcm-drive] Console log: $LAUNCH_LOG"

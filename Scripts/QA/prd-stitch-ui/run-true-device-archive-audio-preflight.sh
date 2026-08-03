#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../../.." && pwd)"
RUN_ID="${RUN_ID:-$(date +%Y%m%d-%H%M%S-true-device-archive-audio-preflight)}"
OUTPUT_DIR="$ROOT_DIR/tmp/visual-qa/prd-stitch-ui/true-device-acceptance/$RUN_ID"
REPORT_FILE="$OUTPUT_DIR/report.md"
BUILD_LOG="$OUTPUT_DIR/device-build.log"
EVIDENCE_MANIFEST="$OUTPUT_DIR/evidence-manifest.md"
AUDIO_QUALITY_NOTES="$OUTPUT_DIR/audio-quality-notes.md"
PLAYBACK_ROUTE_NOTES="$OUTPUT_DIR/playback-route-notes.md"
BACKGROUND_FOREGROUND_NOTES="$OUTPUT_DIR/background-foreground-notes.md"

mkdir -p "$OUTPUT_DIR"

write_report_header() {
  {
    echo "# True Device Archive Audio Preflight"
    echo
    echo "Run ID: \`$RUN_ID\`"
    echo
    echo "Scope: 语音档案真机前置验收，包括真实麦克风授权/拒绝/重新授权、录音质量、详情播放路由、前后台切换后文件不丢。"
    echo
  } > "$REPORT_FILE"
}

append_report() {
  printf '%s\n' "$*" >> "$REPORT_FILE"
}

write_evidence_manifest() {
  touch "$AUDIO_QUALITY_NOTES" "$PLAYBACK_ROUTE_NOTES" "$BACKGROUND_FOREGROUND_NOTES"
  {
    echo "# True Device Archive Audio Evidence Manifest"
    echo
    echo "Run ID: \`$RUN_ID\`"
    echo
    echo "## Required Artifacts"
    echo
    echo "- \`report.md\`: preflight/build status and manual checklist."
    echo "- \`device-build.log\`: true-device xcodebuild output when \`RUN_DEVICE_BUILD=1\`."
    echo "- \`xcodebuild-destinations.txt\`: Xcode destination discovery output."
    echo "- \`devicectl-devices.txt\`: devicectl discovery output."
    echo "- \`xctrace-devices.txt\`: xctrace discovery output."
    echo "- \`audio-quality-notes.md\`: 录音质量 notes for clarity, volume, noise, truncation, and playback failures."
    echo "- \`playback-route-notes.md\`: 播放路由 notes for receiver/speaker/Bluetooth and pause/resume behavior."
    echo "- \`background-foreground-notes.md\`: 前后台 notes for file persistence, list restoration, and detail restoration."
    echo
    echo "## Required Screenshots"
    echo
    echo "- \`01-audio-permission-allow.png\`: first microphone permission allow path."
    echo "- \`02-audio-permission-deny.png\`: microphone denial recovery state."
    echo "- \`03-audio-permission-recover.png\`: Settings re-authorization recovery path."
    echo "- \`04-audio-created.png\`: saved audio archive item in list/detail."
    echo "- \`05-audio-detail-playback.png\`: detail playback route and playback state."
    echo "- \`06-audio-after-background-foreground.png\`: audio item restored after background/foreground."
    echo
    echo "## Acceptance Boundary"
    echo
    echo "This package proves evidence shape only. It does not declare true-device archive audio pass until screenshots and notes are populated on a physical device."
  } > "$EVIDENCE_MANIFEST"
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

env_state() {
  local name="$1"
  local value="${!name:-}"
  if [[ -z "$value" ]]; then
    append_report "- \`$name\`: not set"
    return
  fi
  if [[ "$value" == YOUR_* || "$value" == '$('* ]]; then
    append_report "- \`$name\`: placeholder"
    return
  fi
  append_report "- \`$name\`: set"
}

write_report_header
write_evidence_manifest
cd "$ROOT_DIR"

load_local_xcconfig "DreamJourney/Config/Backend.local.xcconfig"
load_local_xcconfig "DreamJourney/Config/YXJ.local.xcconfig"

append_report "## Optional Local Configuration"
append_report
append_report "Only the non-secret backend base URL may be loaded as an app build setting. Archive audio recording is validated through the native microphone/audio-file route."
for name in DREAMJOURNEY_BACKEND_BASE_URL; do
  env_state "$name"
done

append_report
append_report "## Privacy Declarations"
for key in NSMicrophoneUsageDescription NSSpeechRecognitionUsageDescription; do
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
        $0 ~ /(iPhone|iPad)/ && $0 !~ /unavailable/ && $0 ~ /available/ { print; exit }
      '
  )"
  if [[ -n "$ONLINE_DEVICE_LINE" ]]; then
    DEVICE_ID="$(printf '%s\n' "$ONLINE_DEVICE_LINE" | awk '{ for (i = 1; i <= NF; i++) if ($i ~ /^[0-9A-Fa-f-]{8,}$/) { print $i; exit } }')"
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
  fail "No online physical iPhone/iPad detected. Connect, unlock, and trust the device, then rerun this script."
fi

append_report "- Online device: \`$ONLINE_DEVICE_LINE\`"
append_report "- Device source: \`$DEVICE_SOURCE\`"
append_report "- Device destination: \`id=$DEVICE_ID\`"

RUN_DEVICE_BUILD="${RUN_DEVICE_BUILD:-1}"
if [[ "$RUN_DEVICE_BUILD" == "1" ]]; then
  append_report
  append_report "## Device Build"

  XCODEBUILD_XCCONFIG_ARGS=()
  if [[ -f "DreamJourney/Config/YXJ.local.xcconfig" ]]; then
    XCODEBUILD_XCCONFIG_ARGS=(-xcconfig "DreamJourney/Config/YXJ.local.xcconfig")
    append_report "- Local signing xcconfig: \`DreamJourney/Config/YXJ.local.xcconfig\`"
  fi

  BUILD_SETTINGS=()
  if [[ ${#XCODEBUILD_XCCONFIG_ARGS[@]} -eq 0 ]]; then
    for name in \
      DREAMJOURNEY_BACKEND_BASE_URL \
      DREAMJOURNEY_DEVELOPMENT_TEAM \
      DREAMJOURNEY_PRODUCT_BUNDLE_IDENTIFIER \
      CODE_SIGN_STYLE; do
      if [[ -n "${!name:-}" ]]; then
        BUILD_SETTINGS+=("$name=${!name}")
      fi
    done
  fi

  set +e
  xcodebuild \
    -workspace DreamJourney.xcworkspace \
    "${XCODEBUILD_XCCONFIG_ARGS[@]}" \
    -scheme DreamJourney \
    -configuration Debug \
    -destination "id=$DEVICE_ID" \
    -allowProvisioningUpdates \
    "${BUILD_SETTINGS[@]}" \
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
append_report "## Manual True-Device Archive Audio Flow"
append_report
append_report "- Evidence manifest: \`$EVIDENCE_MANIFEST\`"
append_report "- Audio quality notes: \`$AUDIO_QUALITY_NOTES\`"
append_report "- Playback route notes: \`$PLAYBACK_ROUTE_NOTES\`"
append_report "- Background/foreground notes: \`$BACKGROUND_FOREGROUND_NOTES\`"
append_report
append_report "Launch with hidden archive QA enabled, for example via scheme launch argument \`DJEnableArchiveHiddenBranches\`, then run:"
append_report
append_report "1. 记忆档案 -> 封存新记忆 -> 录入语音。首次弹出麦克风权限时选择允许，录制 5-10 秒，保存。截图：\`01-audio-permission-allow.png\`、\`04-audio-created.png\`。"
append_report "2. 重新安装或重置麦克风权限后再次进入 录入语音，选择拒绝，确认页面显示可恢复状态且不崩溃。截图：\`02-audio-permission-deny.png\`。"
append_report "3. 进入系统设置重新打开麦克风权限，回到 App 后再次录制并保存。截图：\`03-audio-permission-recover.png\`。"
append_report "4. 打开刚保存的语音档案详情，点击播放，确认详情播放路由、暂停/结束状态和扬声器输出正常。截图：\`05-audio-detail-playback.png\`。"
append_report "5. 将 App 切到后台再回前台，确认列表、详情和本地音频文件仍在。截图：\`06-audio-after-background-foreground.png\`。"
append_report "6. 记录录音质量：是否清晰、是否存在明显截断、噪声、过低音量或播放失败。把设备日志和截图放在本 run 目录。"
append_report
append_report "Status: preflight passed; manual archive audio acceptance still requires the screenshots and notes above."

echo "True-device archive audio preflight passed"
echo "Report: $REPORT_FILE"

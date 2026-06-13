#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

ALLOW_NO_DEVICE=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    --allow-no-device)
      ALLOW_NO_DEVICE=1
      shift
      ;;
    *)
      printf 'Usage: %s [--allow-no-device]\n' "$0" >&2
      exit 64
      ;;
  esac
done

WORKSPACE="DreamJourney.xcworkspace"
SCHEME="DreamJourney"
CONFIGURATION="Debug"

ROADSHOW_ARGS="--reset-roadshow-demo --seed-roadshow-demo --roadshow-offline-mode"
ROADSHOW_ENV="DREAMJOURNEY_SEED=roadshow_demo DREAMJOURNEY_RESET_DEMO=1 DREAMJOURNEY_ROADSHOW_OFFLINE=1"
ROADSHOW_ENV_JSON='{"DREAMJOURNEY_SEED":"roadshow_demo","DREAMJOURNEY_RESET_DEMO":"1","DREAMJOURNEY_ROADSHOW_OFFLINE":"1"}'
ROADSHOW_LAUNCH_ARGS=(--reset-roadshow-demo --seed-roadshow-demo --roadshow-offline-mode)

TIMESTAMP="$(date +%Y%m%d_%H%M%S)"
EVIDENCE_DIR="${ROADSHOW_SMOKE_EVIDENCE_DIR:-/tmp/dreamjourney_roadshow_smoke_${TIMESTAMP}}"
mkdir -p "$EVIDENCE_DIR"
mkdir -p "$EVIDENCE_DIR/screens" "$EVIDENCE_DIR/recordings" "$EVIDENCE_DIR/share_packages" "$EVIDENCE_DIR/route_completion" "$EVIDENCE_DIR/diagnostics"

section() {
  printf '\n== %s ==\n' "$1"
}

quote_command() {
  printf '$'
  printf ' %q' "$@"
  printf '\n'
}

run_logged() {
  local label="$1"
  shift
  local log_file="$EVIDENCE_DIR/${label}.log"
  local command_file="$EVIDENCE_DIR/${label}.command"
  local exit_file="$EVIDENCE_DIR/${label}.exit_code"

  quote_command "$@" > "$command_file"
  set +e
  "$@" 2>&1 | tee "$log_file"
  local command_status=${PIPESTATUS[0]}
  set -e
  printf '%s\n' "$command_status" > "$exit_file"
  return "$command_status"
}

write_evidence_scaffold() {
  cat > "$EVIDENCE_DIR/expected_screens.txt" <<'SCREENS'
screens/01_home_banner.png
screens/02_route_checklist.png
screens/03_memory_voice_digital_human.png
screens/04_time_mailbox_delivered_letter.png
screens/05_memory_archive_photo_analysis.png
screens/06_family_footprint_world_generation.png
screens/07_family_care_dashboard_member.png
screens/08_share_package_export_sheet.png
SCREENS

  cat > "$EVIDENCE_DIR/evidence_manifest.json" <<'MANIFEST'
{
  "app": "DreamJourney",
  "mode": "roadshow_device_smoke",
  "launchArguments": [
    "--reset-roadshow-demo",
    "--seed-roadshow-demo",
    "--roadshow-offline-mode"
  ],
  "environment": {
    "DREAMJOURNEY_SEED": "roadshow_demo",
    "DREAMJOURNEY_RESET_DEMO": "1",
    "DREAMJOURNEY_ROADSHOW_OFFLINE": "1"
  },
  "routeScreens": [
    { "id": "home", "title": "首页路演入口", "evidenceFile": "screens/01_home_banner.png" },
    { "id": "route", "title": "路演路线清单", "evidenceFile": "screens/02_route_checklist.png" },
    { "id": "voice_companion", "title": "语音陪伴与数字人", "evidenceFile": "screens/03_memory_voice_digital_human.png" },
    { "id": "time_mailbox", "title": "时空信箱边界", "evidenceFile": "screens/04_time_mailbox_delivered_letter.png" },
    { "id": "memory_archive", "title": "记忆档案馆", "evidenceFile": "screens/05_memory_archive_photo_analysis.png" },
    { "id": "family_footprint", "title": "家族足迹点亮", "evidenceFile": "screens/06_family_footprint_world_generation.png" },
    { "id": "care_dashboard", "title": "亲友关怀看板", "evidenceFile": "screens/07_family_care_dashboard_member.png" },
    { "id": "family_share", "title": "分享包与隐私收口", "evidenceFile": "screens/08_share_package_export_sheet.png" }
  ],
  "additionalArtifacts": [
    "recordings/roadshow_6min_run.mp4",
    "route_completion/route_completion_preferences.txt",
    "route_completion/route_acceptance_checklist.md",
    "share_packages/all_family.json",
    "share_packages/selected_member.json",
    "share_packages/privacy_check.log",
    "app_console_sample.log",
    "diagnostics/digital_human_readiness.txt",
    "diagnostics/digital_human_readiness.json",
    "diagnostics/digital_human_playback.log"
  ]
}
MANIFEST

  cat > "$EVIDENCE_DIR/expected_state_keys.txt" <<'STATEKEYS'
dreamjourney.roadshow.seeded.v1
dreamjourney.roadshow.offlineMode
dj_is_logged_in
dreamjourney.roadshow.route.completed.voice_companion
dreamjourney.roadshow.route.completed.time_mailbox
dreamjourney.roadshow.route.completed.memory_archive
dreamjourney.roadshow.route.completed.family_footprint
dreamjourney.roadshow.route.completed.care_dashboard
dreamjourney.roadshow.route.completed.family_share
STATEKEYS

  cat > "$EVIDENCE_DIR/route_completion/route_acceptance_checklist.md" <<'ROUTECHECKLIST'
# DreamJourney Roadshow Route Acceptance

Copy the in-app "复制验收" output here after the 6-stage smoke run. Keep this file with screenshots, recordings, share packages, and device logs.

Expected route evidence mapping:

| Route step | Expected evidence file |
| --- | --- |
| 语音陪伴与数字人 | `screens/03_memory_voice_digital_human.png` |
| 时空信箱边界 | `screens/04_time_mailbox_delivered_letter.png` |
| 记忆档案馆 | `screens/05_memory_archive_photo_analysis.png` |
| 家族足迹点亮 | `screens/06_family_footprint_world_generation.png` |
| 亲友关怀看板 | `screens/07_family_care_dashboard_member.png` |
| 分享包与隐私收口 | `screens/08_share_package_export_sheet.png` |

Paste copied checklist below:

```text
<paste in-app checklist here>
```
ROUTECHECKLIST

  cat > "$EVIDENCE_DIR/route_screen_checklist.md" <<'CHECKLIST'
# DreamJourney Roadshow Evidence Checklist

Save screenshots and samples into this evidence directory using the expected names.
Screenshots must be real PNG files, and the roadshow recording must be a real MP4 file; placeholder text renamed to `.png` or `.mp4` will be rejected by `roadshow_evidence_report.py`.

| Stage | Evidence file | What to show |
| --- | --- | --- |
| Home | `screens/01_home_banner.png` | Roadshow banner, offline/demo boundary, route entry. |
| Route | `screens/02_route_checklist.png` | Six-stage route checklist and progress. |
| Voice | `screens/03_memory_voice_digital_human.png` | Voice flow, digital human speaking/listening state, boundary copy. |
| Diagnostics | `diagnostics/digital_human_readiness.txt/json` | App auto-writes sanitized diagnostics under Documents/diagnostics; preflight copies them here. |
| Playback | `diagnostics/digital_human_playback.log` | App auto-writes DigitalHumanSpeech lifecycle markers; console grep is fallback. |
| Mailbox | `screens/04_time_mailbox_delivered_letter.png` | Delivered letter and "not a real reply" boundary. |
| Archive | `screens/05_memory_archive_photo_analysis.png` | Text/photo archive sample and mock analysis. |
| Footprint | `screens/06_family_footprint_world_generation.png` | City/nation/world or generation illuminated map. |
| Care | `screens/07_family_care_dashboard_member.png` | Member care dashboard, coverage, masked observation report. |
| Share | `screens/08_share_package_export_sheet.png` | All-family/single-member export path or share sheet. |

Additional expected artifacts:

- `recordings/roadshow_6min_run.mp4`
- `route_completion/route_completion_preferences.txt`
- `share_packages/all_family.json`
- `share_packages/selected_member.json`
- `share_packages/privacy_check.log`
- `app_console_sample.log`
- `diagnostics/digital_human_readiness.txt`
- `diagnostics/digital_human_readiness.json`
- `diagnostics/digital_human_playback.log`
- `evidence_status.json`
- `evidence_status.md`
- `archive_package_next_steps.txt`
- `dreamjourney_roadshow_evidence.zip`
- `archive_inventory.json` inside the zip, with sizeBytes and sha256 for each packaged evidence file

Digital-human playback log acceptance:

- Native audio path: `wav_synth_success` then `playback_finished source=native_audio`
- System TTS fallback path: `fallback=systemTTS` then `playback_finished source=system_tts`
- Watchdog recovery path: `playback_timeout` then `playback_finished source=timeout`

Share package privacy check acceptance:

Save `share_packages/all_family.json` and `share_packages/selected_member.json` as real share packages, not placeholder JSON. Each file must include `sourceUserId`, `sourceNickname`, `exportDate`, and a parseable `graphJSON` string whose inner graph has `people`, `places`, `events`, and `facts` arrays.

After exporting both files, generate `share_packages/privacy_check.log` with the sample checker:

```bash
python3 Scripts/roadshow_share_package_privacy_check.py "$EVIDENCE_DIR" \\
  --write-log "$EVIDENCE_DIR/share_packages/privacy_check.log"
```

The checker validates JSON shape, parses graphJSON, rejects forbidden private/local/raw/unauthorized markers, and writes these tokens so `roadshow_evidence_report.py` can verify it:

```text
PASS share package privacy check
checked: share_packages/all_family.json
checked: share_packages/selected_member.json
no PRIVATE_/LOCAL_/GENERATION_ markers
no RAW_TRANSCRIPT/FULL_TRANSCRIPT/FULL_LETTER content
no UNAUTHORIZED_ member content
```
CHECKLIST

  cat > "$EVIDENCE_DIR/archive_package_next_steps.txt" <<ARCHIVE
When every required screenshot, recording, diagnostic log, share package, and privacy check is present, build the shareable roadshow evidence zip:

python3 Scripts/roadshow_evidence_report.py "$EVIDENCE_DIR" --write --archive --fail-on-missing

Expected output:
- evidence_status.json and evidence_status.md are refreshed.
- dreamjourney_roadshow_evidence.zip is created in this evidence directory.
- The zip contains archive_inventory.json with sizeBytes and sha256 for every packaged evidence file.
- The command fails if evidence is missing, screenshot/recording files are not valid PNG/MP4, a token-like value is detected, playback logs lack an accepted closure chain, share package JSON is invalid/unsafe, share package graphJSON is missing/unparseable, or share_packages/privacy_check.log lacks an explicit PASS privacy sample result.
ARCHIVE
}

write_evidence_scaffold

setting_value() {
  local key="$1"
  awk -F ' = ' -v key="$key" '
    $1 ~ "^[[:space:]]*" key "$" {
      print $2
      exit
    }
  '
}

section "Roadshow launch contract"
printf 'Launch arguments: %s\n' "$ROADSHOW_ARGS"
printf 'Environment: %s\n' "$ROADSHOW_ENV"
printf 'Optional explicit mock args: --use-mock-dialog-engine --use-mock-safety-guard\n'
printf 'Evidence directory: %s\n' "$EVIDENCE_DIR"

section "Connected physical iOS devices"
XCTRACE_DEVICES="$(xcrun xctrace list devices 2>/dev/null || true)"
printf '%s\n' "$XCTRACE_DEVICES" > "$EVIDENCE_DIR/xctrace_devices.txt"
printf '%s\n' "$XCTRACE_DEVICES"

PHYSICAL_IOS_DEVICES="$(
  printf '%s\n' "$XCTRACE_DEVICES" |
    awk '
      /^== Devices ==/ { in_devices = 1; next }
      /^== Devices Offline ==/ { in_devices = 0 }
      /^== Simulators ==/ { in_devices = 0 }
      in_devices && /(iPhone|iPad|iPod)/ { print }
    '
)"
printf '%s\n' "$PHYSICAL_IOS_DEVICES" > "$EVIDENCE_DIR/physical_ios_devices.txt"

DEVICE_UDID="$(
  printf '%s\n' "$PHYSICAL_IOS_DEVICES" |
    sed -nE 's/.*\(([0-9A-Fa-f-]{8,}|[A-Za-z0-9-]{8,})\)[[:space:]]*$/\1/p' |
    head -n 1
)"
DEVICE_CORE_ID=""

XCODE_DESTINATIONS="$(
  xcodebuild \
    -workspace "$WORKSPACE" \
    -scheme "$SCHEME" \
    -showdestinations 2>/dev/null || true
)"
printf '%s\n' "$XCODE_DESTINATIONS" > "$EVIDENCE_DIR/xcodebuild_destinations.txt"
XCODE_DEVICE_UDID="$(
  printf '%s\n' "$XCODE_DESTINATIONS" |
    sed -nE 's/.*platform:iOS, arch:[^,]+, id:([^,}]+), name:.*/\1/p' |
    head -n 1
)"

DEVICECTL_DEVICES="$(xcrun devicectl list devices 2>/dev/null || true)"
printf '%s\n' "$DEVICECTL_DEVICES" > "$EVIDENCE_DIR/devicectl_list_devices.log"
DEVICE_CORE_ID="$(
  printf '%s\n' "$DEVICECTL_DEVICES" |
    awk '/(iPhone|iPad|iPod)/ && /available/ { print $3; exit }'
)"

if [[ -z "$DEVICE_UDID" && -n "$XCODE_DEVICE_UDID" ]]; then
  DEVICE_UDID="$XCODE_DEVICE_UDID"
fi
if [[ -z "$DEVICE_CORE_ID" && -n "$DEVICE_UDID" ]]; then
  DEVICE_CORE_ID="$DEVICE_UDID"
fi

if [[ -z "$PHYSICAL_IOS_DEVICES" && -z "$XCODE_DEVICE_UDID" && -z "$DEVICE_CORE_ID" ]]; then
  printf '\nWARN: No connected physical iPhone/iPad/iPod detected.\n'
  DEVICE_READY=0
else
  DEVICE_READY=1
  printf '\nUsing first physical iOS device identifier: %s\n' "$DEVICE_UDID"
  printf 'Using first CoreDevice identifier: %s\n' "${DEVICE_CORE_ID:-unknown}"
  if [[ -n "$DEVICE_CORE_ID" ]]; then
    run_logged devicectl_device_details xcrun devicectl device info details --device "$DEVICE_CORE_ID" || true
    run_logged devicectl_device_displays xcrun devicectl device info displays --device "$DEVICE_CORE_ID" || true
    run_logged devicectl_device_lock_state xcrun devicectl device info lockState --device "$DEVICE_CORE_ID" || true
  fi
fi

section "Build settings"
BUILD_SETTINGS="$(
  xcodebuild \
    -showBuildSettings \
    -workspace "$WORKSPACE" \
    -scheme "$SCHEME" \
    -configuration "$CONFIGURATION" \
    -sdk iphoneos \
    CODE_SIGNING_ALLOWED=NO
)"
printf '%s\n' "$BUILD_SETTINGS" > "$EVIDENCE_DIR/build_settings.txt"
printf '%s\n' "$BUILD_SETTINGS" |
  awk '
    /PRODUCT_BUNDLE_IDENTIFIER =/ ||
    /DEVELOPMENT_TEAM =/ ||
    /CODE_SIGN_STYLE =/ ||
    /IPHONEOS_DEPLOYMENT_TARGET =/ ||
    /SDKROOT =/ { print }
  '
BUNDLE_ID="$(printf '%s\n' "$BUILD_SETTINGS" | setting_value PRODUCT_BUNDLE_IDENTIFIER)"
printf '%s\n' "${BUNDLE_ID:-unknown}" > "$EVIDENCE_DIR/bundle_identifier.txt"

if ! printf '%s\n' "$BUILD_SETTINGS" | grep -q 'DEVELOPMENT_TEAM = [A-Za-z0-9]'; then
  printf '\nWARN: DEVELOPMENT_TEAM is empty or not visible. Xcode manual signing may still be required before physical-device Run.\n'
fi

section "iPhoneOS build gate"
run_logged iphoneos_build_gate xcodebuild \
  -workspace "$WORKSPACE" \
  -scheme "$SCHEME" \
  -configuration "$CONFIGURATION" \
  -destination 'generic/platform=iOS' \
  CODE_SIGNING_ALLOWED=NO \
  build

DEVICE_AUTOMATION_CONCERNS=0

if [[ "$DEVICE_READY" -eq 1 ]]; then
  section "Physical-device install and launch evidence"

  if [[ -z "$DEVICE_UDID" && -z "$DEVICE_CORE_ID" ]]; then
    printf 'WARN: Could not parse a physical-device identifier from xctrace, xcodebuild destinations, or devicectl; skipping install/launch capture.\n'
    DEVICE_AUTOMATION_CONCERNS=1
  elif [[ -z "$BUNDLE_ID" ]]; then
    printf 'WARN: Could not parse PRODUCT_BUNDLE_IDENTIFIER; skipping devicectl install/launch capture.\n'
    DEVICE_AUTOMATION_CONCERNS=1
  else
    DEVICE_BUILD_DESTINATION="${DEVICE_UDID:-${DEVICE_CORE_ID}}"
    DEVICECTL_DEVICE_ID="${DEVICE_CORE_ID:-${DEVICE_UDID}}"
    if run_logged device_build_settings xcodebuild \
      -showBuildSettings \
      -workspace "$WORKSPACE" \
      -scheme "$SCHEME" \
      -configuration "$CONFIGURATION" \
      -destination "platform=iOS,id=$DEVICE_BUILD_DESTINATION" \
      -allowProvisioningUpdates; then
      TARGET_BUILD_DIR="$(setting_value TARGET_BUILD_DIR < "$EVIDENCE_DIR/device_build_settings.log")"
      FULL_PRODUCT_NAME="$(setting_value FULL_PRODUCT_NAME < "$EVIDENCE_DIR/device_build_settings.log")"
      DEVICE_APP_PATH="${ROADSHOW_DEVICE_APP_PATH:-${TARGET_BUILD_DIR}/${FULL_PRODUCT_NAME}}"
      printf '%s\n' "$DEVICE_APP_PATH" > "$EVIDENCE_DIR/device_app_path.txt"

      if run_logged device_signed_build xcodebuild \
        -workspace "$WORKSPACE" \
        -scheme "$SCHEME" \
        -configuration "$CONFIGURATION" \
        -destination "platform=iOS,id=$DEVICE_BUILD_DESTINATION" \
        -allowProvisioningUpdates \
        build; then
        if [[ -d "$DEVICE_APP_PATH" ]]; then
          if ! run_logged devicectl_install_app xcrun devicectl device install app \
            --device "$DEVICECTL_DEVICE_ID" \
            "$DEVICE_APP_PATH"; then
            DEVICE_AUTOMATION_CONCERNS=1
          fi

          if ! run_logged devicectl_launch_app xcrun devicectl device process launch \
            --device "$DEVICECTL_DEVICE_ID" \
            --terminate-existing \
            --environment-variables "$ROADSHOW_ENV_JSON" \
            "$BUNDLE_ID" \
            "${ROADSHOW_LAUNCH_ARGS[@]}"; then
            DEVICE_AUTOMATION_CONCERNS=1
          fi

          run_logged devicectl_installed_app xcrun devicectl device info apps \
            --device "$DEVICECTL_DEVICE_ID" \
            --bundle-id "$BUNDLE_ID" || DEVICE_AUTOMATION_CONCERNS=1
          run_logged devicectl_processes_sample xcrun devicectl device info processes \
            --device "$DEVICECTL_DEVICE_ID" \
            --filter "executablePath CONTAINS 'DreamJourney'" \
            --columns '*' || DEVICE_AUTOMATION_CONCERNS=1
          run_logged devicectl_container_files_root xcrun devicectl device info files \
            --device "$DEVICECTL_DEVICE_ID" \
            --domain-type appDataContainer \
            --domain-identifier "$BUNDLE_ID" \
            --subdirectory . \
            --columns '*' || true
          run_logged devicectl_container_files_documents xcrun devicectl device info files \
            --device "$DEVICECTL_DEVICE_ID" \
            --domain-type appDataContainer \
            --domain-identifier "$BUNDLE_ID" \
            --subdirectory Documents \
            --columns '*' || true

          PREFERENCES_PLIST="$EVIDENCE_DIR/${BUNDLE_ID}.plist"
          if run_logged devicectl_copy_preferences_plist xcrun devicectl device copy from \
            --device "$DEVICECTL_DEVICE_ID" \
            --domain-type appDataContainer \
            --domain-identifier "$BUNDLE_ID" \
            --source "Library/Preferences/${BUNDLE_ID}.plist" \
            --destination "$PREFERENCES_PLIST"; then
            /usr/libexec/PlistBuddy \
              -c 'Print :dreamjourney.roadshow.seeded.v1' \
              -c 'Print :dreamjourney.roadshow.offlineMode' \
              -c 'Print :dj_is_logged_in' \
              "$PREFERENCES_PLIST" > "$EVIDENCE_DIR/container_preferences_sample.txt" 2>&1 || true
            {
              printf 'Roadshow route completion preferences\n'
              for route_key in \
                dreamjourney.roadshow.route.completed.voice_companion \
                dreamjourney.roadshow.route.completed.time_mailbox \
                dreamjourney.roadshow.route.completed.memory_archive \
                dreamjourney.roadshow.route.completed.family_footprint \
                dreamjourney.roadshow.route.completed.care_dashboard \
                dreamjourney.roadshow.route.completed.family_share; do
                printf '%s=' "$route_key"
                /usr/libexec/PlistBuddy -c "Print :$route_key" "$PREFERENCES_PLIST" 2>/dev/null || printf 'missing'
                printf '\n'
              done
            } > "$EVIDENCE_DIR/route_completion/route_completion_preferences.txt" 2>&1 || true
          else
            DEVICE_AUTOMATION_CONCERNS=1
          fi

          run_logged devicectl_copy_conversation_memory xcrun devicectl device copy from \
            --device "$DEVICECTL_DEVICE_ID" \
            --domain-type appDataContainer \
            --domain-identifier "$BUNDLE_ID" \
            --source Documents/conversation_memory.json \
            --destination "$EVIDENCE_DIR/conversation_memory.json" || true

          run_logged devicectl_copy_digital_human_readiness_text xcrun devicectl device copy from \
            --device "$DEVICECTL_DEVICE_ID" \
            --domain-type appDataContainer \
            --domain-identifier "$BUNDLE_ID" \
            --source Documents/diagnostics/digital_human_readiness.txt \
            --destination "$EVIDENCE_DIR/diagnostics/digital_human_readiness.txt" || true

          run_logged devicectl_copy_digital_human_readiness_json xcrun devicectl device copy from \
            --device "$DEVICECTL_DEVICE_ID" \
            --domain-type appDataContainer \
            --domain-identifier "$BUNDLE_ID" \
            --source Documents/diagnostics/digital_human_readiness.json \
            --destination "$EVIDENCE_DIR/diagnostics/digital_human_readiness.json" || true

          run_logged devicectl_copy_digital_human_playback_log xcrun devicectl device copy from \
            --device "$DEVICECTL_DEVICE_ID" \
            --domain-type appDataContainer \
            --domain-identifier "$BUNDLE_ID" \
            --source Documents/diagnostics/digital_human_playback.log \
            --destination "$EVIDENCE_DIR/diagnostics/digital_human_playback.log" || true
        else
          printf 'WARN: Expected built app was not found at %s\n' "$DEVICE_APP_PATH"
          DEVICE_AUTOMATION_CONCERNS=1
        fi
      else
        DEVICE_AUTOMATION_CONCERNS=1
      fi
    else
      DEVICE_AUTOMATION_CONCERNS=1
    fi
  fi

  cat > "$EVIDENCE_DIR/console_capture_next_steps.txt" <<CONSOLE
The app writes digital-human playback lifecycle markers to
Documents/diagnostics/digital_human_playback.log. The preflight script attempts
to copy that file automatically after launch. If it is still missing, run the
same launch from Xcode Devices or repeat devicectl with --console and tee the
output into this evidence folder:

xcrun devicectl device process launch \\
  --device "$DEVICE_UDID" \\
  --terminate-existing \\
  --console \\
  --environment-variables '$ROADSHOW_ENV_JSON' \\
  "$BUNDLE_ID" \\
  $ROADSHOW_ARGS | tee "$EVIDENCE_DIR/app_console_sample.log"

Then extract the digital-human playback evidence into the required playback log:

grep -E 'DigitalHumanSpeech|wav_synth_success|fallback=systemTTS|playback_timeout|playback_finished source=(native_audio|system_tts|timeout)' \\
  "$EVIDENCE_DIR/app_console_sample.log" \\
  > "$EVIDENCE_DIR/diagnostics/digital_human_playback.log"

Then run the strict rehearsal audit. It requires all three closure samples and
redacts any credential-shaped findings:

python3 Scripts/roadshow_digital_human_playback_audit.py "$EVIDENCE_DIR" --json

The playback log should include at least one closure path for roadshow smoke, and
full acceptance should cover:
- wav_synth_success -> playback_finished source=native_audio
- fallback=systemTTS -> playback_finished source=system_tts
- playback_timeout -> playback_finished source=timeout
CONSOLE
fi

section "Manual smoke checklist"
cat <<'CHECKLIST'
1. [auto] This script checked physical device visibility, signing settings, and iPhoneOS build gate.
2. [auto] Run Scripts/verify_phase2.sh before the final demo cut; it includes RoadshowRouteVerify, RoadshowDemoVerify, and SharePackagePrivacyVerify.
3. [manual] In Xcode, select a connected iPhone target and a valid Team.
4. [manual] Add launch args: --reset-roadshow-demo --seed-roadshow-demo --roadshow-offline-mode.
5. [manual] Add env: DREAMJOURNEY_SEED=roadshow_demo, DREAMJOURNEY_RESET_DEMO=1, DREAMJOURNEY_ROADSHOW_OFFLINE=1.
6. [manual] Run on device and capture console lines containing [RoadshowDemo].
7. [manual] Home: confirm roadshow banner and "路线" entry are visible.
8. [manual] Stage 1 回忆: trigger mock/voice dialog and confirm messages plus digital-human state changes.
9. [manual] Stage 1 boundary: confirm host wording says no diagnosis and no impersonation.
10. [semi-auto] Digital-human diagnostics: launch the app or open the top-right diagnostics sheet so it writes Documents/diagnostics/digital_human_readiness.txt and .json; preflight copies them into diagnostics/. Use the copy buttons only as fallback, and confirm no key/token/secret appears.
11. [manual] Stage 2 信箱: open a delivered demo letter and confirm the reply says it is not a real reply from the deceased.
12. [manual] Stage 3 档案: open text/personality/photo entries and confirm mock photo analysis is visible without live upload.
13. [manual] Stage 4 足迹: switch city/nation/world plus generations; confirm illuminated regions and stats change.
14. [manual] Stage 4 分享海报: open poster preview/share/export and check text/QR readability.
15. [manual] Stage 5 亲友: open member care dashboard and confirm observation window, coverage, masked report, and suggestions.
16. [manual] Stage 5 privacy: confirm the dashboard does not show full raw transcript sentences.
17. [manual] Stage 6 分享包: export all-family and single-member packages.
18. [semi-auto] Sample package JSON and confirm no localOnly/private text, full letter body, raw transcript, or unauthorized member sentinel.
19. [semi-auto] Run python3 Scripts/roadshow_digital_human_playback_audit.py <evidence-dir> --json. Strict rehearsal should find native_audio, system_tts, and timeout samples with no credential-shaped log content.
20. [semi-auto] Run python3 Scripts/roadshow_evidence_report.py <evidence-dir> --write --fail-on-missing and resolve missing diagnostics, screenshots, recordings, logs, or share packages.
21. [manual] Save screenshots/logs; keep the 6-stage main route under 6 minutes and fallback rerun under 2 minutes.
CHECKLIST

if [[ "$DEVICE_READY" -eq 0 ]]; then
  section "No-device next steps"
  cat <<NEXTSTEPS
Evidence directory: $EVIDENCE_DIR
1. Connect a paired, developer-enabled physical iPhone/iPad/iPod.
2. Confirm Xcode can see the device and has a valid Team for $BUNDLE_ID.
3. Rerun: Scripts/roadshow_device_smoke_preflight.sh
4. Keep the generated /tmp/dreamjourney_roadshow_smoke_<timestamp> directory with xctrace/devicectl output, build logs, install/launch results, and container samples.
5. If install or launch reports an untrusted developer profile, trust the profile on the device, then rerun the script to refresh evidence.
NEXTSTEPS
else
  section "Evidence summary"
  find "$EVIDENCE_DIR" -maxdepth 1 -type f -print | sort
fi

section "Evidence package status"
python3 Scripts/roadshow_evidence_report.py "$EVIDENCE_DIR" --write --quiet || true

if [[ "$DEVICE_READY" -eq 0 && "$ALLOW_NO_DEVICE" -eq 0 ]]; then
  printf '\nFAIL: Physical-device smoke is blocked because no iOS device is connected.\n'
  printf 'For script/build validation without a device, rerun with --allow-no-device.\n'
  printf 'Evidence directory: %s\n' "$EVIDENCE_DIR"
  exit 2
fi

if [[ "$DEVICE_READY" -eq 0 ]]; then
  printf '\nPASS_WITH_CONCERNS: Script and iPhoneOS build gate passed, but no physical-device smoke was performed. Evidence saved to %s\n' "$EVIDENCE_DIR"
elif [[ "$DEVICE_AUTOMATION_CONCERNS" -ne 0 ]]; then
  printf '\nPASS_WITH_CONCERNS: Physical iOS device detected and iPhoneOS build gate passed, but automated install/launch or container evidence had concerns. Evidence saved to %s\n' "$EVIDENCE_DIR"
else
  printf '\nPASS: Physical iOS device detected, iPhoneOS build gate passed, and install/launch evidence was captured. Evidence saved to %s\n' "$EVIDENCE_DIR"
fi

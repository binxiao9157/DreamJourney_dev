#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

ALLOW_NO_DEVICE=0
if [[ "${1:-}" == "--allow-no-device" ]]; then
  ALLOW_NO_DEVICE=1
fi

WORKSPACE="DreamJourney.xcworkspace"
SCHEME="DreamJourney"
CONFIGURATION="Debug"

ROADSHOW_ARGS="--reset-roadshow-demo --seed-roadshow-demo --roadshow-offline-mode"
ROADSHOW_ENV="DREAMJOURNEY_SEED=roadshow_demo DREAMJOURNEY_RESET_DEMO=1 DREAMJOURNEY_ROADSHOW_OFFLINE=1"

section() {
  printf '\n== %s ==\n' "$1"
}

section "Roadshow launch contract"
printf 'Launch arguments: %s\n' "$ROADSHOW_ARGS"
printf 'Environment: %s\n' "$ROADSHOW_ENV"
printf 'Optional explicit mock args: --use-mock-dialog-engine --use-mock-safety-guard\n'

section "Connected physical iOS devices"
XCTRACE_DEVICES="$(xcrun xctrace list devices 2>/dev/null || true)"
printf '%s\n' "$XCTRACE_DEVICES"

PHYSICAL_IOS_DEVICES="$(
  printf '%s\n' "$XCTRACE_DEVICES" |
    awk '
      /^== Devices ==/ { in_devices = 1; next }
      /^== Simulators ==/ { in_devices = 0 }
      in_devices && /(iPhone|iPad|iPod)/ { print }
    '
)"

if [[ -z "$PHYSICAL_IOS_DEVICES" ]]; then
  printf '\nWARN: No connected physical iPhone/iPad/iPod detected.\n'
  DEVICE_READY=0
else
  DEVICE_READY=1
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
printf '%s\n' "$BUILD_SETTINGS" |
  awk '
    /PRODUCT_BUNDLE_IDENTIFIER =/ ||
    /DEVELOPMENT_TEAM =/ ||
    /CODE_SIGN_STYLE =/ ||
    /IPHONEOS_DEPLOYMENT_TARGET =/ ||
    /SDKROOT =/ { print }
  '

if ! printf '%s\n' "$BUILD_SETTINGS" | grep -q 'DEVELOPMENT_TEAM = [A-Za-z0-9]'; then
  printf '\nWARN: DEVELOPMENT_TEAM is empty or not visible. Xcode manual signing may still be required before physical-device Run.\n'
fi

section "iPhoneOS build gate"
xcodebuild \
  -workspace "$WORKSPACE" \
  -scheme "$SCHEME" \
  -configuration "$CONFIGURATION" \
  -destination 'generic/platform=iOS' \
  CODE_SIGNING_ALLOWED=NO \
  build

section "Manual smoke checklist"
cat <<'CHECKLIST'
1. In Xcode, select a connected iPhone target and a valid Team.
2. Add launch arguments:
   --reset-roadshow-demo --seed-roadshow-demo --roadshow-offline-mode
3. Add environment:
   DREAMJOURNEY_SEED=roadshow_demo
   DREAMJOURNEY_RESET_DEMO=1
   DREAMJOURNEY_ROADSHOW_OFFLINE=1
4. Run on device and capture console lines containing [RoadshowDemo].
5. Walk the demo route: 信箱 -> 档案 -> 回忆/mock -> 亲友关怀看板 -> 知识库分享包.
6. Save screenshots/logs and mark failures against docs/superpowers/reports/2026-06-11-roadshow-demo-cut.md.
CHECKLIST

if [[ "$DEVICE_READY" -eq 0 && "$ALLOW_NO_DEVICE" -eq 0 ]]; then
  printf '\nFAIL: Physical-device smoke is blocked because no iOS device is connected.\n'
  printf 'For script/build validation without a device, rerun with --allow-no-device.\n'
  exit 2
fi

if [[ "$DEVICE_READY" -eq 0 ]]; then
  printf '\nPASS_WITH_CONCERNS: Script and iPhoneOS build gate passed, but no physical-device smoke was performed.\n'
else
  printf '\nPASS: Physical iOS device detected and iPhoneOS build gate passed. Continue with manual Xcode Run and screenshot/log capture.\n'
fi

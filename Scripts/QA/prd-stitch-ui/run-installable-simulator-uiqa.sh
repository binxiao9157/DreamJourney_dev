#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../../.." && pwd)"

SCHEME="${SCHEME:-DreamJourney}"
CONFIGURATION="${CONFIGURATION:-Debug}"
SIMULATOR_NAME="${SIMULATOR_NAME:-iPhone 16}"
APP_PRODUCT_NAME="${APP_PRODUCT_NAME:-DreamJourney}"
SWIFT_ACTIVE_COMPILATION_CONDITIONS="${SWIFT_ACTIVE_COMPILATION_CONDITIONS:-DEBUG UI_QA_SIMULATOR}"
DERIVED_DATA_PATH="${DERIVED_DATA_PATH:-$ROOT_DIR/tmp/visual-qa/prd-stitch-ui/DerivedDataInstallableSimulatorUIQA}"
OUTPUT_DIR="${OUTPUT_DIR:-$ROOT_DIR/tmp/visual-qa/prd-stitch-ui/installable-simulator-uiqa/$(date +%Y%m%d-%H%M%S)}"
BUILD_LOG="${BUILD_LOG:-$OUTPUT_DIR/build.log}"
INSTALL_ENV_PATH="${INSTALL_ENV_PATH:-$OUTPUT_DIR/install.env}"
LOCAL_BUNDLE_ID="${LOCAL_BUNDLE_ID:-com.yxj.dreamjourney.app}"
LOCAL_DEVELOPMENT_TEAM="${LOCAL_DEVELOPMENT_TEAM:-2BTR77V3R8}"
XCCONFIG_PATH="${XCCONFIG_PATH:-}"

mkdir -p "$OUTPUT_DIR"
cd "$ROOT_DIR"

fail() {
  echo "[installable-simulator-uiqa] $*" >&2
  if [[ -f "$BUILD_LOG" ]]; then
    echo "[installable-simulator-uiqa] build log tail:" >&2
    tail -100 "$BUILD_LOG" >&2 || true
  fi
  exit 1
}

booted_simulator_udid() {
  xcrun simctl list devices booted | awk -F '[()]' '/Booted/ { print $2; exit }'
}

shell_quote() {
  printf "%q" "$1"
}

write_env_var() {
  local key="$1"
  local value="$2"
  printf "%s=%s\n" "$key" "$(shell_quote "$value")" >> "$INSTALL_ENV_PATH"
}

SIMULATOR_UDID="${SIMULATOR_UDID:-$(booted_simulator_udid)}"
if [[ -z "$SIMULATOR_UDID" ]]; then
  xcrun simctl boot "$SIMULATOR_NAME" >/dev/null
  SIMULATOR_UDID="$(booted_simulator_udid)"
fi
[[ -n "$SIMULATOR_UDID" ]] || fail "No booted simulator. Set SIMULATOR_UDID or SIMULATOR_NAME."

echo "[installable-simulator-uiqa] Building $SCHEME for simulator..."
echo "[installable-simulator-uiqa] Local QA bundle id: $LOCAL_BUNDLE_ID"
echo "[installable-simulator-uiqa] Local QA team id: $LOCAL_DEVELOPMENT_TEAM"

BUILD_SETTINGS=(
  CODE_SIGNING_ALLOWED=NO
  SWIFT_ACTIVE_COMPILATION_CONDITIONS="$SWIFT_ACTIVE_COMPILATION_CONDITIONS"
  DREAMJOURNEY_PRODUCT_BUNDLE_IDENTIFIER="$LOCAL_BUNDLE_ID"
  DREAMJOURNEY_DEVELOPMENT_TEAM="$LOCAL_DEVELOPMENT_TEAM"
  "EXCLUDED_ARCHS[sdk=iphonesimulator*]="
  EXCLUDED_ARCHS=
  ARCHS=arm64
  ONLY_ACTIVE_ARCH=NO
)
XCCONFIG_ARGS=()
if [[ -n "$XCCONFIG_PATH" ]]; then
  [[ -f "$XCCONFIG_PATH" ]] || fail "xcconfig not found: $XCCONFIG_PATH"
  python3 - "$XCCONFIG_PATH" <<'PY'
import sys
from pathlib import Path

forbidden = {
    "DREAMJOURNEY_BACKEND_API_TOKEN",
    "VOLCENGINE_APP_ID",
    "VOLCENGINE_APP_KEY",
    "VOLCENGINE_APP_TOKEN",
}
path = Path(sys.argv[1])
configured = set()
for line in path.read_text(encoding="utf-8").splitlines():
    stripped = line.strip()
    if not stripped or stripped.startswith("//") or "=" not in stripped:
        continue
    configured.add(stripped.split("=", 1)[0].strip())
found = sorted(configured & forbidden)
if found:
    raise SystemExit("xcconfig contains retired mobile credential keys: " + ", ".join(found))
PY
  XCCONFIG_ARGS=(-xcconfig "$XCCONFIG_PATH")
fi

xcodebuild \
  -workspace DreamJourney.xcworkspace \
  -scheme "$SCHEME" \
  -configuration "$CONFIGURATION" \
  -sdk iphonesimulator \
  -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath "$DERIVED_DATA_PATH" \
  "${XCCONFIG_ARGS[@]}" \
  "${BUILD_SETTINGS[@]}" \
  build > "$BUILD_LOG"

APP_PATH="$DERIVED_DATA_PATH/Build/Products/$CONFIGURATION-iphonesimulator/$APP_PRODUCT_NAME.app"
[[ -d "$APP_PATH" ]] || fail "Built app not found: $APP_PATH"

QA_MOBILE_CREDENTIAL_APP_PATH="$APP_PATH" \
  python3 "$ROOT_DIR/Scripts/QA/product-v4/product-v4-qa-mobile-credential-artifact-check.py"

BUNDLE_ID="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$APP_PATH/Info.plist")"
[[ "$BUNDLE_ID" == "$LOCAL_BUNDLE_ID" ]] || fail "Built app bundle id is $BUNDLE_ID, expected $LOCAL_BUNDLE_ID"
[[ "$BUNDLE_ID" != "com.gaominge.dreamjourney.app" ]] || fail "Built app is using the shared default bundle id."

EXECUTABLE_NAME="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleExecutable' "$APP_PATH/Info.plist")"
EXECUTABLE_PATH="$APP_PATH/$EXECUTABLE_NAME"
[[ -f "$EXECUTABLE_PATH" ]] || fail "Executable not found: $EXECUTABLE_PATH"
ARCHS="$(lipo -archs "$EXECUTABLE_PATH")"
[[ "$ARCHS" == *"arm64"* ]] || fail "Built simulator app is not arm64-compatible. archs=$ARCHS"

if [[ -d "$APP_PATH/Frameworks" ]]; then
  while IFS= read -r -d '' framework; do
    /usr/bin/codesign --force --sign - --timestamp=none "$framework" >/dev/null
  done < <(find "$APP_PATH/Frameworks" -type d -name "*.framework" -print0)
  while IFS= read -r -d '' dylib; do
    /usr/bin/codesign --force --sign - --timestamp=none "$dylib" >/dev/null
  done < <(find "$APP_PATH/Frameworks" -type f -name "*.dylib" -print0)
fi
/usr/bin/codesign --force --sign - --timestamp=none "$APP_PATH" >/dev/null

echo "[installable-simulator-uiqa] Installing $BUNDLE_ID on $SIMULATOR_UDID..."
xcrun simctl terminate "$SIMULATOR_UDID" "$BUNDLE_ID" >/dev/null 2>&1 || true
xcrun simctl uninstall "$SIMULATOR_UDID" "$BUNDLE_ID" >/dev/null 2>&1 || true
xcrun simctl install "$SIMULATOR_UDID" "$APP_PATH"
xcrun simctl spawn "$SIMULATOR_UDID" defaults delete "$BUNDLE_ID" >/dev/null 2>&1 || true
DATA_CONTAINER="$(xcrun simctl get_app_container "$SIMULATOR_UDID" "$BUNDLE_ID" data)"

rm -f "$INSTALL_ENV_PATH"
write_env_var "SIMULATOR_UDID" "$SIMULATOR_UDID"
write_env_var "APP_PATH" "$APP_PATH"
write_env_var "BUNDLE_ID" "$BUNDLE_ID"
write_env_var "DATA_CONTAINER" "$DATA_CONTAINER"
write_env_var "APP_EXECUTABLE_ARCHS" "$ARCHS"

echo "[installable-simulator-uiqa] Build log: $BUILD_LOG"
echo "[installable-simulator-uiqa] Install env: $INSTALL_ENV_PATH"

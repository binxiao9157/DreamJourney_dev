#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../../.." && pwd)"

SCHEME="${SCHEME:-DreamJourney}"
CONFIGURATION="${CONFIGURATION:-Debug}"
RUN_ID="${RUN_ID:-$(date +%Y%m%d-%H%M%S)-iphoneos-generic-build}"
OUTPUT_ROOT="${OUTPUT_ROOT:-$ROOT_DIR/tmp/visual-qa/prd-stitch-ui/iphoneos-generic-build}"
OUTPUT_DIR="$OUTPUT_ROOT/$RUN_ID"
DERIVED_DATA_PATH="${DERIVED_DATA_PATH:-$OUTPUT_DIR/DerivedData}"
BUILD_LOG="$OUTPUT_DIR/iphoneos-generic-build.log"
REPORT_PATH="$OUTPUT_DIR/report.md"
LOCAL_BUNDLE_ID="${LOCAL_BUNDLE_ID:-com.yxj.dreamjourney.app}"
LOCAL_DEVELOPMENT_TEAM="${LOCAL_DEVELOPMENT_TEAM:-2BTR77V3R8}"

mkdir -p "$OUTPUT_DIR"
cd "$ROOT_DIR"

fail() {
  {
    echo
    echo "## Result"
    echo
    echo "- Status: failed"
    echo "- Reason: $*"
  } >> "$REPORT_PATH"
  echo "[iphoneos-generic-build] $*" >&2
  if [[ -f "$BUILD_LOG" ]]; then
    echo "[iphoneos-generic-build] build log tail:" >&2
    tail -120 "$BUILD_LOG" >&2 || true
  fi
  exit 1
}

cat > "$REPORT_PATH" <<REPORT
# iPhoneOS Generic Build

- Run ID: \`$RUN_ID\`
- Output dir: \`$OUTPUT_DIR\`
- Build log: \`$BUILD_LOG\`
- Bundle ID override: \`$LOCAL_BUNDLE_ID\`
- Development Team override: \`$LOCAL_DEVELOPMENT_TEAM\`

REPORT

echo "[iphoneos-generic-build] Building $SCHEME for generic iPhoneOS..."
xcodebuild \
  -workspace DreamJourney.xcworkspace \
  -scheme "$SCHEME" \
  -configuration "$CONFIGURATION" \
  -sdk iphoneos \
  -destination 'generic/platform=iOS' \
  -derivedDataPath "$DERIVED_DATA_PATH" \
  CODE_SIGNING_ALLOWED=NO \
  DREAMJOURNEY_PRODUCT_BUNDLE_IDENTIFIER="$LOCAL_BUNDLE_ID" \
  DREAMJOURNEY_DEVELOPMENT_TEAM="$LOCAL_DEVELOPMENT_TEAM" \
  EXCLUDED_ARCHS='' \
  ARCHS=arm64 \
  ONLY_ACTIVE_ARCH=NO \
  build > "$BUILD_LOG" 2>&1 || fail "xcodebuild generic iPhoneOS build failed"

APP_PATH="$DERIVED_DATA_PATH/Build/Products/$CONFIGURATION-iphoneos/DreamJourney.app"
[[ -d "$APP_PATH" ]] || fail "Built app not found: $APP_PATH"

BUNDLE_ID="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$APP_PATH/Info.plist")"
[[ "$BUNDLE_ID" == "$LOCAL_BUNDLE_ID" ]] || fail "Built app bundle id is $BUNDLE_ID, expected $LOCAL_BUNDLE_ID"
[[ "$BUNDLE_ID" != "com.gaominge.dreamjourney.app" ]] || fail "Built app is using the shared default bundle id."

{
  echo "## Result"
  echo
  echo "- Status: passed"
  echo "- iPhoneOS generic build: passed"
  echo "- App path: \`$APP_PATH\`"
  echo "- Bundle ID: \`$BUNDLE_ID\`"
} >> "$REPORT_PATH"

echo "[iphoneos-generic-build] iPhoneOS generic build: passed"
echo "[iphoneos-generic-build] Report: $REPORT_PATH"
echo "[iphoneos-generic-build] Build log: $BUILD_LOG"

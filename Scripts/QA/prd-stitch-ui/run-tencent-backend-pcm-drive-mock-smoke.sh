#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../../.." && pwd)"
WORKSPACE_ROOT="$(cd "$ROOT_DIR/.." && pwd)"
BACKEND_ROOT="${BACKEND_ROOT:-$WORKSPACE_ROOT/DreamJourneyBackend}"

SCHEME="${SCHEME:-DreamJourney}"
CONFIGURATION="${CONFIGURATION:-Debug}"
SIMULATOR_NAME="${SIMULATOR_NAME:-iPhone 17}"
SWIFT_ACTIVE_COMPILATION_CONDITIONS='DEBUG UI_QA_SIMULATOR'
DERIVED_DATA_PATH="${DERIVED_DATA_PATH:-$ROOT_DIR/tmp/visual-qa/prd-stitch-ui/DerivedDataTencentBackendPCMDriveMockSmoke}"
OUTPUT_ROOT="${OUTPUT_ROOT:-$ROOT_DIR/tmp/visual-qa/prd-stitch-ui/tencent-backend-pcm-drive-mock-smoke}"
RUN_ID="${RUN_ID:-$(date +%Y%m%d-%H%M%S)}"
DJ_TENCENT_BACKEND_PCM_MOCK_VOICE_PROFILE_ID="${DJ_TENCENT_BACKEND_PCM_MOCK_VOICE_PROFILE_ID:-${VOICE_CLONE_READY_PROFILE_ID:-}}"
DJ_TENCENT_BACKEND_PCM_MOCK_USER_ID="${DJ_TENCENT_BACKEND_PCM_MOCK_USER_ID:-${VOICE_CLONE_READY_PROFILE_USER_ID:-}}"
LOCAL_BUNDLE_ID="${LOCAL_BUNDLE_ID:-com.yxj.dreamjourney.app}"
LOCAL_DEVELOPMENT_TEAM="${LOCAL_DEVELOPMENT_TEAM:-2BTR77V3R8}"
OUTPUT_DIR="$OUTPUT_ROOT/$RUN_ID"
BUILD_LOG="$OUTPUT_DIR/build.log"
RUNTIME_LOG="$OUTPUT_DIR/runtime.log"
OS_LOG="$OUTPUT_DIR/oslog.log"
SCREENSHOT_PATH="$OUTPUT_DIR/01-tencent-backend-pcm-drive-mock-smoke.png"
RESULT_COPY_PATH="$OUTPUT_DIR/tencent-backend-pcm-drive-mock-smoke-result.json"
RESULT_BASENAME="tencent-backend-pcm-drive-mock-smoke-result.json"
COMPLETION_PATTERN="TencentBackendPCMDriveMockSmoke completed"
LOG_WAIT_TIMEOUT="${LOG_WAIT_TIMEOUT:-120}"

mkdir -p "$OUTPUT_DIR"
cd "$ROOT_DIR"

fail() {
  echo "[tencent-backend-pcm-drive-mock-smoke] $*" >&2
  if [[ -f "$RUNTIME_LOG" ]]; then
    echo "[tencent-backend-pcm-drive-mock-smoke] runtime log tail:" >&2
    tail -100 "$RUNTIME_LOG" >&2 || true
  fi
  if [[ -f "$OS_LOG" ]]; then
    echo "[tencent-backend-pcm-drive-mock-smoke] os log tail:" >&2
    tail -100 "$OS_LOG" >&2 || true
  fi
  exit 1
}

xcconfig_value() {
  local key="$1"
  local file="$2"
  [[ -f "$file" ]] || return 0
  awk -F= -v key="$key" '
    $0 !~ /^[[:space:]]*\/\// && $1 ~ "^[[:space:]]*" key "[[:space:]]*$" {
      value=$2
      sub(/[[:space:]]*\/\/.*/, "", value)
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", value)
      print value
      exit
    }
  ' "$file"
}

normalize_xcconfig_url() {
  local value="${1:-}"
  value="${value//:\/\$()\//:\/\/}"
  printf '%s' "$value"
}

resolve_deployed_backend_config() {
  python3 - "$BACKEND_ROOT" "${DEPLOYED_BACKEND_ACCESS_DOC:-}" <<'PY'
import re
import sys
from pathlib import Path

backend_root = Path(sys.argv[1])
explicit = sys.argv[2].strip()
candidates = []
if explicit:
    candidates.append(Path(explicit))
candidates.extend([
    backend_root / "private/deployed-backend-access.md",
    backend_root / "deployed-backend-access.md",
])

for path in candidates:
    if not path.exists():
        continue
    content = path.read_text(encoding="utf-8")
    base_url = ""
    for line in content.splitlines():
        stripped = line.strip()
        if stripped.startswith("DreamJourneyBackendBaseURL="):
            base_url = stripped.split("=", 1)[1].strip().strip("'\"")
    if not base_url:
        match = re.search(r"https?://[A-Za-z0-9._~:/?#\[\]@!$&'()*+,;=%-]+", content)
        base_url = match.group(0).rstrip("/,") if match else ""
    if base_url:
        print(f"base_url={base_url}")
        raise SystemExit(0)

raise SystemExit(0)
PY
}

BACKEND_XCCONFIG="$ROOT_DIR/DreamJourney/Config/Backend.local.xcconfig"
XCCONFIG_BASE_URL="$(normalize_xcconfig_url "$(xcconfig_value DREAMJOURNEY_BACKEND_BASE_URL "$BACKEND_XCCONFIG")")"
CONFIG_OUTPUT="$(resolve_deployed_backend_config || true)"
DOC_BASE_URL="$(printf '%s\n' "$CONFIG_OUTPUT" | awk -F= '/^base_url=/{print substr($0, 10); exit}')"

BACKEND_BASE_URL="${BACKEND_BASE_URL:-${XCCONFIG_BASE_URL:-$DOC_BASE_URL}}"

[[ -n "$BACKEND_BASE_URL" ]] || fail "BACKEND_BASE_URL is required. Export it, configure Backend.local.xcconfig, or provide deployed-backend-access.md."
[[ -n "$DJ_TENCENT_BACKEND_PCM_MOCK_VOICE_PROFILE_ID" ]] || fail "DJ_TENCENT_BACKEND_PCM_MOCK_VOICE_PROFILE_ID or VOICE_CLONE_READY_PROFILE_ID is required."
[[ -n "$DJ_TENCENT_BACKEND_PCM_MOCK_USER_ID" ]] || fail "DJ_TENCENT_BACKEND_PCM_MOCK_USER_ID or VOICE_CLONE_READY_PROFILE_USER_ID is required."

booted_simulator_udid() {
  xcrun simctl list devices booted | awk -F '[()]' '/Booted/ { print $2; exit }'
}

SIMULATOR_UDID="${SIMULATOR_UDID:-$(booted_simulator_udid)}"
if [[ -z "$SIMULATOR_UDID" ]]; then
  xcrun simctl boot "$SIMULATOR_NAME" >/dev/null
  SIMULATOR_UDID="$(booted_simulator_udid)"
fi
[[ -n "$SIMULATOR_UDID" ]] || fail "No booted simulator. Set SIMULATOR_UDID or SIMULATOR_NAME."

echo "[tencent-backend-pcm-drive-mock-smoke] Building UIQA app..."
echo "[tencent-backend-pcm-drive-mock-smoke] Local QA bundle id: $LOCAL_BUNDLE_ID"
echo "[tencent-backend-pcm-drive-mock-smoke] Local QA team id: $LOCAL_DEVELOPMENT_TEAM"
xcodebuild \
  -workspace DreamJourney.xcworkspace \
  -scheme "$SCHEME" \
  -configuration "$CONFIGURATION" \
  -sdk iphonesimulator \
  -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath "$DERIVED_DATA_PATH" \
  CODE_SIGNING_ALLOWED=NO \
  SWIFT_ACTIVE_COMPILATION_CONDITIONS="$SWIFT_ACTIVE_COMPILATION_CONDITIONS" \
  DREAMJOURNEY_PRODUCT_BUNDLE_IDENTIFIER="$LOCAL_BUNDLE_ID" \
  DREAMJOURNEY_DEVELOPMENT_TEAM="$LOCAL_DEVELOPMENT_TEAM" \
  DREAMJOURNEY_BACKEND_BASE_URL="$BACKEND_BASE_URL" \
  EXCLUDED_ARCHS='' \
  ARCHS=arm64 \
  ONLY_ACTIVE_ARCH=NO \
  build > "$BUILD_LOG" 2>&1

APP_PATH="$DERIVED_DATA_PATH/Build/Products/$CONFIGURATION-iphonesimulator/DreamJourney.app"
[[ -d "$APP_PATH" ]] || fail "Built app not found: $APP_PATH"
QA_MOBILE_CREDENTIAL_APP_PATH="$APP_PATH" \
  python3 "$ROOT_DIR/Scripts/QA/product-v4/product-v4-qa-mobile-credential-artifact-check.py"

BUNDLE_ID="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$APP_PATH/Info.plist")"
[[ -n "$BUNDLE_ID" ]] || fail "Unable to read bundle id from $APP_PATH"
[[ "$BUNDLE_ID" == "$LOCAL_BUNDLE_ID" ]] || fail "Built app bundle id is $BUNDLE_ID, expected $LOCAL_BUNDLE_ID"
[[ "$BUNDLE_ID" != "com.gaominge.dreamjourney.app" ]] || fail "Built app is using the shared default bundle id."

echo "[tencent-backend-pcm-drive-mock-smoke] Installing $BUNDLE_ID on $SIMULATOR_UDID..."
xcrun simctl terminate "$SIMULATOR_UDID" "$BUNDLE_ID" >/dev/null 2>&1 || true
xcrun simctl uninstall "$SIMULATOR_UDID" "$BUNDLE_ID" >/dev/null 2>&1 || true
xcrun simctl install "$SIMULATOR_UDID" "$APP_PATH"
xcrun simctl spawn "$SIMULATOR_UDID" defaults delete "$BUNDLE_ID" >/dev/null 2>&1 || true
DATA_CONTAINER="$(xcrun simctl get_app_container "$SIMULATOR_UDID" "$BUNDLE_ID" data)"
RESULT_FILE="$DATA_CONTAINER/Documents/$RESULT_BASENAME"
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

echo "[tencent-backend-pcm-drive-mock-smoke] Launching fake Tencent backend PCM-drive harness..."
xcrun simctl launch --console "$SIMULATOR_UDID" "$BUNDLE_ID" \
  DJUITestBypassLogin \
  DJRunTencentBackendPCMDriveMockSmoke \
  "DJTencentBackendPCMDriveMockVoiceProfileId=$DJ_TENCENT_BACKEND_PCM_MOCK_VOICE_PROFILE_ID" \
  "DJTencentBackendPCMDriveMockUserId=$DJ_TENCENT_BACKEND_PCM_MOCK_USER_ID" > "$RUNTIME_LOG" 2>&1 &
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

python3 - "$RESULT_COPY_PATH" "$DJ_TENCENT_BACKEND_PCM_MOCK_VOICE_PROFILE_ID" "$DJ_TENCENT_BACKEND_PCM_MOCK_USER_ID" <<'PY'
import json
import sys

result_path, expected_voice_profile_id, expected_user_id = sys.argv[1:4]
with open(result_path, "r", encoding="utf-8") as handle:
    result = json.load(handle)

if result.get("completed") is not True:
    raise SystemExit(f"Tencent backend PCM-drive mock smoke did not complete: {result}")
if result.get("voiceProfileId") != expected_voice_profile_id:
    raise SystemExit(f"voiceProfileId mismatch: {result}")
if result.get("userId") != expected_user_id:
    raise SystemExit(f"userId mismatch: {result}")
if result.get("pcmCompatible") is not True:
    raise SystemExit(f"PCM should be compatible: {result}")
if result.get("audioDataOmitted") is not True:
    raise SystemExit(f"Raw audio must be omitted: {result}")
if result.get("outputMode") != "tencentAudioDrive":
    raise SystemExit(f"outputMode mismatch: {result}")
if result.get("audioFormat") != "pcm16kMono":
    raise SystemExit(f"audioFormat mismatch: {result}")
if int(result.get("pcmChunkCount") or 0) <= 1:
    raise SystemExit(f"PCM chunks should include data chunks and final chunk: {result}")
if result.get("finalChunkObserved") is not True:
    raise SystemExit(f"Final PCM chunk was not observed: {result}")
if result.get("sequenceIsContiguous") is not True:
    raise SystemExit(f"PCM chunk sequence should be contiguous: {result}")
if int(result.get("preparedByteCount") or 0) < int(result.get("byteCount") or -1):
    raise SystemExit(f"Prepared PCM bytes should include original synthesis PCM: {result}")
if int(result.get("sentPCMByteCount") or 0) != int(result.get("preparedByteCount") or -1):
    raise SystemExit(f"Sent PCM bytes should equal prepared PCM byteCount: {result}")
if result.get("interruptProbeCompleted") is not True:
    raise SystemExit(f"Interrupt probe should clear the active provider request: {result}")
PY

xcrun simctl io "$SIMULATOR_UDID" screenshot "$SCREENSHOT_PATH" >/dev/null
xcrun simctl terminate "$SIMULATOR_UDID" "$BUNDLE_ID" >/dev/null 2>&1 || true

echo "[tencent-backend-pcm-drive-mock-smoke] Build log: $BUILD_LOG"
echo "[tencent-backend-pcm-drive-mock-smoke] Runtime log: $RUNTIME_LOG"
echo "[tencent-backend-pcm-drive-mock-smoke] OS log: $OS_LOG"
echo "[tencent-backend-pcm-drive-mock-smoke] Result: $RESULT_COPY_PATH"
echo "[tencent-backend-pcm-drive-mock-smoke] Screenshot: $SCREENSHOT_PATH"

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
DERIVED_DATA_PATH="${DERIVED_DATA_PATH:-$ROOT_DIR/tmp/visual-qa/prd-stitch-ui/DerivedDataVoiceCloneSynthesisRuntimeSmoke}"
OUTPUT_ROOT="${OUTPUT_ROOT:-$ROOT_DIR/tmp/visual-qa/prd-stitch-ui/voice-clone-synthesis-runtime-smoke}"
RUN_ID="${RUN_ID:-$(date +%Y%m%d-%H%M%S)}"
VOICE_CLONE_READY_PROFILE_ID="${VOICE_CLONE_READY_PROFILE_ID:-S_PhXlHqB52}"
OUTPUT_DIR="$OUTPUT_ROOT/$RUN_ID"
BUILD_LOG="$OUTPUT_DIR/build.log"
RUNTIME_LOG="$OUTPUT_DIR/runtime.log"
OS_LOG="$OUTPUT_DIR/oslog.log"
SCREENSHOT_PATH="$OUTPUT_DIR/01-voice-clone-synthesis-runtime.png"
RESULT_COPY_PATH="$OUTPUT_DIR/voice-clone-synthesis-runtime-smoke-result.json"
RESULT_BASENAME="voice-clone-synthesis-runtime-smoke-result.json"
COMPLETION_PATTERN="VoiceCloneSynthesisRuntimeSmoke completed"
LOG_WAIT_TIMEOUT="${LOG_WAIT_TIMEOUT:-90}"

mkdir -p "$OUTPUT_DIR"
cd "$ROOT_DIR"

fail() {
  echo "[voice-clone-synthesis-runtime-smoke] $*" >&2
  if [[ -f "$RUNTIME_LOG" ]]; then
    echo "[voice-clone-synthesis-runtime-smoke] runtime log tail:" >&2
    tail -100 "$RUNTIME_LOG" >&2 || true
  fi
  if [[ -f "$OS_LOG" ]]; then
    echo "[voice-clone-synthesis-runtime-smoke] os log tail:" >&2
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
    token = ""
    for line in content.splitlines():
        stripped = line.strip()
        if stripped.startswith("DreamJourneyBackendBaseURL="):
            base_url = stripped.split("=", 1)[1].strip().strip("'\"")
        elif stripped.startswith("BACKEND_API_TOKEN="):
            token = stripped.split("=", 1)[1].strip().strip("'\"")
        elif stripped.startswith("DreamJourneyBackendAPIToken=") and not token:
            token = stripped.split("=", 1)[1].strip().strip("'\"")
    if not base_url:
        match = re.search(r"https?://[A-Za-z0-9._~:/?#\[\]@!$&'()*+,;=%-]+", content)
        base_url = match.group(0).rstrip("/,") if match else ""
    if base_url or token:
        print(f"base_url={base_url}")
        print(f"token={token}")
        raise SystemExit(0)

raise SystemExit(0)
PY
}

BACKEND_XCCONFIG="$ROOT_DIR/DreamJourney/Config/Backend.local.xcconfig"
XCCONFIG_BASE_URL="$(normalize_xcconfig_url "$(xcconfig_value DREAMJOURNEY_BACKEND_BASE_URL "$BACKEND_XCCONFIG")")"
XCCONFIG_API_TOKEN="$(xcconfig_value DREAMJOURNEY_BACKEND_API_TOKEN "$BACKEND_XCCONFIG")"
CONFIG_OUTPUT="$(resolve_deployed_backend_config || true)"
DOC_BASE_URL="$(printf '%s\n' "$CONFIG_OUTPUT" | awk -F= '/^base_url=/{print substr($0, 10); exit}')"
DOC_API_TOKEN="$(printf '%s\n' "$CONFIG_OUTPUT" | awk -F= '/^token=/{print substr($0, 7); exit}')"

BACKEND_BASE_URL="${BACKEND_BASE_URL:-${XCCONFIG_BASE_URL:-$DOC_BASE_URL}}"
BACKEND_API_TOKEN="${BACKEND_API_TOKEN:-${XCCONFIG_API_TOKEN:-$DOC_API_TOKEN}}"

[[ -n "$BACKEND_BASE_URL" ]] || fail "BACKEND_BASE_URL is required. Export it, configure Backend.local.xcconfig, or provide deployed-backend-access.md."
[[ -n "$BACKEND_API_TOKEN" ]] || fail "BACKEND_API_TOKEN is required. Export it, configure Backend.local.xcconfig, or provide deployed-backend-access.md."
[[ "$BACKEND_API_TOKEN" != YOUR_* ]] || fail "BACKEND_API_TOKEN is still a placeholder."

booted_simulator_udid() {
  xcrun simctl list devices booted | awk -F '[()]' '/Booted/ { print $2; exit }'
}

SIMULATOR_UDID="${SIMULATOR_UDID:-$(booted_simulator_udid)}"
if [[ -z "$SIMULATOR_UDID" ]]; then
  xcrun simctl boot "$SIMULATOR_NAME" >/dev/null
  SIMULATOR_UDID="$(booted_simulator_udid)"
fi
[[ -n "$SIMULATOR_UDID" ]] || fail "No booted simulator. Set SIMULATOR_UDID or SIMULATOR_NAME."

echo "[voice-clone-synthesis-runtime-smoke] Building UIQA app..."
xcodebuild \
  -workspace DreamJourney.xcworkspace \
  -scheme "$SCHEME" \
  -configuration "$CONFIGURATION" \
  -sdk iphonesimulator \
  -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath "$DERIVED_DATA_PATH" \
  CODE_SIGNING_ALLOWED=NO \
  SWIFT_ACTIVE_COMPILATION_CONDITIONS="$SWIFT_ACTIVE_COMPILATION_CONDITIONS" \
  DREAMJOURNEY_BACKEND_BASE_URL="$BACKEND_BASE_URL" \
  DREAMJOURNEY_BACKEND_API_TOKEN="$BACKEND_API_TOKEN" \
  EXCLUDED_ARCHS='' \
  ARCHS=arm64 \
  ONLY_ACTIVE_ARCH=NO \
  build 2>&1 | python3 -c 'import sys
token = sys.argv[1]
replacement = "<redacted-backend-token>"
for line in sys.stdin:
    sys.stdout.write(line.replace(token, replacement) if token else line)
' "$BACKEND_API_TOKEN" > "$BUILD_LOG"

APP_PATH="$DERIVED_DATA_PATH/Build/Products/$CONFIGURATION-iphonesimulator/DreamJourney.app"
[[ -d "$APP_PATH" ]] || fail "Built app not found: $APP_PATH"

BUNDLE_ID="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$APP_PATH/Info.plist")"
[[ -n "$BUNDLE_ID" ]] || fail "Unable to read bundle id from $APP_PATH"

echo "[voice-clone-synthesis-runtime-smoke] Installing $BUNDLE_ID on $SIMULATOR_UDID..."
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

echo "[voice-clone-synthesis-runtime-smoke] Launching synthesis runtime harness..."
xcrun simctl launch --console "$SIMULATOR_UDID" "$BUNDLE_ID" \
  DJUITestBypassLogin \
  DJRunVoiceCloneSynthesisRuntimeSmoke \
  "DJVoiceCloneProbeProfileId=$VOICE_CLONE_READY_PROFILE_ID" > "$RUNTIME_LOG" 2>&1 &
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

python3 - "$RESULT_COPY_PATH" "$VOICE_CLONE_READY_PROFILE_ID" <<'PY'
import json
import sys

result_path, expected_voice_profile_id = sys.argv[1:3]

with open(result_path, "r", encoding="utf-8") as handle:
    result = json.load(handle)

if result.get("completed") is not True:
    raise SystemExit(f"Voice clone synthesis runtime smoke did not complete: {result}")
if result.get("pcmCompatible") is not True:
    raise SystemExit(f"PCM contract should be compatible: {result}")
if result.get("audioDataOmitted") is not True:
    raise SystemExit(f"Raw audio data must stay omitted: {result}")
if result.get("outputMode") != "tencentAudioDrive":
    raise SystemExit(f"outputMode mismatch: {result}")
if result.get("audioFormat") != "pcm16kMono":
    raise SystemExit(f"audioFormat mismatch: {result}")
if int(result.get("decodedByteCount") or 0) <= 0:
    raise SystemExit(f"decoded PCM should be non-empty: {result}")
if int(result.get("byteCount") or 0) != int(result.get("decodedByteCount") or -1):
    raise SystemExit(f"decoded byte count should match backend byteCount: {result}")
if result.get("voiceProfileId") != expected_voice_profile_id:
    raise SystemExit(f"voiceProfileId mismatch: {result}")
PY

xcrun simctl io "$SIMULATOR_UDID" screenshot "$SCREENSHOT_PATH" >/dev/null
xcrun simctl terminate "$SIMULATOR_UDID" "$BUNDLE_ID" >/dev/null 2>&1 || true

echo "[voice-clone-synthesis-runtime-smoke] Build log: $BUILD_LOG"
echo "[voice-clone-synthesis-runtime-smoke] Runtime log: $RUNTIME_LOG"
echo "[voice-clone-synthesis-runtime-smoke] OS log: $OS_LOG"
echo "[voice-clone-synthesis-runtime-smoke] Result: $RESULT_COPY_PATH"
echo "[voice-clone-synthesis-runtime-smoke] Screenshot: $SCREENSHOT_PATH"

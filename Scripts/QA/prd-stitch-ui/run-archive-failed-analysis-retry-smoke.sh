#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../../.." && pwd)"
WORKSPACE_ROOT="$(cd "$ROOT_DIR/.." && pwd)"
BACKEND_ROOT="${BACKEND_ROOT:-$WORKSPACE_ROOT/DreamJourneyBackend}"

SCHEME="${SCHEME:-DreamJourney}"
CONFIGURATION="${CONFIGURATION:-Debug}"
SIMULATOR_NAME="${SIMULATOR_NAME:-iPhone 16}"
SWIFT_ACTIVE_COMPILATION_CONDITIONS='DEBUG UI_QA_SIMULATOR'
DERIVED_DATA_PATH="${DERIVED_DATA_PATH:-$ROOT_DIR/tmp/visual-qa/prd-stitch-ui/DerivedDataArchiveFailedAnalysisRetrySmoke}"
OUTPUT_ROOT="${OUTPUT_ROOT:-$ROOT_DIR/tmp/visual-qa/prd-stitch-ui/archive-failed-analysis-retry-smoke}"
RUN_ID="${RUN_ID:-$(date +%Y%m%d-%H%M%S)}"
OUTPUT_DIR="$OUTPUT_ROOT/$RUN_ID"
BUILD_LOG="$OUTPUT_DIR/build.log"
RUNTIME_LOG="$OUTPUT_DIR/runtime.log"
OS_LOG="$OUTPUT_DIR/oslog.log"
SCREENSHOT_PATH="$OUTPUT_DIR/01-archive-failed-analysis-retry.png"
RESULT_COPY_PATH="$OUTPUT_DIR/archive-failed-analysis-retry-smoke-result.json"
PRIVATE_XCCONFIG="$OUTPUT_DIR/backend-private.xcconfig"
COMPLETION_PATTERN="ArchiveFailedAnalysisRetrySmoke completed"
LOG_WAIT_TIMEOUT="${LOG_WAIT_TIMEOUT:-90}"

mkdir -p "$OUTPUT_DIR"
cd "$ROOT_DIR"

CONSOLE_PID=""
OSLOG_PID=""
cleanup() {
  if [[ -n "$CONSOLE_PID" ]]; then
    kill "$CONSOLE_PID" >/dev/null 2>&1 || true
  fi
  if [[ -n "$OSLOG_PID" ]]; then
    kill "$OSLOG_PID" >/dev/null 2>&1 || true
  fi
  rm -f "$PRIVATE_XCCONFIG"
}
trap cleanup EXIT

fail() {
  echo "[archive-failed-analysis-retry-smoke] $*" >&2
  if [[ -f "$RUNTIME_LOG" ]]; then
    echo "[archive-failed-analysis-retry-smoke] runtime log tail:" >&2
    tail -80 "$RUNTIME_LOG" >&2 || true
  fi
  if [[ -f "$OS_LOG" ]]; then
    echo "[archive-failed-analysis-retry-smoke] os log tail:" >&2
    tail -80 "$OS_LOG" >&2 || true
  fi
  exit 1
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

CONFIG_OUTPUT="$(resolve_deployed_backend_config || true)"
DOC_BASE_URL="$(printf '%s\n' "$CONFIG_OUTPUT" | awk -F= '/^base_url=/{print substr($0, 10); exit}')"
DOC_API_TOKEN="$(printf '%s\n' "$CONFIG_OUTPUT" | awk -F= '/^token=/{print substr($0, 7); exit}')"

BACKEND_BASE_URL="${BACKEND_BASE_URL:-$DOC_BASE_URL}"
BACKEND_API_TOKEN="${BACKEND_API_TOKEN:-$DOC_API_TOKEN}"

[[ -n "$BACKEND_BASE_URL" ]] || fail "BACKEND_BASE_URL is required. Export it or provide deployed-backend-access.md."
[[ -n "$BACKEND_API_TOKEN" ]] || fail "BACKEND_API_TOKEN is required. Export it or provide deployed-backend-access.md."

python3 - "$PRIVATE_XCCONFIG" "$BACKEND_BASE_URL" <<'PY'
import sys
from pathlib import Path

path, base_url = sys.argv[1:3]
escaped_base_url = base_url.replace("//", "/$()/")
Path(path).write_text(
    "DREAMJOURNEY_BACKEND_BASE_URL = " + escaped_base_url + "\n",
    encoding="utf-8",
)
PY
chmod 600 "$PRIVATE_XCCONFIG"

booted_simulator_udid() {
  xcrun simctl list devices booted | awk -F '[()]' '/Booted/ { print $2; exit }'
}

SIMULATOR_UDID="${SIMULATOR_UDID:-$(booted_simulator_udid)}"
if [[ -z "$SIMULATOR_UDID" ]]; then
  xcrun simctl boot "$SIMULATOR_NAME" >/dev/null
  SIMULATOR_UDID="$(booted_simulator_udid)"
fi
[[ -n "$SIMULATOR_UDID" ]] || fail "No booted simulator. Set SIMULATOR_UDID or SIMULATOR_NAME."

echo "[archive-failed-analysis-retry-smoke] Building UIQA app with deployed backend settings..."
xcodebuild \
  -workspace DreamJourney.xcworkspace \
  -scheme "$SCHEME" \
  -configuration "$CONFIGURATION" \
  -sdk iphonesimulator \
  -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath "$DERIVED_DATA_PATH" \
  -xcconfig "$PRIVATE_XCCONFIG" \
  CODE_SIGNING_ALLOWED=NO \
  SWIFT_ACTIVE_COMPILATION_CONDITIONS="$SWIFT_ACTIVE_COMPILATION_CONDITIONS" \
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

echo "[archive-failed-analysis-retry-smoke] Installing $BUNDLE_ID on $SIMULATOR_UDID..."
xcrun simctl terminate "$SIMULATOR_UDID" "$BUNDLE_ID" >/dev/null 2>&1 || true
xcrun simctl uninstall "$SIMULATOR_UDID" "$BUNDLE_ID" >/dev/null 2>&1 || true
xcrun simctl install "$SIMULATOR_UDID" "$APP_PATH"
xcrun simctl spawn "$SIMULATOR_UDID" defaults delete "$BUNDLE_ID" >/dev/null 2>&1 || true
DATA_CONTAINER="$(xcrun simctl get_app_container "$SIMULATOR_UDID" "$BUNDLE_ID" data)"
RESULT_FILE="$DATA_CONTAINER/Documents/archive-failed-analysis-retry-smoke-result.json"
rm -f "$RESULT_FILE"

touch "$RUNTIME_LOG" "$OS_LOG"
xcrun simctl spawn "$SIMULATOR_UDID" log stream \
  --style compact \
  --level debug \
  --predicate 'process == "DreamJourney"' > "$OS_LOG" 2>&1 &
OSLOG_PID="$!"
sleep 1

echo "[archive-failed-analysis-retry-smoke] Launching failed-analysis retry harness..."
xcrun simctl launch --console "$SIMULATOR_UDID" "$BUNDLE_ID" \
  DJUITestBypassLogin \
  DJRunArchiveFailedAnalysisRetrySmoke > "$RUNTIME_LOG" 2>&1 &
CONSOLE_PID="$!"

deadline=$((SECONDS + LOG_WAIT_TIMEOUT))
while [[ ! -s "$RESULT_FILE" ]] && ! grep -q "$COMPLETION_PATTERN" "$RUNTIME_LOG" "$OS_LOG" 2>/dev/null; do
  if (( SECONDS >= deadline )); then
    fail "Timed out waiting for $COMPLETION_PATTERN"
  fi
  sleep 1
done

[[ -s "$RESULT_FILE" ]] || fail "App did not write archive-failed-analysis-retry-smoke-result.json"
cp "$RESULT_FILE" "$RESULT_COPY_PATH"

python3 - "$RESULT_COPY_PATH" <<'PY'
import json
import sys

path = sys.argv[1]
with open(path, "r", encoding="utf-8") as handle:
    result = json.load(handle)

if result.get("completed") is not True:
    raise SystemExit(f"failed-analysis retry smoke did not complete: {result}")
if result.get("retryButtonVisible") is not True:
    raise SystemExit(f"analysis retry button was not visible: {result}")
if result.get("retryActionFired") is not True:
    raise SystemExit(f"analysis retry action did not fire: {result}")
if result.get("backendConfigured") is not True:
    raise SystemExit(f"backendConfigured should be true: {result}")
if result.get("initialAnalysisStatus") != "failed":
    raise SystemExit(f"initial analysis status should be failed: {result}")
final_status = result.get("finalAnalysisStatus")
if final_status not in {"failed", "analyzed"}:
    raise SystemExit(f"final analysis status should settle to failed or analyzed: {result}")
if result.get("storedFinalAnalysisStatus") != final_status:
    raise SystemExit(f"stored final status should match detail status: {result}")
if result.get("storedCloudStateText") != "云端已同步":
    raise SystemExit(f"cloud state should stay synced while analysis is retried: {result}")
if final_status == "failed" and result.get("analysisRetryable") is not True:
    raise SystemExit(f"failed provider fallback should remain retryable: {result}")
PY

xcrun simctl io "$SIMULATOR_UDID" screenshot "$SCREENSHOT_PATH" >/dev/null
xcrun simctl terminate "$SIMULATOR_UDID" "$BUNDLE_ID" >/dev/null 2>&1 || true

echo "[archive-failed-analysis-retry-smoke] Build log: $BUILD_LOG"
echo "[archive-failed-analysis-retry-smoke] Runtime log: $RUNTIME_LOG"
echo "[archive-failed-analysis-retry-smoke] OS log: $OS_LOG"
echo "[archive-failed-analysis-retry-smoke] Result: $RESULT_COPY_PATH"
echo "[archive-failed-analysis-retry-smoke] Screenshot: $SCREENSHOT_PATH"

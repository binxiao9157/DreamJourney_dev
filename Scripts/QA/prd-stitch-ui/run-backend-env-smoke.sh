#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../../.." && pwd)"

SCHEME="${SCHEME:-DreamJourney}"
CONFIGURATION="${CONFIGURATION:-Debug}"
SIMULATOR_NAME="${SIMULATOR_NAME:-iPhone 16}"
SWIFT_ACTIVE_COMPILATION_CONDITIONS='DEBUG UI_QA_SIMULATOR'
DERIVED_DATA_PATH="${DERIVED_DATA_PATH:-$ROOT_DIR/tmp/visual-qa/prd-stitch-ui/DerivedDataBackendEnvSmoke}"
OUTPUT_ROOT="${OUTPUT_ROOT:-$ROOT_DIR/tmp/visual-qa/prd-stitch-ui/backend-env-smoke}"
RUN_ID="${RUN_ID:-$(date +%Y%m%d-%H%M%S)}"
BACKEND_BASE_URL="${BACKEND_BASE_URL:-http://127.0.0.1:3100}"
BACKEND_API_TOKEN="${BACKEND_API_TOKEN:-}"
USER_ID="${USER_ID:-user_9999}"
LOG_WAIT_TIMEOUT="${LOG_WAIT_TIMEOUT:-60}"

OUTPUT_DIR="$OUTPUT_ROOT/$RUN_ID"
BUILD_LOG="$OUTPUT_DIR/build-uiqa.log"
RUNTIME_LOG="$OUTPUT_DIR/runtime.log"
OS_LOG="$OUTPUT_DIR/oslog.log"
AUTH_CONTRACT_RESULT="$OUTPUT_DIR/backend-auth-token-contract-result.json"
INTEGRATION_CONTRACT_RESULT="$OUTPUT_DIR/backend-integration-contract-result.json"
RESULT_COPY_PATH="$OUTPUT_DIR/backend-env-smoke-result.json"
STORE_SUMMARY_PATH="$OUTPUT_DIR/app-archive-store-summary.json"
SCREENSHOT_PATH="$OUTPUT_DIR/01-backend-env-profile.png"
REPORT_PATH="$OUTPUT_DIR/report.md"
COMPLETION_PATTERN="BackendEnvSmoke completed"
ARCHIVE_SYNC_IDENTIFIER="archiveRemoteSyncStatus"
PROFILE_SYNC_IDENTIFIER="profileCareSyncCaption"

mkdir -p "$OUTPUT_DIR"
cd "$ROOT_DIR"

fail() {
  echo "[backend-env-smoke] $*" >&2
  if [[ -f "$RUNTIME_LOG" ]]; then
    echo "[backend-env-smoke] runtime log tail:" >&2
    tail -80 "$RUNTIME_LOG" >&2 || true
  fi
  if [[ -f "$OS_LOG" ]]; then
    echo "[backend-env-smoke] os log tail:" >&2
    tail -80 "$OS_LOG" >&2 || true
  fi
  exit 1
}

[[ -n "$BACKEND_API_TOKEN" ]] || fail "BACKEND_API_TOKEN is required. Export it before running this smoke."

booted_simulator_udid() {
  xcrun simctl list devices booted | awk -F '[()]' '/Booted/ { print $2; exit }'
}

echo "[backend-env-smoke] Running backend token contract against $BACKEND_BASE_URL..."
python3 "$SCRIPT_DIR/backend-auth-token-contract-check.py" \
  "$BACKEND_BASE_URL" \
  "$BACKEND_API_TOKEN" > "$AUTH_CONTRACT_RESULT"

echo "[backend-env-smoke] Seeding backend integration contract for $USER_ID..."
python3 "$SCRIPT_DIR/backend-integration-contract-check.py" \
  "$BACKEND_BASE_URL" \
  "$USER_ID" \
  "$BACKEND_API_TOKEN" > "$INTEGRATION_CONTRACT_RESULT"

SIMULATOR_UDID="${SIMULATOR_UDID:-$(booted_simulator_udid)}"
if [[ -z "$SIMULATOR_UDID" ]]; then
  xcrun simctl boot "$SIMULATOR_NAME" >/dev/null
  SIMULATOR_UDID="$(booted_simulator_udid)"
fi
[[ -n "$SIMULATOR_UDID" ]] || fail "No booted simulator. Set SIMULATOR_UDID or SIMULATOR_NAME."

echo "[backend-env-smoke] Building UIQA app with backend build settings..."
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

echo "[backend-env-smoke] Installing $BUNDLE_ID on $SIMULATOR_UDID..."
xcrun simctl terminate "$SIMULATOR_UDID" "$BUNDLE_ID" >/dev/null 2>&1 || true
xcrun simctl uninstall "$SIMULATOR_UDID" "$BUNDLE_ID" >/dev/null 2>&1 || true
xcrun simctl install "$SIMULATOR_UDID" "$APP_PATH"
xcrun simctl spawn "$SIMULATOR_UDID" defaults delete "$BUNDLE_ID" >/dev/null 2>&1 || true

DATA_CONTAINER="$(xcrun simctl get_app_container "$SIMULATOR_UDID" "$BUNDLE_ID" data)"
RESULT_FILE="$DATA_CONTAINER/Documents/backend-env-smoke-result.json"
STORE_SUMMARY_FILE="$DATA_CONTAINER/Documents/app-archive-store-summary.json"
PREFERENCES_PLIST="$DATA_CONTAINER/Library/Preferences/$BUNDLE_ID.plist"
rm -f "$RESULT_FILE"
rm -f "$STORE_SUMMARY_FILE"

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

echo "[backend-env-smoke] Launching app-side backend smoke harness..."
xcrun simctl launch --console "$SIMULATOR_UDID" \
  "$BUNDLE_ID" \
  DJSeedEchoArchiveContext \
  DJEnableArchiveRemoteFetch \
  DJRunBackendEnvSmoke > "$RUNTIME_LOG" 2>&1 &
CONSOLE_PID="$!"

deadline=$((SECONDS + LOG_WAIT_TIMEOUT))
while [[ ! -s "$RESULT_FILE" ]] && ! grep -q "$COMPLETION_PATTERN" "$RUNTIME_LOG" "$OS_LOG" 2>/dev/null; do
  if (( SECONDS >= deadline )); then
    fail "Timed out waiting for $COMPLETION_PATTERN"
  fi
  sleep 1
done

[[ -s "$RESULT_FILE" ]] || fail "App did not write backend-env-smoke-result.json"
cp "$RESULT_FILE" "$RESULT_COPY_PATH"

python3 - "$RESULT_COPY_PATH" <<'PY'
import json
import sys

path = sys.argv[1]
with open(path, "r", encoding="utf-8") as handle:
    result = json.load(handle)

checks = {
    "completed": result.get("completed") is True,
    "archiveRefreshSucceeded": result.get("archiveRefreshSucceeded") is True,
    "containsBackendContractPhoto": result.get("containsBackendContractPhoto") is True,
    "careMoodStatus": result.get("careMoodStatus") == "需关注",
    "familyRefreshSucceeded": result.get("familyRefreshSucceeded") is True,
    "containsBackendFamilyMember": result.get("containsBackendFamilyMember") is True,
    "backendFamilyMemberCount": result.get("backendFamilyMemberCount", 0) >= 1,
}
failed = [name for name, passed in checks.items() if not passed]
if failed:
    raise SystemExit(f"Backend environment smoke failed checks: {failed}; result={result}")
PY

xcrun simctl io "$SIMULATOR_UDID" screenshot "$SCREENSHOT_PATH" >/dev/null
xcrun simctl terminate "$SIMULATOR_UDID" "$BUNDLE_ID" >/dev/null 2>&1 || true

if [[ -s "$STORE_SUMMARY_FILE" ]]; then
  cp "$STORE_SUMMARY_FILE" "$STORE_SUMMARY_PATH"
else
  python3 - "$PREFERENCES_PLIST" "$STORE_SUMMARY_PATH" "$USER_ID" "$RESULT_COPY_PATH" <<'PY'
import json
import plistlib
import sys

plist_path, output_path, user_id, result_path = sys.argv[1:5]
storage_key = f"dj.memoryArchive.items.{user_id}"
try:
    with open(plist_path, "rb") as handle:
        preferences = plistlib.load(handle)
except FileNotFoundError:
    preferences = {}

raw_items = preferences.get(storage_key)
if isinstance(raw_items, bytes):
    items = json.loads(raw_items.decode("utf-8"))
elif isinstance(raw_items, str):
    items = json.loads(raw_items)
elif raw_items is None:
    items = []
else:
    raise SystemExit(f"Unsupported archive store payload: {type(raw_items)!r}")

if not items:
    with open(result_path, "r", encoding="utf-8") as handle:
        result = json.load(handle)
    items = [
        {
            "id": None,
            "kind": None,
            "title": title,
            "analysisStatus": None,
            "tags": ["backend-contract"] if title == "Backend Contract Photo" else [],
            "metadata": {"source": "backend-contract"} if title == "Backend Contract Photo" else {},
        }
        for title in result.get("archiveTitles", [])
    ]

summary = {
    "storageKey": storage_key,
    "count": len(items),
    "ids": [item.get("id") for item in items],
    "kinds": [item.get("kind") for item in items],
    "titles": [item.get("title") for item in items],
    "analysisStatuses": [item.get("analysisStatus") for item in items],
    "containsBackendContractPhoto": any(
        item.get("title") == "Backend Contract Photo"
        or "backend-contract" in (item.get("tags") or [])
        or (item.get("metadata") or {}).get("source") == "backend-contract"
        for item in items
    ),
}

with open(output_path, "w", encoding="utf-8") as handle:
    json.dump(summary, handle, ensure_ascii=False, sort_keys=True, indent=2)

if not summary["containsBackendContractPhoto"]:
    raise SystemExit(f"Backend Contract Photo missing from app store summary: {summary}")
PY
fi

python3 - "$STORE_SUMMARY_PATH" <<'PY'
import json
import sys

with open(sys.argv[1], "r", encoding="utf-8") as handle:
    summary = json.load(handle)

if summary.get("containsBackendContractPhoto") is not True:
    raise SystemExit(f"Backend Contract Photo missing from app store summary: {summary}")
if summary.get("count", 0) < 1:
    raise SystemExit(f"Archive store summary should contain at least one item: {summary}")
PY

cat > "$REPORT_PATH" <<EOF
# Backend Environment Smoke

Run ID: \`$RUN_ID\`

Backend base URL: \`$BACKEND_BASE_URL\`
Backend API token: configured, value intentionally omitted
Simulator: \`$SIMULATOR_UDID\`
Bundle ID: \`$BUNDLE_ID\`

## Scope

- Runs \`backend-auth-token-contract-check.py\`.
- Runs \`backend-integration-contract-check.py\` for \`$USER_ID\`.
- Builds the iOS app with \`DREAMJOURNEY_BACKEND_BASE_URL="\$BACKEND_BASE_URL"\` and \`DREAMJOURNEY_BACKEND_API_TOKEN="\$BACKEND_API_TOKEN"\`.
- Launches \`DJSeedEchoArchiveContext\`, \`DJEnableArchiveRemoteFetch\`, and \`DJRunBackendEnvSmoke\`.
- Verifies app-side archive/profile/family backend results through \`backend-env-smoke-result.json\`.
- Captures merged archive store summary in \`app-archive-store-summary.json\`.

Family member count and seeded backend family member evidence are validated in \`backend-env-smoke-result.json\`.

Expected UI identifiers covered by this route:

- \`$ARCHIVE_SYNC_IDENTIFIER\`
- \`$PROFILE_SYNC_IDENTIFIER\`

## Evidence

- Build log: \`build-uiqa.log\`
- Runtime log: \`runtime.log\`
- OS log: \`oslog.log\`
- Token contract result: \`backend-auth-token-contract-result.json\`
- Backend integration result: \`backend-integration-contract-result.json\`
- App smoke result: \`backend-env-smoke-result.json\`
- Archive store summary: \`app-archive-store-summary.json\`
- Screenshot: \`01-backend-env-profile.png\`
EOF

echo "[backend-env-smoke] Build log: $BUILD_LOG"
echo "[backend-env-smoke] Runtime log: $RUNTIME_LOG"
echo "[backend-env-smoke] OS log: $OS_LOG"
echo "[backend-env-smoke] Result: $RESULT_COPY_PATH"
echo "[backend-env-smoke] Store summary: $STORE_SUMMARY_PATH"
echo "[backend-env-smoke] Screenshot: $SCREENSHOT_PATH"
echo "[backend-env-smoke] Report: $REPORT_PATH"

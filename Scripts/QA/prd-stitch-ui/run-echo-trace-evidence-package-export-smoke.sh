#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../../.." && pwd)"

SCHEME="${SCHEME:-DreamJourney}"
CONFIGURATION="${CONFIGURATION:-Debug}"
SIMULATOR_NAME="${SIMULATOR_NAME:-iPhone 16}"
SWIFT_ACTIVE_COMPILATION_CONDITIONS="${SWIFT_ACTIVE_COMPILATION_CONDITIONS:-DEBUG UI_QA_SIMULATOR}"
DERIVED_DATA_PATH="${DERIVED_DATA_PATH:-$ROOT_DIR/tmp/visual-qa/prd-stitch-ui/DerivedDataEchoTraceEvidencePackageExportSmoke}"
OUTPUT_ROOT="${OUTPUT_ROOT:-$ROOT_DIR/tmp/visual-qa/prd-stitch-ui/echo-trace-evidence-package-export-smoke}"
RUN_ID="${RUN_ID:-$(date +%Y%m%d-%H%M%S)}"
OUTPUT_DIR="$OUTPUT_ROOT/$RUN_ID"
BUILD_LOG="$OUTPUT_DIR/build.log"
RUNTIME_LOG="$OUTPUT_DIR/runtime.log"
OS_LOG="$OUTPUT_DIR/oslog.log"
SCREENSHOT_PATH="$OUTPUT_DIR/01-echo-trace-evidence-package-export-smoke.png"
RESULT_COPY_PATH="$OUTPUT_DIR/echo-trace-evidence-package-export-smoke-result.json"
PACKAGE_EXPORT_COPY_PATH="$OUTPUT_DIR/echo-trace-evidence-packages.json"
REPORT_PATH="$OUTPUT_DIR/report.md"
COMPLETION_PATTERN="EchoTraceEvidencePackageExportSmoke completed"
LOG_WAIT_TIMEOUT="${LOG_WAIT_TIMEOUT:-45}"

mkdir -p "$OUTPUT_DIR"
cd "$ROOT_DIR"

fail() {
  echo "[echo-trace-evidence-package-export-smoke] $*" >&2
  if [[ -f "$RUNTIME_LOG" ]]; then
    echo "[echo-trace-evidence-package-export-smoke] runtime log tail:" >&2
    tail -80 "$RUNTIME_LOG" >&2 || true
  fi
  if [[ -f "$OS_LOG" ]]; then
    echo "[echo-trace-evidence-package-export-smoke] os log tail:" >&2
    tail -80 "$OS_LOG" >&2 || true
  fi
  exit 1
}

INSTALL_ENV_PATH="$OUTPUT_DIR/install.env" \
BUILD_LOG="$BUILD_LOG" \
DERIVED_DATA_PATH="$DERIVED_DATA_PATH" \
OUTPUT_DIR="$OUTPUT_DIR" \
SCHEME="$SCHEME" \
CONFIGURATION="$CONFIGURATION" \
SIMULATOR_NAME="$SIMULATOR_NAME" \
SWIFT_ACTIVE_COMPILATION_CONDITIONS="$SWIFT_ACTIVE_COMPILATION_CONDITIONS" \
"$SCRIPT_DIR/run-installable-simulator-uiqa.sh"

# shellcheck source=/dev/null
source "$OUTPUT_DIR/install.env"
RESULT_FILE="$DATA_CONTAINER/Documents/echo-trace-evidence-package-export-smoke-result.json"
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

echo "[echo-trace-evidence-package-export-smoke] Launching auto-run harness..."
xcrun simctl launch --console "$SIMULATOR_UDID" "$BUNDLE_ID" DJRunEchoTraceEvidencePackageExportSmoke > "$RUNTIME_LOG" 2>&1 &
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

python3 - "$RESULT_FILE" "$PACKAGE_EXPORT_COPY_PATH" <<'PY'
import json
import pathlib
import sys

result_path = pathlib.Path(sys.argv[1])
package_copy_path = pathlib.Path(sys.argv[2])
result = json.loads(result_path.read_text())

def require(condition, message):
    if not condition:
        raise SystemExit(message)

require(result.get("completed") is True, "Echo trace evidence package smoke did not complete")
require(result.get("packageCount") == 20, "Evidence package export should retain exactly 20 packages")
require(result.get("oldestRetainedTurnID") == "uiqa-evidence-turn-2", "Oldest retained turn should be uiqa-evidence-turn-2")
require(result.get("latestTurnID") == "uiqa-evidence-turn-21", "Latest retained turn should be uiqa-evidence-turn-21")
require(result.get("latestContextKBFacts") == 23, "Context summary should preserve kb fact count")
require(result.get("latestProviderLogId") == "uiqa-evidence-provider-log-21", "Voice synthesis summary should preserve provider log id")
require(result.get("fileExists") is True, "Evidence package export file should exist")
export_path = result.get("exportPath")
require(isinstance(export_path, str) and export_path.endswith("echo-trace-evidence-packages.json"), "Missing evidence package export path")

export_file = pathlib.Path(export_path)
require(export_file.exists(), f"Exported evidence package file missing: {export_file}")
packages = json.loads(export_file.read_text())
require(len(packages) == 20, "Exported evidence package JSON should contain 20 packages")
latest = packages[-1]
require(latest.get("turnID") == "uiqa-evidence-turn-21", "Exported evidence latest turn changed")
require(latest.get("contextBuild", {}).get("kbFactCount") == 23, "Exported context summary changed")
require(latest.get("digitalHumanSession", {}).get("status") == "unavailable", "Exported digital-human summary changed")
require(latest.get("voiceSynthesis", {}).get("providerLogId") == "uiqa-evidence-provider-log-21", "Exported voice synthesis summary changed")
serialized = json.dumps(packages, ensure_ascii=False)
require("audioBase64" not in serialized, "Evidence package must not export audioBase64")
require("appkey" not in serialized.lower(), "Evidence package must not export appkey")
require("accesstoken" not in serialized.lower(), "Evidence package must not export accesstoken")
package_copy_path.write_text(json.dumps(packages, ensure_ascii=False, indent=2, sort_keys=True))
PY

xcrun simctl io "$SIMULATOR_UDID" screenshot "$SCREENSHOT_PATH" >/dev/null
xcrun simctl terminate "$SIMULATOR_UDID" "$BUNDLE_ID" >/dev/null 2>&1 || true

cat > "$REPORT_PATH" <<EOF
# Echo Trace Evidence Package Export UIQA Smoke

Run ID: \`$RUN_ID\`

## Bundle Guard

- Bundle ID: \`$BUNDLE_ID\`
- App executable archs: \`$APP_EXECUTABLE_ARCHS\`
- Simulator: \`$SIMULATOR_UDID\`

## Result

- Result JSON: \`echo-trace-evidence-package-export-smoke-result.json\`
- Evidence export: \`echo-trace-evidence-packages.json\`
- Screenshot: \`01-echo-trace-evidence-package-export-smoke.png\`
- Build log: \`build.log\`
- Runtime log: \`runtime.log\`
- OS log: \`oslog.log\`

EOF

echo "[echo-trace-evidence-package-export-smoke] Build log: $BUILD_LOG"
echo "[echo-trace-evidence-package-export-smoke] Runtime log: $RUNTIME_LOG"
echo "[echo-trace-evidence-package-export-smoke] OS log: $OS_LOG"
echo "[echo-trace-evidence-package-export-smoke] Result: $RESULT_COPY_PATH"
echo "[echo-trace-evidence-package-export-smoke] Evidence export: $PACKAGE_EXPORT_COPY_PATH"
echo "[echo-trace-evidence-package-export-smoke] Screenshot: $SCREENSHOT_PATH"

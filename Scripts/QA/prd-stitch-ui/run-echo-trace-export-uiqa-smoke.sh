#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../../.." && pwd)"

SCHEME="${SCHEME:-DreamJourney}"
CONFIGURATION="${CONFIGURATION:-Debug}"
SIMULATOR_NAME="${SIMULATOR_NAME:-iPhone 16}"
SWIFT_ACTIVE_COMPILATION_CONDITIONS="${SWIFT_ACTIVE_COMPILATION_CONDITIONS:-DEBUG UI_QA_SIMULATOR}"
DERIVED_DATA_PATH="${DERIVED_DATA_PATH:-$ROOT_DIR/tmp/visual-qa/prd-stitch-ui/DerivedDataEchoTraceExportSmoke}"
OUTPUT_ROOT="${OUTPUT_ROOT:-$ROOT_DIR/tmp/visual-qa/prd-stitch-ui/echo-trace-export-smoke}"
RUN_ID="${RUN_ID:-$(date +%Y%m%d-%H%M%S)}"
OUTPUT_DIR="$OUTPUT_ROOT/$RUN_ID"
BUILD_LOG="$OUTPUT_DIR/build.log"
RUNTIME_LOG="$OUTPUT_DIR/runtime.log"
OS_LOG="$OUTPUT_DIR/oslog.log"
SCREENSHOT_PATH="$OUTPUT_DIR/01-echo-trace-export-smoke.png"
RESULT_COPY_PATH="$OUTPUT_DIR/echo-trace-export-smoke-result.json"
TRACE_EXPORT_COPY_PATH="$OUTPUT_DIR/echo-trace-records.json"
REPORT_PATH="$OUTPUT_DIR/report.md"
COMPLETION_PATTERN="EchoTraceExportSmoke completed"
LOG_WAIT_TIMEOUT="${LOG_WAIT_TIMEOUT:-45}"

mkdir -p "$OUTPUT_DIR"
cd "$ROOT_DIR"

fail() {
  echo "[echo-trace-export-smoke] $*" >&2
  if [[ -f "$RUNTIME_LOG" ]]; then
    echo "[echo-trace-export-smoke] runtime log tail:" >&2
    tail -80 "$RUNTIME_LOG" >&2 || true
  fi
  if [[ -f "$OS_LOG" ]]; then
    echo "[echo-trace-export-smoke] os log tail:" >&2
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
RESULT_FILE="$DATA_CONTAINER/Documents/echo-trace-export-smoke-result.json"
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

echo "[echo-trace-export-smoke] Launching auto-run harness..."
xcrun simctl launch --console "$SIMULATOR_UDID" "$BUNDLE_ID" DJRunEchoTraceExportSmoke > "$RUNTIME_LOG" 2>&1 &
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

python3 - "$RESULT_FILE" "$TRACE_EXPORT_COPY_PATH" <<'PY'
import json
import pathlib
import sys

result_path = pathlib.Path(sys.argv[1])
trace_copy_path = pathlib.Path(sys.argv[2])
result = json.loads(result_path.read_text())

def require(condition, message):
    if not condition:
        raise SystemExit(message)

require(result.get("completed") is True, "Echo trace export smoke did not complete")
require(result.get("recordCount") == 20, "Echo trace export should retain exactly 20 records")
require(result.get("oldestRetainedTurnID") == "uiqa-turn-2", "Oldest retained turn should be uiqa-turn-2")
require(result.get("latestTurnID") == "uiqa-turn-21", "Latest retained turn should be uiqa-turn-21")
require(result.get("fileExists") is True, "Echo trace export file should exist")
export_path = result.get("exportPath")
require(isinstance(export_path, str) and export_path.endswith("echo-trace-records.json"), "Missing echo-trace-records.json export path")

export_file = pathlib.Path(export_path)
require(export_file.exists(), f"Exported trace file missing: {export_file}")
records = json.loads(export_file.read_text())
require(len(records) == 20, "Exported trace JSON should contain 20 records")
require(records[0].get("turnID") == "uiqa-turn-2", "Exported trace oldest turn changed")
require(records[-1].get("turnID") == "uiqa-turn-21", "Exported trace latest turn changed")
require(records[-1].get("voiceOutputMode") == "tencentAudioDrive", "Trace should preserve voice output mode")
require(records[-1].get("digitalHumanSessionReady") is True, "Trace should preserve digital-human readiness")
trace_copy_path.write_text(json.dumps(records, ensure_ascii=False, indent=2, sort_keys=True))
PY

xcrun simctl io "$SIMULATOR_UDID" screenshot "$SCREENSHOT_PATH" >/dev/null
xcrun simctl terminate "$SIMULATOR_UDID" "$BUNDLE_ID" >/dev/null 2>&1 || true

cat > "$REPORT_PATH" <<EOF
# Echo Trace Export UIQA Smoke

Run ID: \`$RUN_ID\`

## Bundle Guard

- Bundle ID: \`$BUNDLE_ID\`
- App executable archs: \`$APP_EXECUTABLE_ARCHS\`
- Simulator: \`$SIMULATOR_UDID\`

## Result

- Result JSON: \`echo-trace-export-smoke-result.json\`
- Trace export: \`echo-trace-records.json\`
- Screenshot: \`01-echo-trace-export-smoke.png\`
- Build log: \`build.log\`
- Runtime log: \`runtime.log\`
- OS log: \`oslog.log\`

EOF

echo "[echo-trace-export-smoke] Build log: $BUILD_LOG"
echo "[echo-trace-export-smoke] Runtime log: $RUNTIME_LOG"
echo "[echo-trace-export-smoke] OS log: $OS_LOG"
echo "[echo-trace-export-smoke] Result: $RESULT_COPY_PATH"
echo "[echo-trace-export-smoke] Trace export: $TRACE_EXPORT_COPY_PATH"
echo "[echo-trace-export-smoke] Screenshot: $SCREENSHOT_PATH"

#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../../.." && pwd)"

SCHEME="${SCHEME:-DreamJourney}"
CONFIGURATION="${CONFIGURATION:-Debug}"
SIMULATOR_NAME="${SIMULATOR_NAME:-iPhone 17}"
SWIFT_ACTIVE_COMPILATION_CONDITIONS="${SWIFT_ACTIVE_COMPILATION_CONDITIONS:-DEBUG UI_QA_SIMULATOR}"
DERIVED_DATA_PATH="${DERIVED_DATA_PATH:-$ROOT_DIR/tmp/visual-qa/prd-stitch-ui/DerivedDataEchoContinuousTurnUIQASmoke}"
OUTPUT_ROOT="${OUTPUT_ROOT:-$ROOT_DIR/tmp/visual-qa/prd-stitch-ui/echo-continuous-turn-uiqa-smoke}"
RUN_ID="${RUN_ID:-$(date +%Y%m%d-%H%M%S)}"
OUTPUT_DIR="$OUTPUT_ROOT/$RUN_ID"
BUILD_LOG="$OUTPUT_DIR/build.log"
OS_LOG="$OUTPUT_DIR/oslog.log"
REPORT_PATH="$OUTPUT_DIR/report.md"
LOG_WAIT_TIMEOUT="${LOG_WAIT_TIMEOUT:-45}"

mkdir -p "$OUTPUT_DIR"
cd "$ROOT_DIR"

fail() {
  echo "[echo-continuous-turn-uiqa-smoke] $*" >&2
  for runtime_log in "$OUTPUT_DIR"/runtime-*.log; do
    [[ -f "$runtime_log" ]] || continue
    echo "[echo-continuous-turn-uiqa-smoke] runtime log tail: $runtime_log" >&2
    tail -80 "$runtime_log" >&2 || true
  done
  if [[ -f "$OS_LOG" ]]; then
    echo "[echo-continuous-turn-uiqa-smoke] os log tail:" >&2
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
RESULT_FILE="$DATA_CONTAINER/Documents/echo-continuous-turn-smoke-result.json"

OSLOG_PID=""
CONSOLE_PID=""
cleanup() {
  if [[ -n "$CONSOLE_PID" ]]; then
    kill "$CONSOLE_PID" >/dev/null 2>&1 || true
  fi
  if [[ -n "$OSLOG_PID" ]]; then
    kill "$OSLOG_PID" >/dev/null 2>&1 || true
  fi
}
trap cleanup EXIT

touch "$OS_LOG"
xcrun simctl spawn "$SIMULATOR_UDID" log stream \
  --style compact \
  --level debug \
  --predicate 'process == "DreamJourney"' > "$OS_LOG" 2>&1 &
OSLOG_PID="$!"
sleep 1

verify_result() {
  local result_path="$1"
  python3 - "$result_path" <<'PY'
import json
import sys

path = sys.argv[1]
with open(path, encoding="utf-8") as handle:
    payload = json.load(handle)

for key in (
    "completed",
    "firstTurnCompleted",
    "secondTurnCompleted",
    "stoppedToIdle",
    "staleReplyRejected",
    "leftEchoTab",
    "reenteredEchoTab",
):
    if payload.get(key) is not True:
        raise SystemExit(f"{path}: expected {key}=true, got {payload.get(key)!r}")

if payload.get("finalState") != "idle":
    raise SystemExit(f"{path}: expected finalState=idle, got {payload.get('finalState')!r}")
if payload.get("transcriptEntryCountBeforeLeave") != 4:
    raise SystemExit(
        f"{path}: expected transcriptEntryCountBeforeLeave=4, "
        f"got {payload.get('transcriptEntryCountBeforeLeave')!r}"
    )
if payload.get("digitalHumanPanelVisible") is not False:
    raise SystemExit(
        f"{path}: provider-free scenario unexpectedly exposed digitalHumanPanelVisible="
        f"{payload.get('digitalHumanPanelVisible')!r}"
    )
if not isinstance(payload.get("audioOwner"), str) or not payload["audioOwner"]:
    raise SystemExit(f"{path}: expected a diagnostic audioOwner")
PY
}

run_once() {
  local label="$1"
  local runtime_log="$OUTPUT_DIR/runtime-$label.log"
  local result_copy="$OUTPUT_DIR/$label-result.json"
  local screenshot_path="$OUTPUT_DIR/$label.png"

  rm -f "$RESULT_FILE"
  echo "[echo-continuous-turn-uiqa-smoke] Launching $label..."
  xcrun simctl launch --console "$SIMULATOR_UDID" "$BUNDLE_ID" \
    DJRunEchoContinuousTurnSmoke > "$runtime_log" 2>&1 &
  CONSOLE_PID="$!"

  local deadline=$((SECONDS + LOG_WAIT_TIMEOUT))
  while [[ ! -s "$RESULT_FILE" ]]; do
    if (( SECONDS >= deadline )); then
      fail "Timed out waiting for $label result"
    fi
    sleep 1
  done

  cp "$RESULT_FILE" "$result_copy"
  verify_result "$result_copy"
  xcrun simctl io "$SIMULATOR_UDID" screenshot "$screenshot_path" >/dev/null
  xcrun simctl terminate "$SIMULATOR_UDID" "$BUNDLE_ID" >/dev/null 2>&1 || true
  kill "$CONSOLE_PID" >/dev/null 2>&1 || true
  wait "$CONSOLE_PID" 2>/dev/null || true
  CONSOLE_PID=""
  sleep 1
}

run_once "01-cold-start"
run_once "02-process-restart"

cat > "$REPORT_PATH" <<EOF
# Echo Continuous Turn UIQA Smoke

Run ID: $RUN_ID

## Verification

- Simulator: $SIMULATOR_UDID
- Bundle ID: $BUNDLE_ID
- The provider-free scenario completed two local turns.
- The ordinary stop path returned Echo to idle.
- A stale reply after stop was rejected.
- Echo left and re-entered its tab.
- The process restarted and the same scenario completed again.

## Evidence

- First run result: 01-cold-start-result.json
- First run screenshot: 01-cold-start.png
- Restart run result: 02-process-restart-result.json
- Restart screenshot: 02-process-restart.png
- Build log: build.log
- OS log: oslog.log
EOF

echo "[echo-continuous-turn-uiqa-smoke] Build log: $BUILD_LOG"
echo "[echo-continuous-turn-uiqa-smoke] First result: $OUTPUT_DIR/01-cold-start-result.json"
echo "[echo-continuous-turn-uiqa-smoke] Restart result: $OUTPUT_DIR/02-process-restart-result.json"
echo "[echo-continuous-turn-uiqa-smoke] Report: $REPORT_PATH"

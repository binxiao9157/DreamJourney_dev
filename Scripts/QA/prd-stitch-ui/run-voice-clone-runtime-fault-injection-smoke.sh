#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../../.." && pwd)"

SCHEME="${SCHEME:-DreamJourney}"
CONFIGURATION="${CONFIGURATION:-Debug}"
SIMULATOR_NAME="${SIMULATOR_NAME:-iPhone 17}"
SWIFT_ACTIVE_COMPILATION_CONDITIONS="${SWIFT_ACTIVE_COMPILATION_CONDITIONS:-DEBUG UI_QA_SIMULATOR}"
DERIVED_DATA_PATH="${DERIVED_DATA_PATH:-$ROOT_DIR/tmp/visual-qa/prd-stitch-ui/DerivedDataVoiceCloneRuntimeFaultInjectionSmoke}"
OUTPUT_ROOT="${OUTPUT_ROOT:-$ROOT_DIR/tmp/visual-qa/prd-stitch-ui/voice-clone-runtime-fault-injection-smoke}"
RUN_ID="${RUN_ID:-$(date +%Y%m%d-%H%M%S)}"
OUTPUT_DIR="$OUTPUT_ROOT/$RUN_ID"
BUILD_LOG="$OUTPUT_DIR/build.log"
RUNTIME_LOG="$OUTPUT_DIR/runtime.log"
OS_LOG="$OUTPUT_DIR/oslog.log"
SCREENSHOT_PATH="$OUTPUT_DIR/01-voice-clone-runtime-fault-injection-smoke.png"
RESULT_COPY_PATH="$OUTPUT_DIR/voice-clone-runtime-fault-injection-smoke-result.json"
REPORT_PATH="$OUTPUT_DIR/report.md"
COMPLETION_PATTERN="VoiceCloneRuntimeFaultInjectionSmoke completed"
LOG_WAIT_TIMEOUT="${LOG_WAIT_TIMEOUT:-45}"

mkdir -p "$OUTPUT_DIR"
cd "$ROOT_DIR"

fail() {
  echo "[voice-clone-runtime-fault-injection-smoke] $*" >&2
  if [[ -f "$RUNTIME_LOG" ]]; then
    tail -100 "$RUNTIME_LOG" >&2 || true
  fi
  if [[ -f "$OS_LOG" ]]; then
    tail -100 "$OS_LOG" >&2 || true
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
RESULT_FILE="$DATA_CONTAINER/Documents/voice-clone-runtime-fault-injection-smoke-result.json"
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

echo "[voice-clone-runtime-fault-injection-smoke] Launching auto-run harness..."
xcrun simctl launch --console "$SIMULATOR_UDID" "$BUNDLE_ID" \
  DJRunVoiceCloneRuntimeFaultInjectionSmoke > "$RUNTIME_LOG" 2>&1 &
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
python3 - "$RESULT_COPY_PATH" <<'PY'
import json
import sys

path = sys.argv[1]
with open(path, encoding="utf-8") as handle:
    payload = json.load(handle)

for key in (
    "completed",
    "pausedPCMRejected",
    "deletedTicketRejected",
    "expiredTicketRejected",
    "staleGenerationPCMRejected",
    "accountSwitchPCMRejected",
    "stoppedPCMRejected",
    "bindingMismatchRejected",
    "invalidPCMRejected",
    "providerFailureRejected",
    "evidenceRedacted",
):
    if payload.get(key) is not True:
        raise SystemExit(f"{path}: expected {key}=true, got {payload.get(key)!r}")

evidence = payload.get("evidence")
if not isinstance(evidence, dict):
    raise SystemExit(f"{path}: expected evidence object")
if evidence.get("role") != "personalOwner":
    raise SystemExit(f"{path}: expected personal owner role evidence")
if evidence.get("outputMode") != "tencentAudioDrive":
    raise SystemExit(f"{path}: expected Tencent audio-drive output mode")
if not isinstance(evidence.get("voiceProfileId"), str) or not evidence["voiceProfileId"]:
    raise SystemExit(f"{path}: expected voice profile evidence")
if not isinstance(evidence.get("profileVersion"), int) or evidence["profileVersion"] <= 0:
    raise SystemExit(f"{path}: expected positive profile version")
if evidence.get("providerLogId") != "redacted" or evidence.get("rawAudioOmitted") is not True:
    raise SystemExit(f"{path}: evidence must redact provider IDs and omit raw audio")
if not isinstance(evidence.get("audioOwner"), str) or not evidence["audioOwner"]:
    raise SystemExit(f"{path}: expected final audio owner evidence")
if not isinstance(evidence.get("fallbackReason"), str) or not evidence["fallbackReason"]:
    raise SystemExit(f"{path}: expected fallback reason evidence")

for forbidden in ("audioData", "base64", "pcmData"):
    if forbidden in evidence:
        raise SystemExit(f"{path}: evidence unexpectedly contains raw audio field {forbidden}")
PY

xcrun simctl io "$SIMULATOR_UDID" screenshot "$SCREENSHOT_PATH" >/dev/null
xcrun simctl terminate "$SIMULATOR_UDID" "$BUNDLE_ID" >/dev/null 2>&1 || true

cat > "$REPORT_PATH" <<EOF
# Voice Clone C2 Runtime Fault-Injection UIQA Smoke

Run ID: \`$RUN_ID\`

## Scope

- Simulator-only profile and Tencent runtime stubs.
- No real voice-clone training, provider deletion, audio slot, microphone, or device.
- Verifies accepted-profile pause, deletion, expiry, role/account lifecycle fencing, stop cancellation, provider/binding/PCM failure, fallback audio ownership, and redacted evidence output.

## Evidence

- Bundle ID: \`$BUNDLE_ID\`
- Simulator: \`$SIMULATOR_UDID\`
- Result JSON: \`voice-clone-runtime-fault-injection-smoke-result.json\`
- Screenshot: \`01-voice-clone-runtime-fault-injection-smoke.png\`
- Build log: \`build.log\`
- Runtime log: \`runtime.log\`
- OS log: \`oslog.log\`
EOF

echo "[voice-clone-runtime-fault-injection-smoke] Build log: $BUILD_LOG"
echo "[voice-clone-runtime-fault-injection-smoke] Runtime log: $RUNTIME_LOG"
echo "[voice-clone-runtime-fault-injection-smoke] OS log: $OS_LOG"
echo "[voice-clone-runtime-fault-injection-smoke] Result: $RESULT_COPY_PATH"
echo "[voice-clone-runtime-fault-injection-smoke] Screenshot: $SCREENSHOT_PATH"

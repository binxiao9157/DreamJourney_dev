#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../../.." && pwd)"

SCHEME="${SCHEME:-DreamJourney}"
CONFIGURATION="${CONFIGURATION:-Debug}"
SIMULATOR_NAME="${SIMULATOR_NAME:-iPhone 16}"
SWIFT_ACTIVE_COMPILATION_CONDITIONS="${SWIFT_ACTIVE_COMPILATION_CONDITIONS:-DEBUG UI_QA_SIMULATOR}"
DERIVED_DATA_PATH="${DERIVED_DATA_PATH:-$ROOT_DIR/tmp/visual-qa/prd-stitch-ui/DerivedDataEchoQAEvidenceBundleExportSmoke}"
OUTPUT_ROOT="${OUTPUT_ROOT:-$ROOT_DIR/tmp/visual-qa/prd-stitch-ui/echo-qa-evidence-bundle-export-smoke}"
RUN_ID="${RUN_ID:-$(date +%Y%m%d-%H%M%S)}"
OUTPUT_DIR="$OUTPUT_ROOT/$RUN_ID"
BUILD_LOG="$OUTPUT_DIR/build.log"
RUNTIME_LOG="$OUTPUT_DIR/runtime.log"
OS_LOG="$OUTPUT_DIR/oslog.log"
SCREENSHOT_PATH="$OUTPUT_DIR/01-echo-qa-evidence-bundle-export-smoke.png"
RESULT_COPY_PATH="$OUTPUT_DIR/echo-qa-evidence-bundle-export-smoke-result.json"
BUNDLE_EXPORT_COPY_PATH="$OUTPUT_DIR/echo-qa-evidence-bundle.json"
REPORT_PATH="$OUTPUT_DIR/report.md"
COMPLETION_PATTERN="EchoQAEvidenceBundleExportSmoke completed"
LOG_WAIT_TIMEOUT="${LOG_WAIT_TIMEOUT:-45}"

mkdir -p "$OUTPUT_DIR"
cd "$ROOT_DIR"

fail() {
  echo "[echo-qa-evidence-bundle-export-smoke] $*" >&2
  if [[ -f "$RUNTIME_LOG" ]]; then
    echo "[echo-qa-evidence-bundle-export-smoke] runtime log tail:" >&2
    tail -80 "$RUNTIME_LOG" >&2 || true
  fi
  if [[ -f "$OS_LOG" ]]; then
    echo "[echo-qa-evidence-bundle-export-smoke] os log tail:" >&2
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
RESULT_FILE="$DATA_CONTAINER/Documents/echo-qa-evidence-bundle-export-smoke-result.json"
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

echo "[echo-qa-evidence-bundle-export-smoke] Launching QA evidence bundle export harness..."
xcrun simctl launch --console "$SIMULATOR_UDID" "$BUNDLE_ID" DJRunEchoQAEvidenceBundleExportSmoke > "$RUNTIME_LOG" 2>&1 &
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

python3 - "$RESULT_FILE" "$BUNDLE_EXPORT_COPY_PATH" <<'PY'
import json
import pathlib
import sys

result_path = pathlib.Path(sys.argv[1])
bundle_copy_path = pathlib.Path(sys.argv[2])
result = json.loads(result_path.read_text())

def require(condition, message):
    if not condition:
        raise SystemExit(message)

require(result.get("completed") is True, "Echo QA evidence bundle smoke did not complete")
require(result.get("schemaVersion") == 2, "QA evidence bundle schemaVersion changed")
require(result.get("latestTurnID") == "uiqa-qa-bundle-turn", "QA evidence bundle latest turn changed")
require(result.get("latestVoiceOutputMode") == "tencentAudioDrive", "QA evidence bundle voice output mode changed")
require(result.get("latestProviderLogId") == "uiqa-bundle-provider-log", "QA evidence bundle provider log changed")
require(result.get("latestDigitalHumanStatus") == "unavailable", "QA evidence bundle digital human status changed")
require(result.get("latestFallbacks") == "voice_clone_provider_retry", "QA evidence bundle fallback summary changed")
require(result.get("latestClueSummaryArchiveRefs") == "archive_qa_bundle", "QA evidence bundle archive clues changed")
require(result.get("latestClueSummaryKbFactRefs") == "fact_qa_bundle", "QA evidence bundle kbFact clues changed")
require(
    result.get("latestClueSummaryPersonaRefs") == "persona:personal:uiqa_echo_qa_bundle_user",
    "QA evidence bundle persona clues changed",
)
require(result.get("latestClueSummaryCareRefs") == "care:latest", "QA evidence bundle care clues changed")
require(result.get("latestRankingTraceCount") == 6, "QA evidence bundle ranking trace count changed")
require(result.get("fileExists") is True, "QA evidence bundle export file should exist")
export_path = result.get("exportPath")
require(isinstance(export_path, str) and export_path.endswith("echo-qa-evidence-bundle.json"), "Missing QA bundle export path")

export_file = pathlib.Path(export_path)
require(export_file.exists(), f"Exported QA evidence bundle file missing: {export_file}")
bundle = json.loads(export_file.read_text())
require(bundle.get("schemaVersion") == 2, "Exported QA bundle schemaVersion changed")
require(bundle.get("evidencePackage", {}).get("schemaVersion") == 1, "Nested evidence package schemaVersion changed")
require(bundle.get("contextClues", {}).get("archiveRefs") == ["archive_qa_bundle"], "Exported archive clue summary changed")
require(bundle.get("contextClues", {}).get("kbFactRefs") == ["fact_qa_bundle"], "Exported kbFact clue summary changed")
require(bundle.get("digitalHumanSession", {}).get("status") == "unavailable", "Exported digital human status changed")
require(bundle.get("voiceSynthesis", {}).get("providerLogId") == "uiqa-bundle-provider-log", "Exported voice provider log changed")
require(
    bundle.get("fallbackSummary", {}).get("contextFallbacks") == ["voice_clone_provider_retry"],
    "Exported fallback summary changed",
)
serialized = json.dumps(bundle, ensure_ascii=False)
require("audioBase64" not in serialized, "QA evidence bundle must not export audioBase64")
require("appkey" not in serialized.lower(), "QA evidence bundle must not export appkey")
require("accesstoken" not in serialized.lower(), "QA evidence bundle must not export accesstoken")
bundle_copy_path.write_text(json.dumps(bundle, ensure_ascii=False, indent=2, sort_keys=True))
PY

xcrun simctl io "$SIMULATOR_UDID" screenshot "$SCREENSHOT_PATH" >/dev/null
xcrun simctl terminate "$SIMULATOR_UDID" "$BUNDLE_ID" >/dev/null 2>&1 || true

cat > "$REPORT_PATH" <<EOF
# Echo QA Evidence Bundle Export UIQA Smoke

Run ID: \`$RUN_ID\`

## Bundle Guard

- Bundle ID: \`$BUNDLE_ID\`
- App executable archs: \`$APP_EXECUTABLE_ARCHS\`
- Simulator: \`$SIMULATOR_UDID\`

## Result

- Result JSON: \`echo-qa-evidence-bundle-export-smoke-result.json\`
- QA evidence bundle: \`echo-qa-evidence-bundle.json\`
- Screenshot: \`01-echo-qa-evidence-bundle-export-smoke.png\`
- Build log: \`build.log\`
- Runtime log: \`runtime.log\`
- OS log: \`oslog.log\`

EOF

echo "[echo-qa-evidence-bundle-export-smoke] Build log: $BUILD_LOG"
echo "[echo-qa-evidence-bundle-export-smoke] Runtime log: $RUNTIME_LOG"
echo "[echo-qa-evidence-bundle-export-smoke] OS log: $OS_LOG"
echo "[echo-qa-evidence-bundle-export-smoke] Result: $RESULT_COPY_PATH"
echo "[echo-qa-evidence-bundle-export-smoke] QA bundle: $BUNDLE_EXPORT_COPY_PATH"
echo "[echo-qa-evidence-bundle-export-smoke] Screenshot: $SCREENSHOT_PATH"

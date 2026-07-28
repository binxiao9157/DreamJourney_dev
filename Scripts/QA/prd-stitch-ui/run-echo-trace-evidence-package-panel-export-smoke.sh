#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../../.." && pwd)"

SCHEME="${SCHEME:-DreamJourney}"
CONFIGURATION="${CONFIGURATION:-Debug}"
SIMULATOR_NAME="${SIMULATOR_NAME:-iPhone 16}"
SWIFT_ACTIVE_COMPILATION_CONDITIONS="${SWIFT_ACTIVE_COMPILATION_CONDITIONS:-DEBUG UI_QA_SIMULATOR}"
DERIVED_DATA_PATH="${DERIVED_DATA_PATH:-$ROOT_DIR/tmp/visual-qa/prd-stitch-ui/DerivedDataEchoTraceEvidencePackagePanelExportSmoke}"
OUTPUT_ROOT="${OUTPUT_ROOT:-$ROOT_DIR/tmp/visual-qa/prd-stitch-ui/echo-trace-evidence-package-panel-export-smoke}"
RUN_ID="${RUN_ID:-$(date +%Y%m%d-%H%M%S)}"
OUTPUT_DIR="$OUTPUT_ROOT/$RUN_ID"
BUILD_LOG="$OUTPUT_DIR/build.log"
RUNTIME_LOG="$OUTPUT_DIR/runtime.log"
OS_LOG="$OUTPUT_DIR/oslog.log"
SCREENSHOT_PATH="$OUTPUT_DIR/01-echo-trace-evidence-package-panel-export-smoke.png"
RESULT_COPY_PATH="$OUTPUT_DIR/echo-trace-evidence-package-panel-export-smoke-result.json"
PACKAGE_EXPORT_COPY_PATH="$OUTPUT_DIR/echo-trace-evidence-packages.json"
REPORT_PATH="$OUTPUT_DIR/report.md"
COMPLETION_PATTERN="EchoTraceEvidencePackagePanelExportSmoke completed"
LOG_WAIT_TIMEOUT="${LOG_WAIT_TIMEOUT:-45}"

mkdir -p "$OUTPUT_DIR"
cd "$ROOT_DIR"

fail() {
  echo "[echo-trace-evidence-package-panel-export-smoke] $*" >&2
  if [[ -f "$RUNTIME_LOG" ]]; then
    echo "[echo-trace-evidence-package-panel-export-smoke] runtime log tail:" >&2
    tail -80 "$RUNTIME_LOG" >&2 || true
  fi
  if [[ -f "$OS_LOG" ]]; then
    echo "[echo-trace-evidence-package-panel-export-smoke] os log tail:" >&2
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
RESULT_FILE="$DATA_CONTAINER/Documents/echo-trace-evidence-package-panel-export-smoke-result.json"
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

echo "[echo-trace-evidence-package-panel-export-smoke] Launching panel export harness..."
xcrun simctl launch --console "$SIMULATOR_UDID" "$BUNDLE_ID" DJRunEchoTraceEvidencePackagePanelExportSmoke > "$RUNTIME_LOG" 2>&1 &
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
import hashlib
import pathlib
import sys

result_path = pathlib.Path(sys.argv[1])
package_copy_path = pathlib.Path(sys.argv[2])
result = json.loads(result_path.read_text())

def require(condition, message):
    if not condition:
        raise SystemExit(message)

def correlation_hash(value):
    return "sha256:" + hashlib.sha256(value.encode()).hexdigest()[:16]

require(result.get("completed") is True, "Echo evidence panel export smoke did not complete")
require(result.get("buttonVisible") is True, "QA evidence export button should be visible")
require(result.get("buttonTitle") == "导出证据包", "QA evidence export button title changed")
require(result.get("personaBadgeMatchesFamily") is True, "Visible Echo persona badge must match the family runtime context")
require(result.get("personaBadgeName") == "UIQA 家人音色 · AI 数字分身", "Visible Echo persona badge text changed")
require(result.get("latestTurnIDHash") == correlation_hash("uiqa-panel-evidence-turn"), "Panel export latest turn hash changed")
require(result.get("latestProviderLogIdHash") == correlation_hash("uiqa-panel-provider-log"), "Panel export provider log hash changed")
require(result.get("latestArchiveClueHashes") == correlation_hash("archive_panel_evidence"), "Panel export archive clue hash changed")
require(result.get("latestKbFactClueHashes") == correlation_hash("fact_panel_evidence"), "Panel export kbFact clue hash changed")
require(result.get("latestPersonaClueHashes") == correlation_hash("persona:personal:uiqa_echo_panel_evidence_user"), "Panel export persona clue hash changed")
require(result.get("latestCareClueHashes") == correlation_hash("care:latest"), "Panel export care clue hash changed")
require(result.get("latestContextVersion") == "echo-context-v2", "Panel export context version changed")
require(result.get("latestFilteredReasons") == "archive_panel_filtered:analysis_failed_empty_context", "Panel export filtered reasons changed")
require(result.get("latestRankingTraceCount") == 5, "Panel export ranking trace count changed")
require(result.get("latestRuntimeRoleVoiceSource") == "familyMember", "Panel export role voice source changed")
require(result.get("latestRuntimeVoiceProfileIdHash") == correlation_hash("S_uiqa_family_panel_voice"), "Panel export role voice profile hash changed")
require(result.get("latestRuntimeAudioOwner") == "tencentDigitalHuman", "Panel export audio owner changed")
require(result.get("fileExists") is True, "Panel evidence export file should exist")
export_path = result.get("exportPath")
require(isinstance(export_path, str) and export_path.endswith("echo-trace-evidence-packages.json"), "Missing evidence package export path")

export_file = pathlib.Path(export_path)
require(export_file.exists(), f"Exported evidence package file missing: {export_file}")
packages = json.loads(export_file.read_text())
require(packages[-1].get("turnIDHash") == correlation_hash("uiqa-panel-evidence-turn"), "Exported panel package latest turn hash changed")
runtime_diagnostics = packages[-1].get("runtimeDiagnostics", {})
require(runtime_diagnostics.get("roleVoiceSource") == "familyMember", "Exported role voice source changed")
require(
    runtime_diagnostics.get("roleVoiceContextOwnerIdHash") == correlation_hash("uiqa_family_voice_panel_member"),
    "Exported role voice context owner hash changed",
)
require(runtime_diagnostics.get("voiceProfileIdHash") == correlation_hash("S_uiqa_family_panel_voice"), "Exported role voice profile hash changed")
require(runtime_diagnostics.get("audioOwner") == "tencentDigitalHuman", "Exported audio owner changed")
clue_summary = packages[-1].get("contextBuild", {}).get("clueSummary", {})
require(clue_summary.get("archiveRefsHashes") == [correlation_hash("archive_panel_evidence")], "Exported archive clue summary changed")
require(clue_summary.get("kbFactRefsHashes") == [correlation_hash("fact_panel_evidence")], "Exported kbFact clue summary changed")
require(
    clue_summary.get("personaRefsHashes") == [correlation_hash("persona:personal:uiqa_echo_panel_evidence_user")],
    "Exported persona clue summary changed",
)
require(clue_summary.get("careRefsHashes") == [correlation_hash("care:latest")], "Exported care clue summary changed")
require(clue_summary.get("contextVersion") == "echo-context-v2", "Exported context version changed")
require(
    clue_summary.get("filteredContextReasons") == ["archive_panel_filtered:analysis_failed_empty_context"],
    "Exported filtered clue summary changed",
)
require(clue_summary.get("rankingTraceCount") == 5, "Exported ranking trace count changed")
serialized = json.dumps(packages, ensure_ascii=False)
require("audioBase64" not in serialized, "Evidence package must not export audioBase64")
require("appkey" not in serialized.lower(), "Evidence package must not export appkey")
require("accesstoken" not in serialized.lower(), "Evidence package must not export accesstoken")
require("uiqa-panel-provider-log" not in serialized, "Evidence package must not export raw provider log IDs")
require("archive_panel_evidence" not in serialized, "Evidence package must not export raw archive references")
package_copy_path.write_text(json.dumps(packages, ensure_ascii=False, indent=2, sort_keys=True))
PY

xcrun simctl io "$SIMULATOR_UDID" screenshot "$SCREENSHOT_PATH" >/dev/null
xcrun simctl terminate "$SIMULATOR_UDID" "$BUNDLE_ID" >/dev/null 2>&1 || true

cat > "$REPORT_PATH" <<EOF
# Echo Trace Evidence Package Panel Export UIQA Smoke

Run ID: \`$RUN_ID\`

## Bundle Guard

- Bundle ID: \`$BUNDLE_ID\`
- App executable archs: \`$APP_EXECUTABLE_ARCHS\`
- Simulator: \`$SIMULATOR_UDID\`

## Result

- Result JSON: \`echo-trace-evidence-package-panel-export-smoke-result.json\`
- Evidence export: \`echo-trace-evidence-packages.json\`
- Screenshot: \`01-echo-trace-evidence-package-panel-export-smoke.png\`
- Build log: \`build.log\`
- Runtime log: \`runtime.log\`
- OS log: \`oslog.log\`

EOF

echo "[echo-trace-evidence-package-panel-export-smoke] Build log: $BUILD_LOG"
echo "[echo-trace-evidence-package-panel-export-smoke] Runtime log: $RUNTIME_LOG"
echo "[echo-trace-evidence-package-panel-export-smoke] OS log: $OS_LOG"
echo "[echo-trace-evidence-package-panel-export-smoke] Result: $RESULT_COPY_PATH"
echo "[echo-trace-evidence-package-panel-export-smoke] Evidence export: $PACKAGE_EXPORT_COPY_PATH"
echo "[echo-trace-evidence-package-panel-export-smoke] Screenshot: $SCREENSHOT_PATH"

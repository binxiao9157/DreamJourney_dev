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
MANIFEST_EXPORT_COPY_PATH="$OUTPUT_DIR/echo-qa-evidence-manifest.json"
REPORT_PATH="$OUTPUT_DIR/report.md"
COMPLETION_PATTERN="EchoQAEvidenceBundleExportSmoke completed"
LOG_WAIT_TIMEOUT="${LOG_WAIT_TIMEOUT:-45}"
SOURCE_COMMIT="${SOURCE_COMMIT:-$(git rev-parse --verify HEAD)}"

mkdir -p "$OUTPUT_DIR"
cd "$ROOT_DIR"

[[ "$SOURCE_COMMIT" =~ ^[0-9a-f]{7,64}$ ]] || {
  echo "[echo-qa-evidence-bundle-export-smoke] SOURCE_COMMIT must be a lowercase Git commit" >&2
  exit 1
}

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
xcrun simctl launch --console "$SIMULATOR_UDID" "$BUNDLE_ID" \
  DJRunEchoQAEvidenceBundleExportSmoke \
  DJEnableOwnerTruthContextCitationQA \
  DJEnableOwnerTruthMigrationParityQA \
  "DJEvidenceSourceCommit=$SOURCE_COMMIT" > "$RUNTIME_LOG" 2>&1 &
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

python3 - "$RESULT_FILE" "$BUNDLE_EXPORT_COPY_PATH" "$MANIFEST_EXPORT_COPY_PATH" "$SOURCE_COMMIT" <<'PY'
import json
import hashlib
import pathlib
import sys

result_path = pathlib.Path(sys.argv[1])
bundle_copy_path = pathlib.Path(sys.argv[2])
manifest_copy_path = pathlib.Path(sys.argv[3])
source_commit = sys.argv[4]
result = json.loads(result_path.read_text())

def require(condition, message):
    if not condition:
        raise SystemExit(message)

def correlation_hash(value):
    return "sha256:" + hashlib.sha256(value.encode()).hexdigest()[:16]

require(result.get("completed") is True, "Echo QA evidence bundle smoke did not complete")
require(result.get("schemaVersion") == 4, "QA evidence bundle schemaVersion changed")
require(result.get("latestTurnIDHash") == correlation_hash("uiqa-qa-bundle-turn"), "QA evidence bundle latest turn hash changed")
require(result.get("latestVoiceOutputMode") == "tencentAudioDrive", "QA evidence bundle voice output mode changed")
require(result.get("latestProviderLogIdHash") == correlation_hash("uiqa-bundle-provider-log"), "QA evidence bundle provider log hash changed")
require(result.get("latestDigitalHumanStatus") == "unavailable", "QA evidence bundle digital human status changed")
require(result.get("latestFallbacks") == "voice_clone_provider_retry", "QA evidence bundle fallback summary changed")
require(result.get("latestClueSummaryArchiveRefHashes") == correlation_hash("archive_qa_bundle"), "QA evidence bundle archive clue hash changed")
require(result.get("latestClueSummaryKbFactRefHashes") == correlation_hash("fact_qa_bundle"), "QA evidence bundle kbFact clue hash changed")
require(
    result.get("latestClueSummaryPersonaRefHashes") == correlation_hash("persona:personal:uiqa_echo_qa_bundle_user"),
    "QA evidence bundle persona clue hash changed",
)
require(result.get("latestClueSummaryCareRefHashes") == correlation_hash("care:latest"), "QA evidence bundle care clue hash changed")
require(result.get("latestRankingTraceCount") == 6, "QA evidence bundle ranking trace count changed")
require(
    result.get("ownerTruthContextEvidenceSchemaVersion") == "owner-truth-context-citation-readout-v1",
    "Owner Truth Context QA evidence schema changed",
)
require(
    result.get("ownerTruthContextReferenceDigestCount") == 1,
    "Owner Truth Context QA evidence should include one digested citation reference",
)
require(
    result.get("ownerTruthContextPanelVisible") is True,
    "Owner Truth Context QA evidence should render in the QA diagnostics panel",
)
require(
    result.get("ownerTruthContextParityEvidenceSchemaVersion") == "echo-owner-truth-context-parity-readout-v1",
    "Owner Truth Context parity QA evidence schema changed",
)
require(
    result.get("ownerTruthContextParityPromotionDecision") == "notEvaluated",
    "Owner Truth Context parity must not imply a promotion decision",
)
require(
    "M04" in (result.get("ownerTruthContextParityMismatchCodes") or "").split(","),
    "Owner Truth Context parity fixture should preserve the authority-epoch mismatch",
)
require(
    result.get("ownerTruthContextParityPanelVisible") is True,
    "Owner Truth Context parity evidence should render in the QA diagnostics panel",
)
require(result.get("fileExists") is True, "QA evidence bundle export file should exist")
require(result.get("manifestSchemaVersion") == 1, "QA evidence manifest schemaVersion changed")
require(result.get("manifestStatus") == "passed", "QA evidence manifest should be passed")
require(result.get("manifestSourceCommit") == source_commit, "QA evidence manifest source commit changed")
require(result.get("manifestCurrent") is True, "QA evidence manifest should be current")
require(result.get("manifestOwnerIsolation") is True, "QA evidence manifest must remain owner-isolated")
require(result.get("manifestExpiryObserved") is True, "QA evidence manifest expiry guard changed")
require(result.get("manifestFileExists") is True, "QA evidence manifest export file should exist")
export_path = result.get("exportPath")
require(isinstance(export_path, str) and export_path.endswith("echo-qa-evidence-bundle.json"), "Missing QA bundle export path")
manifest_export_path = result.get("manifestExportPath")
require(isinstance(manifest_export_path, str) and manifest_export_path.endswith("echo-qa-evidence-manifest.json"), "Missing QA manifest export path")

export_file = pathlib.Path(export_path)
require(export_file.exists(), f"Exported QA evidence bundle file missing: {export_file}")
bundle = json.loads(export_file.read_text())
require(bundle.get("schemaVersion") == 4, "Exported QA bundle schemaVersion changed")
require(bundle.get("evidencePackage", {}).get("schemaVersion") == 1, "Nested evidence package schemaVersion changed")
require(bundle.get("redactionPolicyVersion") == "iosDiagnostics-v1", "QA evidence bundle should declare its redaction policy")
answer_grounding = bundle.get("answerGrounding") or {}
require(answer_grounding.get("schemaVersion") == 1, "Answer grounding evidence schema changed")
require(answer_grounding.get("outcome") == "grounded", "Answer grounding outcome changed")
require(answer_grounding.get("citationCount") == 1, "Answer grounding citation count changed")
require(
    answer_grounding.get("citationSources") == ["ownerTruthMemoryProjection"],
    "Answer grounding citation source changed",
)
for field in ("contextTraceIdDigest",):
    value = answer_grounding.get(field)
    require(
        isinstance(value, str) and len(value) == 64 and all(char in "0123456789abcdef" for char in value),
        f"Answer grounding {field} must be a SHA-256 digest",
    )
for field in ("citationRefDigests", "citationContentHashDigests"):
    values = answer_grounding.get(field) or []
    require(len(values) == 1, f"Answer grounding {field} count changed")
    require(
        all(isinstance(value, str) and len(value) == 64 and all(char in "0123456789abcdef" for char in value) for value in values),
        f"Answer grounding {field} must contain SHA-256 digests",
    )
require(bundle.get("contextClues", {}).get("archiveRefsHashes") == [correlation_hash("archive_qa_bundle")], "Exported archive clue summary changed")
require(bundle.get("contextClues", {}).get("kbFactRefsHashes") == [correlation_hash("fact_qa_bundle")], "Exported kbFact clue summary changed")
owner_truth_context = bundle.get("ownerTruthContextCitationEvidence") or {}
require(
    owner_truth_context.get("schemaVersion") == "owner-truth-context-citation-readout-v1",
    "Exported Owner Truth Context QA evidence schema changed",
)
require(owner_truth_context.get("contextVersion") == "echo-context-v4-shadow", "Owner Truth Context version changed")
require(owner_truth_context.get("authorityState") == "ready", "Owner Truth Context authority state changed")
require(owner_truth_context.get("authorityEpoch") == 7, "Owner Truth Context authority epoch changed")
owner_truth_ref_digests = owner_truth_context.get("selectedContextRefDigests") or []
require(len(owner_truth_ref_digests) == 1, "Owner Truth Context should export one digested reference")
require(
    all(isinstance(value, str) and len(value) == 64 and all(char in "0123456789abcdef" for char in value) for value in owner_truth_ref_digests),
    "Owner Truth Context references must be SHA-256 digests",
)
owner_truth_context_parity = bundle.get("ownerTruthContextParityEvidence") or {}
require(
    owner_truth_context_parity.get("schemaVersion") == "echo-owner-truth-context-parity-readout-v1",
    "Exported Owner Truth Context parity QA evidence schema changed",
)
require(
    owner_truth_context_parity.get("comparisonState") == "observedNonPromoting",
    "Owner Truth Context parity must remain observation-only",
)
require(
    owner_truth_context_parity.get("promotionDecision") == "notEvaluated",
    "Owner Truth Context parity must not authorize promotion",
)
require(
    "M04" in (owner_truth_context_parity.get("mismatchCodes") or []),
    "Owner Truth Context parity should preserve authority-epoch mismatch evidence",
)
require(bundle.get("digitalHumanSession", {}).get("status") == "unavailable", "Exported digital human status changed")
require(bundle.get("voiceSynthesis", {}).get("providerLogIdHash") == correlation_hash("uiqa-bundle-provider-log"), "Exported voice provider log changed")
require(
    bundle.get("fallbackSummary", {}).get("contextFallbacks") == ["voice_clone_provider_retry"],
    "Exported fallback summary changed",
)
serialized = json.dumps(bundle, ensure_ascii=False)
require("audioBase64" not in serialized, "QA evidence bundle must not export audioBase64")
require("appkey" not in serialized.lower(), "QA evidence bundle must not export appkey")
require("accesstoken" not in serialized.lower(), "QA evidence bundle must not export accesstoken")
require("uiqa-bundle-provider-log" not in serialized, "QA evidence bundle must not export raw provider log IDs")
require("archive_qa_bundle" not in serialized, "QA evidence bundle must not export raw archive references")
require("ctx_uiqa_grounding_trace" not in serialized, "QA evidence bundle must not export raw answer Context trace IDs")
require("memory-version:uiqa-grounding-reference" not in serialized, "QA evidence bundle must not export raw answer Citation refs")
require(("a" * 64) not in serialized, "QA evidence bundle must not export raw answer Citation content hashes")
require("uiqa echo context parity evidence" not in serialized, "QA evidence bundle must not export raw parity query")
require(
    "memory-version:00000000-0000-0000-0000-000000000901" not in serialized,
    "QA evidence bundle must not export raw Owner Truth memory references",
)
bundle_copy_path.write_text(json.dumps(bundle, ensure_ascii=False, indent=2, sort_keys=True))

manifest_file = pathlib.Path(manifest_export_path)
require(manifest_file.exists(), f"Exported QA evidence manifest file missing: {manifest_file}")
manifest = json.loads(manifest_file.read_text())
bundle_hash = hashlib.sha256(export_file.read_bytes()).hexdigest()
require(manifest.get("schemaVersion") == 1, "Exported manifest schemaVersion changed")
require(manifest.get("manifestVersion") == 1, "Exported manifest version changed")
require(manifest.get("manifestType") == "echoQaEvidenceBundle", "Exported manifest type changed")
require(manifest.get("sourceCommit") == source_commit, "Exported manifest source commit changed")
require(manifest.get("manifestStatus") == "passed", "Exported manifest must be passed")
require(manifest.get("artifactHashes") == [bundle_hash], "Manifest must bind the exact redacted bundle hash")
require(manifest.get("sourceSchemaVersions") == ["echoQaBundle-v4", "echoEvidenceManifest-v1"], "Manifest schema source changed")
require(manifest.get("exclusionCodes") == ["rawAudio", "providerSecret", "reportBody", "userContent"], "Manifest exclusion set changed")
require(isinstance(manifest.get("ownerLeaseHash"), str) and len(manifest["ownerLeaseHash"]) == 64, "Manifest owner lease hash missing")
require("evidenceIdHash" in manifest, "Manifest evidence id should be redacted at export")
manifest_serialized = json.dumps(manifest, ensure_ascii=False)
require("uiqa_echo_qa_bundle_user" not in manifest_serialized, "Manifest must not export raw owner identity")
require("uiqa-bundle-provider-log" not in manifest_serialized, "Manifest must not export raw provider log ID")
require("archive_qa_bundle" not in manifest_serialized, "Manifest must not export raw archive reference")
manifest_copy_path.write_text(json.dumps(manifest, ensure_ascii=False, indent=2, sort_keys=True))
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
- QA evidence manifest: \`echo-qa-evidence-manifest.json\`
- Source commit: \`$SOURCE_COMMIT\`
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
echo "[echo-qa-evidence-bundle-export-smoke] QA manifest: $MANIFEST_EXPORT_COPY_PATH"
echo "[echo-qa-evidence-bundle-export-smoke] Screenshot: $SCREENSHOT_PATH"

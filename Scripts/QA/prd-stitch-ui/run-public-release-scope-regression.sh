#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../../.." && pwd)"
BACKEND_ROOT="${BACKEND_ROOT:-$(cd "$ROOT_DIR/.." && pwd)/DreamJourneyBackend}"
RUN_ID="${RUN_ID:-$(date +%Y%m%d-%H%M%S)-public-release-scope}"
OUTPUT_ROOT="${OUTPUT_ROOT:-$ROOT_DIR/tmp/visual-qa/prd-stitch-ui/public-release-scope-regression}"
OUTPUT_DIR="$OUTPUT_ROOT/$RUN_ID"
RUN_RELEASE_ARTIFACT="${RUN_RELEASE_ARTIFACT:-1}"
RUN_BACKEND_G2="${RUN_BACKEND_G2:-0}"
MODEL_RESULT="$OUTPUT_DIR/model-result.json"
UI_RESULT="$OUTPUT_DIR/uiqa/result.json"
BACKEND_RESULT="$OUTPUT_DIR/backend-result.json"
EVIDENCE_RESULT="$OUTPUT_DIR/public-release-scope-evidence.json"
REPORT_PATH="$OUTPUT_DIR/report.md"
ARTIFACT_REPORT="${RELEASE_ARTIFACT_REPORT:-}"

mkdir -p "$OUTPUT_DIR"

swift "$SCRIPT_DIR/public-release-scope-regression-check.swift" "$ROOT_DIR"
OUTPUT_PATH="$MODEL_RESULT" "$SCRIPT_DIR/run-public-release-scope-model-smoke.sh"

if [[ "$RUN_RELEASE_ARTIFACT" == "1" ]]; then
  RUN_ID=release-artifact \
  OUTPUT_ROOT="$OUTPUT_DIR" \
    "$SCRIPT_DIR/run-release-qa-override-artifact-scan.sh"
  ARTIFACT_REPORT="$OUTPUT_DIR/release-artifact/report.md"
fi
[[ -f "$ARTIFACT_REPORT" ]] || { echo "Release artifact report is required" >&2; exit 1; }

RUN_ID=uiqa \
OUTPUT_ROOT="$OUTPUT_DIR" \
DERIVED_DATA_PATH="$OUTPUT_DIR/DerivedDataReleaseSimulator" \
  "$SCRIPT_DIR/run-public-release-scope-uiqa-smoke.sh"

if [[ "$RUN_BACKEND_G2" == "1" ]]; then
  [[ -d "$BACKEND_ROOT" ]] || { echo "Backend repo is required" >&2; exit 1; }
  OUTPUT_PATH="$BACKEND_RESULT" \
  BACKEND_BASE_URL="${BACKEND_BASE_URL:-}" \
  BACKEND_API_TOKEN="${BACKEND_API_TOKEN:-}" \
  EXPECTED_RELEASE_POLICY_COMMAND_MODE="${EXPECTED_RELEASE_POLICY_COMMAND_MODE:-observe}" \
    "$BACKEND_ROOT/scripts/run-backend-public-release-scope-deployed-smoke.sh"
  python3 "$SCRIPT_DIR/public-release-scope-evidence.py" \
    "$MODEL_RESULT" "$UI_RESULT" "$ARTIFACT_REPORT" "$EVIDENCE_RESULT" "$BACKEND_RESULT"
else
  python3 "$SCRIPT_DIR/public-release-scope-evidence.py" \
    "$MODEL_RESULT" "$UI_RESULT" "$ARTIFACT_REPORT" "$EVIDENCE_RESULT"
fi

cat > "$REPORT_PATH" <<REPORT
# Public Release Scope Regression

- Run ID: \`$RUN_ID\`
- Work Item: \`WI-S0-06-07\`
- Release artifact gate: passed
- Release default entry and deep-link negative gate: passed
- Policy offline/expired/emergency gate: passed
- Deployed G2 command gate: \`$RUN_BACKEND_G2\`
- G4 true-device regression: open
- Evidence bundle: \`$(basename "$EVIDENCE_RESULT")\`
REPORT

echo "Public Release Scope regression passed"
echo "Report: $REPORT_PATH"
echo "Evidence: $EVIDENCE_RESULT"

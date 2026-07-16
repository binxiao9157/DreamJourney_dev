#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../../.." && pwd)"
BACKEND_ROOT="${BACKEND_ROOT:-$(cd "$ROOT_DIR/.." && pwd)/DreamJourneyBackend}"
RUN_ID="${RUN_ID:-$(date +%Y%m%d-%H%M%S)-release-policy-rollout}"
OUTPUT_ROOT="${OUTPUT_ROOT:-$ROOT_DIR/tmp/visual-qa/prd-stitch-ui/release-policy-rollout}"
OUTPUT_DIR="$OUTPUT_ROOT/$RUN_ID"
RUN_BACKEND_G2="${RUN_BACKEND_G2:-0}"
BACKEND_RESULT="$OUTPUT_DIR/backend-result.json"
REPORT_PATH="$OUTPUT_DIR/report.md"

mkdir -p "$OUTPUT_DIR"

swift "$SCRIPT_DIR/release-policy-rollout-retirement-check.swift" "$ROOT_DIR"

if [[ "$RUN_BACKEND_G2" == "1" ]]; then
  [[ -d "$BACKEND_ROOT" ]] || { echo "Backend repo is required" >&2; exit 1; }
  OUTPUT_PATH="$BACKEND_RESULT" \
  BACKEND_BASE_URL="${BACKEND_BASE_URL:-}" \
  BACKEND_API_TOKEN="${BACKEND_API_TOKEN:-}" \
  EXPECTED_RELEASE_POLICY_CANARY_FEATURES="${EXPECTED_RELEASE_POLICY_CANARY_FEATURES:-}" \
  EXPECTED_RELEASE_POLICY_KILL_SWITCH_FEATURES="${EXPECTED_RELEASE_POLICY_KILL_SWITCH_FEATURES:-}" \
    "$BACKEND_ROOT/scripts/run-backend-release-policy-rollout-deployed-smoke.sh"
else
  printf '{"status":"skipped","reason":"RUN_BACKEND_G2=0"}\n' > "$BACKEND_RESULT"
fi

cat > "$REPORT_PATH" <<REPORT
# Release Policy Rollout Gate

- Run ID: \`$RUN_ID\`
- Work Item: \`WI-S0-06-08\`
- Static rollout/retirement contract: passed
- Deployed G2 rollout smoke: \`$RUN_BACKEND_G2\`
- G4 feature-specific true-device gate: open
- Backend evidence: \`$(basename "$BACKEND_RESULT")\`
REPORT

echo "Release Policy rollout gate passed"
echo "Report: $REPORT_PATH"

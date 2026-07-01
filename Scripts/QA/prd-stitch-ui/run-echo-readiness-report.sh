#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../../.." && pwd)"
RUN_ID="${RUN_ID:-$(date +%Y%m%d-%H%M%S)-echo-readiness-report}"
OUTPUT_ROOT="${OUTPUT_ROOT:-$ROOT_DIR/tmp/visual-qa/prd-stitch-ui/echo-readiness-report}"
OUTPUT_DIR="$OUTPUT_ROOT/$RUN_ID"

mkdir -p "$OUTPUT_DIR"

python3 "$SCRIPT_DIR/echo-readiness-report.py" "$ROOT_DIR" "$OUTPUT_DIR" | tee "$OUTPUT_DIR/echo-readiness-report-runner.json"

cat > "$OUTPUT_DIR/report.md" <<EOF
# Echo Readiness Report Runner

Run ID: \`$RUN_ID\`

- JSON report: \`echo-readiness-report.json\`
- Markdown report: \`echo-readiness-report.md\`
- Runner result: \`echo-readiness-report-runner.json\`

Backend probing is optional. Provide \`BACKEND_BASE_URL\` and \`BACKEND_API_TOKEN\` to include deployed backend checks.
Voice synthesis is opt-in via \`RUN_READINESS_VOICE_SYNTHESIS=1\` plus \`VOICE_CLONE_READY_PROFILE_ID\`.
Use \`READINESS_STRICT=1\` when this report should fail the command on degraded checks.
EOF

echo "Echo readiness report written to $OUTPUT_DIR"

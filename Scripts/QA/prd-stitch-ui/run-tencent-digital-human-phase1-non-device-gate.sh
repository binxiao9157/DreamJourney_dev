#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../../.." && pwd)"

RUN_ID="${RUN_ID:-$(date +%Y%m%d-%H%M%S)-tencent-phase1-non-device}"
OUTPUT_ROOT="${OUTPUT_ROOT:-$ROOT_DIR/tmp/visual-qa/prd-stitch-ui/tencent-digital-human-phase1-non-device-gate}"
OUTPUT_DIR="$OUTPUT_ROOT/$RUN_ID"
REPORT_PATH="$OUTPUT_DIR/report.md"
COMMAND_LOG="$OUTPUT_DIR/commands.log"
STATIC_LOG_DIR="$OUTPUT_DIR/static-guards"
DERIVED_DATA_PATH="${DERIVED_DATA_PATH:-$OUTPUT_DIR/DerivedDataPhase1NonDeviceGate}"

mkdir -p "$STATIC_LOG_DIR"
touch "$COMMAND_LOG"

cd "$ROOT_DIR"

cat > "$REPORT_PATH" <<EOF
# Tencent Digital Human Phase 1 Non-Device Gate

Run ID: \`$RUN_ID\`

## Scope

- This gate intentionally does not run true-device validation.
- It verifies backend-first asset source, QA-only local asset override, Echo digital-human lifecycle, audio owner logging, provider fallback, fake Tencent runtime, backend PCM-drive mock, static release regression, simulator Debug build, and whitespace safety.
- True-device validation for actual sound, lip movement, interruption, and microphone recovery remains outside this non-device gate.

## Steps

EOF

run_step() {
  local name="$1"
  shift
  local log_path="$1"
  shift

  echo "== $name ==" | tee -a "$COMMAND_LOG"
  printf '+ ' >> "$COMMAND_LOG"
  printf '%q ' "$@" >> "$COMMAND_LOG"
  printf '\n' >> "$COMMAND_LOG"

  if "$@" > "$log_path" 2>&1; then
    echo "- $name: passed" >> "$REPORT_PATH"
  else
    echo "- $name: failed. See \`$(basename "$log_path")\`." >> "$REPORT_PATH"
    cat "$log_path" >&2
    exit 1
  fi
}

run_shell_step() {
  local name="$1"
  shift
  local log_path="$1"
  shift
  local command="$*"

  echo "== $name ==" | tee -a "$COMMAND_LOG"
  echo "+ $command" >> "$COMMAND_LOG"

  if bash -lc "$command" > "$log_path" 2>&1; then
    echo "- $name: passed" >> "$REPORT_PATH"
  else
    echo "- $name: failed. See \`$(basename "$log_path")\`." >> "$REPORT_PATH"
    cat "$log_path" >&2
    exit 1
  fi
}

run_step \
  "Phase 1 digital-human stability static guard" \
  "$STATIC_LOG_DIR/tencent-digital-human-phase1-stability-check.log" \
  swift "$SCRIPT_DIR/tencent-digital-human-phase1-stability-check.swift" "$ROOT_DIR"

run_step \
  "Tencent backend PCM-drive mock static guard" \
  "$STATIC_LOG_DIR/tencent-backend-pcm-drive-mock-smoke-check.log" \
  swift "$SCRIPT_DIR/tencent-backend-pcm-drive-mock-smoke-check.swift" "$ROOT_DIR"

run_step \
  "True-device Tencent smoke static guard" \
  "$STATIC_LOG_DIR/true-device-tencent-backend-pcm-drive-smoke-check.log" \
  swift "$SCRIPT_DIR/true-device-tencent-backend-pcm-drive-smoke-check.swift" "$ROOT_DIR"

run_shell_step \
  "Digital-human runtime stub smoke" \
  "$STATIC_LOG_DIR/digital-human-runtime-stub-smoke.log" \
  "RUN_ID='${RUN_ID}-runtime-stub' OUTPUT_ROOT='$OUTPUT_DIR/digital-human-runtime-stub-smoke' DERIVED_DATA_PATH='$OUTPUT_DIR/DerivedDataRuntimeStubSmoke' '$SCRIPT_DIR/run-digital-human-runtime-stub-smoke.sh'"

run_shell_step \
  "Tencent backend PCM-drive mock UIQA smoke" \
  "$STATIC_LOG_DIR/tencent-backend-pcm-drive-mock-smoke.log" \
  "RUN_ID='${RUN_ID}-pcm-drive' OUTPUT_ROOT='$OUTPUT_DIR/tencent-backend-pcm-drive-mock-smoke' DERIVED_DATA_PATH='$OUTPUT_DIR/DerivedDataPCMDriveMockSmoke' '$SCRIPT_DIR/run-tencent-backend-pcm-drive-mock-smoke.sh'"

run_shell_step \
  "Static release regression without recursive Phase 1 gate" \
  "$STATIC_LOG_DIR/release-regression-static.log" \
  "RUN_TENCENT_DIGITAL_HUMAN_PHASE1_NON_DEVICE_GATE=0 RUN_STANDARD_BUILD=0 RUN_SIMULATOR_SMOKE=0 RUN_ECHO_DELAYED_REPLY_NOTIFICATION_SMOKE=0 RUN_ID='${RUN_ID}-release-regression' OUTPUT_ROOT='$OUTPUT_DIR/release-regression' '$SCRIPT_DIR/run-release-regression.sh'"

run_step \
  "iOS Debug simulator build" \
  "$OUTPUT_DIR/build-debug-simulator.log" \
  xcodebuild \
    -workspace DreamJourney.xcworkspace \
    -scheme DreamJourney \
    -configuration Debug \
    -destination "generic/platform=iOS Simulator" \
    -derivedDataPath "$DERIVED_DATA_PATH" \
    build

run_step \
  "Git diff whitespace check" \
  "$STATIC_LOG_DIR/git-diff-check.log" \
  git diff --check

cat >> "$REPORT_PATH" <<EOF

## Evidence

- Command log: \`commands.log\`
- Static guard logs: \`static-guards/\`
- Runtime stub smoke: \`digital-human-runtime-stub-smoke/${RUN_ID}-runtime-stub/\`
- PCM-drive mock smoke: \`tencent-backend-pcm-drive-mock-smoke/${RUN_ID}-pcm-drive/\`
- Static release regression: \`release-regression/${RUN_ID}-release-regression/\`
- Build log: \`build-debug-simulator.log\`

## Boundary

No true-device validation was run by this gate. Real-device sound, Tencent rendered lip movement, interruption, and microphone recovery still require a separate true-device pass.

EOF

echo "Tencent digital-human Phase 1 non-device gate completed: $REPORT_PATH"

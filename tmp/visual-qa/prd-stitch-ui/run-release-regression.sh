#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../../.." && pwd)"
WORKSPACE_ROOT="$(cd "$ROOT_DIR/.." && pwd)"
BACKEND_ROOT="${BACKEND_ROOT:-$WORKSPACE_ROOT/DreamJourneyBackend}"

RUN_ID="${RUN_ID:-$(date +%Y%m%d-%H%M%S)-release-regression}"
OUTPUT_ROOT="${OUTPUT_ROOT:-$ROOT_DIR/tmp/visual-qa/prd-stitch-ui/release-regression}"
OUTPUT_DIR="$OUTPUT_ROOT/$RUN_ID"
REPORT_PATH="$OUTPUT_DIR/report.md"
COMMAND_LOG="$OUTPUT_DIR/commands.log"
BUILD_LOG="$OUTPUT_DIR/build-debug.log"
STATIC_LOG_DIR="$OUTPUT_DIR/static-guards"

RUN_STANDARD_BUILD="${RUN_STANDARD_BUILD:-1}"
RUN_SIMULATOR_SMOKE="${RUN_SIMULATOR_SMOKE:-1}"
RUN_ECHO_DELAYED_REPLY_NOTIFICATION_SMOKE="${RUN_ECHO_DELAYED_REPLY_NOTIFICATION_SMOKE:-1}"
RUN_BACKEND_ENV_SMOKE="${RUN_BACKEND_ENV_SMOKE:-0}"
RELEASE_HANDOFF_MODE="${RELEASE_HANDOFF_MODE:-0}"
if [[ "$RELEASE_HANDOFF_MODE" == "1" ]]; then
  # Release handoff mode forces release-like backend acceptance; do not allow
  # RUN_RELEASE_LIKE_BACKEND=0 to bypass the handoff backend gate.
  RUN_RELEASE_LIKE_BACKEND=1
else
  RUN_RELEASE_LIKE_BACKEND="${RUN_RELEASE_LIKE_BACKEND:-0}"
fi

mkdir -p "$STATIC_LOG_DIR"
touch "$COMMAND_LOG"

run_step() {
  local name="$1"
  shift
  local log_path="$1"
  shift

  echo "== $name ==" | tee -a "$COMMAND_LOG"
  echo "$*" >> "$COMMAND_LOG"
  "$@" > "$log_path" 2>&1
}

append_report_header() {
  cat > "$REPORT_PATH" <<EOF
# Release Regression

Run ID: \`$RUN_ID\`

## Configuration

- Standard iOS build: \`$RUN_STANDARD_BUILD\`
- Archive -> Echo simulator smoke: \`$RUN_SIMULATOR_SMOKE\`
- Echo delayed reply notification smoke: \`$RUN_ECHO_DELAYED_REPLY_NOTIFICATION_SMOKE\`
- Backend environment smoke: \`$RUN_BACKEND_ENV_SMOKE\`
- Release handoff mode: \`$RELEASE_HANDOFF_MODE\`
- Release-like FastAPI/Postgres backend: \`$RUN_RELEASE_LIKE_BACKEND\`
- Backend root: \`$BACKEND_ROOT\`

## Scope

- Backend unit/FastAPI smoke, if the sibling backend repo is present.
- Static PRD/UI/release guard scripts.
- iOS Debug simulator build, unless \`RUN_STANDARD_BUILD=0\`.
- Core Archive -> Echo simulator smoke, unless \`RUN_SIMULATOR_SMOKE=0\`.
- Echo delayed reply persistence/local-notification smoke, unless \`RUN_ECHO_DELAYED_REPLY_NOTIFICATION_SMOKE=0\`.
- Optional backend environment smoke when \`RUN_BACKEND_ENV_SMOKE=1\` and backend URL/token are configured.
- Optional release-like Postgres backend acceptance when \`RUN_RELEASE_LIKE_BACKEND=1\`.
- Release handoff mode forces release-like backend acceptance and cannot be disabled by \`RUN_RELEASE_LIKE_BACKEND=0\`.

EOF
}

append_report_footer() {
  cat >> "$REPORT_PATH" <<EOF
## Evidence

- Command log: \`commands.log\`
- Static guard logs: \`static-guards/\`
- Standard build log: \`build-debug.log\`
- Archive -> Echo smoke: \`archive-to-echo-smoke/$RUN_ID/\`
- Echo delayed reply notification smoke: \`echo-delayed-reply-notification-smoke/$RUN_ID/\`
- Backend env smoke: \`backend-env-smoke/$RUN_ID/\`
- Release-like backend acceptance: \`release-like-backend/$RUN_ID/\`

EOF
}

append_report_header

cd "$ROOT_DIR"

if [[ -d "$BACKEND_ROOT" ]]; then
  run_step \
    "Backend verify" \
    "$STATIC_LOG_DIR/backend-verify.log" \
    bash -lc "cd '$BACKEND_ROOT' && BACKEND_API_TOKEN= BACKEND_BASE_URL= ./scripts/verify_backend.sh"
else
  echo "Backend repo missing at $BACKEND_ROOT; skipping backend verify." | tee "$STATIC_LOG_DIR/backend-verify.log"
fi

run_step "Python QA scripts compile" "$STATIC_LOG_DIR/python-qa-compile.log" \
  python3 -m py_compile \
    "$SCRIPT_DIR/backend-auth-token-contract-check.py" \
    "$SCRIPT_DIR/backend-integration-contract-check.py" \
    "$SCRIPT_DIR/backend-postgres-persistence-check.py"

for guard in \
  release-feature-matrix-check.swift \
  prd-coverage-matrix-check.swift \
  prd-full-feature-closure-decisions-check.swift \
  echo-state-machine-runtime-check.swift \
  echo-waiting-reply-policy-check.swift \
  echo-delayed-reply-notification-check.swift \
  echo-delayed-reply-push-contract-check.swift \
  echo-delayed-reply-dispatch-contract-check.swift \
  phase0-backend-alignment-check.swift \
  backend-voice-runtime-contract-check.swift \
  release-like-backend-acceptance-check.swift \
  backend-env-smoke-check.swift \
  backend-contract-gap-check.swift \
  care-snapshot-backend-state-fixtures-check.swift \
  login-password-contract-check.swift \
  profile-settings-save-state-check.swift \
  profile-account-fields-check.swift \
  profile-password-change-check.swift \
  profile-care-public-placeholder-check.swift \
  archive-ownership-visibility-check.swift \
  archive-analysis-disclaimer-check.swift \
  archive-sync-error-recovery-check.swift \
  archive-feature-card-ia-check.swift \
  archive-audio-ia-release-check.swift \
  archive-audio-lifecycle-smoke-check.swift \
  true-device-archive-audio-acceptance-check.swift \
  archive-media-backend-contract-check.swift \
  archive-media-upload-intent-contract-check.swift \
  final-visual-qa-package-check.swift \
  release-qa-package-check.swift
do
  run_step "Swift guard $guard" "$STATIC_LOG_DIR/${guard%.swift}.log" \
    swift "$SCRIPT_DIR/$guard" "$ROOT_DIR"
done

run_step "iOS git diff --check" "$STATIC_LOG_DIR/ios-diff-check.log" \
  git diff --check

if [[ -d "$BACKEND_ROOT/.git" ]]; then
  run_step "Backend git diff --check" "$STATIC_LOG_DIR/backend-diff-check.log" \
    bash -lc "cd '$BACKEND_ROOT' && git diff --check"
fi

if [[ "$RUN_STANDARD_BUILD" == "1" ]]; then
  run_step "iOS Debug simulator build" "$BUILD_LOG" \
    xcodebuild \
      -workspace DreamJourney.xcworkspace \
      -scheme DreamJourney \
      -configuration Debug \
      -sdk iphonesimulator \
      -destination 'generic/platform=iOS Simulator' \
      -derivedDataPath "$OUTPUT_DIR/DerivedData" \
      CODE_SIGNING_ALLOWED=NO \
      build
else
  echo "Skipped by RUN_STANDARD_BUILD=0" > "$BUILD_LOG"
fi

if [[ "$RUN_SIMULATOR_SMOKE" == "1" ]]; then
  RUN_ID="$RUN_ID" \
  OUTPUT_ROOT="$OUTPUT_DIR/archive-to-echo-smoke" \
  DERIVED_DATA_PATH="$OUTPUT_DIR/DerivedDataArchiveToEchoSmoke" \
  "$SCRIPT_DIR/run-archive-to-echo-smoke.sh"
else
  mkdir -p "$OUTPUT_DIR/archive-to-echo-smoke/$RUN_ID"
  echo "Skipped by RUN_SIMULATOR_SMOKE=0" > "$OUTPUT_DIR/archive-to-echo-smoke/$RUN_ID/skipped.txt"
fi

if [[ "$RUN_ECHO_DELAYED_REPLY_NOTIFICATION_SMOKE" == "1" ]]; then
  RUN_ID="$RUN_ID" \
  OUTPUT_ROOT="$OUTPUT_DIR/echo-delayed-reply-notification-smoke" \
  DERIVED_DATA_PATH="$OUTPUT_DIR/DerivedDataEchoDelayedReplyNotificationSmoke" \
  "$SCRIPT_DIR/run-echo-delayed-reply-notification-smoke.sh"
else
  mkdir -p "$OUTPUT_DIR/echo-delayed-reply-notification-smoke/$RUN_ID"
  echo "Skipped by RUN_ECHO_DELAYED_REPLY_NOTIFICATION_SMOKE=0" > "$OUTPUT_DIR/echo-delayed-reply-notification-smoke/$RUN_ID/skipped.txt"
fi

if [[ "$RUN_BACKEND_ENV_SMOKE" == "1" ]]; then
  [[ -n "${BACKEND_BASE_URL:-}" ]] || {
    echo "BACKEND_BASE_URL is required for RUN_BACKEND_ENV_SMOKE=1" >&2
    exit 1
  }
  [[ -n "${BACKEND_API_TOKEN:-}" ]] || {
    echo "BACKEND_API_TOKEN is required for RUN_BACKEND_ENV_SMOKE=1" >&2
    exit 1
  }
  RUN_ID="$RUN_ID" \
  OUTPUT_ROOT="$OUTPUT_DIR/backend-env-smoke" \
  "$SCRIPT_DIR/run-backend-env-smoke.sh"
else
  mkdir -p "$OUTPUT_DIR/backend-env-smoke/$RUN_ID"
  echo "Skipped by RUN_BACKEND_ENV_SMOKE=0" > "$OUTPUT_DIR/backend-env-smoke/$RUN_ID/skipped.txt"
fi

if [[ "$RUN_RELEASE_LIKE_BACKEND" == "1" ]]; then
  RUN_ID="$RUN_ID" \
  OUTPUT_ROOT="$OUTPUT_DIR/release-like-backend" \
  "$SCRIPT_DIR/run-release-like-backend-acceptance.sh"
else
  mkdir -p "$OUTPUT_DIR/release-like-backend/$RUN_ID"
  echo "Skipped by RUN_RELEASE_LIKE_BACKEND=0" > "$OUTPUT_DIR/release-like-backend/$RUN_ID/skipped.txt"
fi

append_report_footer

echo "[release-regression] Report: $REPORT_PATH"
echo "[release-regression] Command log: $COMMAND_LOG"

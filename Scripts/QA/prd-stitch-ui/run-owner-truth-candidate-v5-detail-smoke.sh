#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../../.." && pwd)"

DERIVED_DATA_PATH="${DERIVED_DATA_PATH:-$ROOT_DIR/tmp/visual-qa/product-v4/DerivedDataOwnerTruthCandidateV5Detail}"
OUTPUT_ROOT="${OUTPUT_ROOT:-$ROOT_DIR/tmp/visual-qa/product-v4/owner-truth-candidate-v5-detail}"
RUN_ID="${RUN_ID:-$(date +%Y%m%d-%H%M%S)}"
OUTPUT_DIR="$OUTPUT_ROOT/$RUN_ID"
INSTALL_OUTPUT_DIR="$OUTPUT_DIR/install"
RUNTIME_LOG="$OUTPUT_DIR/runtime.log"
DETAIL_RUNTIME_LOG="$OUTPUT_DIR/detail-runtime.log"
STRUCTURED_PREVIEW_RUNTIME_LOG="$OUTPUT_DIR/structured-preview-runtime.log"
RESULT_COPY_PATH="$OUTPUT_DIR/owner-truth-candidate-related-group-uiqa-result.json"
DETAIL_SCREENSHOT_PATH="$OUTPUT_DIR/01-owner-truth-candidate-v5-detail.png"
STRUCTURED_PREVIEW_SCREENSHOT_PATH="$OUTPUT_DIR/02-owner-truth-candidate-structured-group-preview.png"
LOG_WAIT_TIMEOUT="${LOG_WAIT_TIMEOUT:-60}"

mkdir -p "$OUTPUT_DIR"
cd "$ROOT_DIR"

fail() {
  printf '[owner-truth-candidate-v5-detail] %s\n' "$*" >&2
  [[ -f "$RUNTIME_LOG" ]] && tail -80 "$RUNTIME_LOG" >&2 || true
  exit 1
}

OUTPUT_DIR="$INSTALL_OUTPUT_DIR" \
DERIVED_DATA_PATH="$DERIVED_DATA_PATH" \
LOCAL_BUNDLE_ID="${LOCAL_BUNDLE_ID:-com.yxj.dreamjourney.app}" \
LOCAL_DEVELOPMENT_TEAM="${LOCAL_DEVELOPMENT_TEAM:-2BTR77V3R8}" \
bash "$ROOT_DIR/Scripts/QA/prd-stitch-ui/run-installable-simulator-uiqa.sh"

# shellcheck disable=SC1090
source "$INSTALL_OUTPUT_DIR/install.env"
RESULT_FILE="$DATA_CONTAINER/Documents/owner-truth-candidate-related-group-uiqa-result.json"
rm -f "$RESULT_FILE"
xcrun simctl terminate "$SIMULATOR_UDID" "$BUNDLE_ID" >/dev/null 2>&1 || true
sleep 2

CONSOLE_PID=""
cleanup() {
  [[ -n "$CONSOLE_PID" ]] && kill "$CONSOLE_PID" >/dev/null 2>&1 || true
}
trap cleanup EXIT

xcrun simctl launch --console "$SIMULATOR_UDID" "$BUNDLE_ID" \
  DJUITestBypassLogin \
  DJEnableOwnerTruthCandidateReviewQA \
  DJRunOwnerTruthCandidateRelatedGroupSmoke > "$RUNTIME_LOG" 2>&1 &
CONSOLE_PID="$!"

deadline=$((SECONDS + LOG_WAIT_TIMEOUT))
while [[ ! -s "$RESULT_FILE" ]]; do
  (( SECONDS < deadline )) || fail "Timed out waiting for the V5 review result"
  sleep 1
done

cp "$RESULT_FILE" "$RESULT_COPY_PATH"
cat "$RESULT_FILE"
printf '\n'

for assertion in \
  completed \
  v5DetailVisible \
  v5RevisionVisible \
  v5FacetsVisible \
  v5ActionsBound \
  previewShowsCorrectedStatement \
  previewShowsStructuredTimeChange \
  previewShowsStructuredConfidenceChange \
  previewShowsRejectedNoWrite \
  atomicCommitAppliedOnce; do
  grep -Eq "\"$assertion\"[[:space:]]*:[[:space:]]*true" "$RESULT_FILE" \
    || fail "$assertion was not true"
done

xcrun simctl terminate "$SIMULATOR_UDID" "$BUNDLE_ID" >/dev/null 2>&1 || true
CONSOLE_PID=""
sleep 2

xcrun simctl launch --console "$SIMULATOR_UDID" "$BUNDLE_ID" \
  DJUITestBypassLogin \
  DJEnableOwnerTruthCandidateReviewQA \
  DJRunOwnerTruthCandidateRelatedGroupSmoke \
  DJOwnerTruthCandidateRelatedGroupUIQAHoldAtV5Detail > "$DETAIL_RUNTIME_LOG" 2>&1 &
CONSOLE_PID="$!"
sleep 3
xcrun simctl io "$SIMULATOR_UDID" screenshot "$DETAIL_SCREENSHOT_PATH" >/dev/null
xcrun simctl terminate "$SIMULATOR_UDID" "$BUNDLE_ID" >/dev/null 2>&1 || true
CONSOLE_PID=""
sleep 2

xcrun simctl launch --console "$SIMULATOR_UDID" "$BUNDLE_ID" \
  DJUITestBypassLogin \
  DJEnableOwnerTruthCandidateReviewQA \
  DJRunOwnerTruthCandidateRelatedGroupSmoke \
  DJOwnerTruthCandidateRelatedGroupUIQAHoldAtStructuredGroupPreview > "$STRUCTURED_PREVIEW_RUNTIME_LOG" 2>&1 &
CONSOLE_PID="$!"
deadline=$((SECONDS + LOG_WAIT_TIMEOUT))
while ! grep -q "holding at structured group preview" "$STRUCTURED_PREVIEW_RUNTIME_LOG"; do
  (( SECONDS < deadline )) || fail "Structured group preview did not become visible"
  sleep 1
done
xcrun simctl io "$SIMULATOR_UDID" screenshot "$STRUCTURED_PREVIEW_SCREENSHOT_PATH" >/dev/null
xcrun simctl terminate "$SIMULATOR_UDID" "$BUNDLE_ID" >/dev/null 2>&1 || true
CONSOLE_PID=""

printf '[owner-truth-candidate-v5-detail] Result: %s\n' "$RESULT_COPY_PATH"
printf '[owner-truth-candidate-v5-detail] Runtime log: %s\n' "$RUNTIME_LOG"
printf '[owner-truth-candidate-v5-detail] Screenshot: %s\n' "$DETAIL_SCREENSHOT_PATH"
printf '[owner-truth-candidate-v5-detail] Structured preview: %s\n' "$STRUCTURED_PREVIEW_SCREENSHOT_PATH"

#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../../.." && pwd)"

DERIVED_DATA_PATH="${DERIVED_DATA_PATH:-$ROOT_DIR/tmp/visual-qa/product-v4/DerivedDataOwnerTruthCandidateInboxSmoke}"
OUTPUT_ROOT="${OUTPUT_ROOT:-$ROOT_DIR/tmp/visual-qa/product-v4/owner-truth-candidate-inbox-smoke}"
RUN_ID="${RUN_ID:-$(date +%Y%m%d-%H%M%S)}"
OUTPUT_DIR="$OUTPUT_ROOT/$RUN_ID"
INSTALL_OUTPUT_DIR="$OUTPUT_DIR/install"
RUNTIME_LOG="$OUTPUT_DIR/runtime.log"
OS_LOG="$OUTPUT_DIR/oslog.log"
SCREENSHOT_PATH="$OUTPUT_DIR/01-owner-truth-candidate-inbox.png"
RESULT_COPY_PATH="$OUTPUT_DIR/owner-truth-candidate-inbox-uiqa-result.json"
COMPLETION_PATTERN="OwnerTruthCandidateInboxSmoke completed"
LOG_WAIT_TIMEOUT="${LOG_WAIT_TIMEOUT:-45}"

mkdir -p "$OUTPUT_DIR"
cd "$ROOT_DIR"

fail() {
  echo "[owner-truth-candidate-inbox-smoke] $*" >&2
  [[ -f "$RUNTIME_LOG" ]] && tail -80 "$RUNTIME_LOG" >&2 || true
  [[ -f "$OS_LOG" ]] && tail -80 "$OS_LOG" >&2 || true
  exit 1
}

echo "[owner-truth-candidate-inbox-smoke] Building and installing UIQA app..."
OUTPUT_DIR="$INSTALL_OUTPUT_DIR" \
DERIVED_DATA_PATH="$DERIVED_DATA_PATH" \
LOCAL_BUNDLE_ID="${LOCAL_BUNDLE_ID:-com.yxj.dreamjourney.app}" \
LOCAL_DEVELOPMENT_TEAM="${LOCAL_DEVELOPMENT_TEAM:-2BTR77V3R8}" \
bash "$ROOT_DIR/Scripts/QA/prd-stitch-ui/run-installable-simulator-uiqa.sh"

# shellcheck disable=SC1090
source "$INSTALL_OUTPUT_DIR/install.env"
RESULT_FILE="$DATA_CONTAINER/Documents/owner-truth-candidate-inbox-uiqa-result.json"
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

echo "[owner-truth-candidate-inbox-smoke] Launching auto-run harness..."
xcrun simctl launch --console "$SIMULATOR_UDID" "$BUNDLE_ID" \
  DJUITestBypassLogin \
  DJEnableOwnerTruthCandidateReviewQA \
  DJRunOwnerTruthCandidateInboxSmoke > "$RUNTIME_LOG" 2>&1 &
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
cat "$RESULT_FILE"
echo

grep -Eq '"completed"[[:space:]]*:[[:space:]]*true' "$RESULT_FILE" || fail "Candidate Inbox UIQA did not complete."
grep -Eq '"qaGateEnabled"[[:space:]]*:[[:space:]]*true' "$RESULT_FILE" || fail "QA gate should be enabled."
grep -Eq '"candidateVisible"[[:space:]]*:[[:space:]]*true' "$RESULT_FILE" || fail "Candidate row should render."
grep -Eq '"candidatePreviewVisible"[[:space:]]*:[[:space:]]*true' "$RESULT_FILE" || fail "Candidate preview should render."
grep -Eq '"reviewActionsAvailable"[[:space:]]*:[[:space:]]*true' "$RESULT_FILE" || fail "Review actions should be available."
grep -Eq '"reviewSubmitted"[[:space:]]*:[[:space:]]*true' "$RESULT_FILE" || fail "Candidate review should submit."
grep -Eq '"reviewAction"[[:space:]]*:[[:space:]]*"acceptBatch"' "$RESULT_FILE" || fail "Candidate review action should be acceptBatch."
grep -Eq '"terminalDecision"[[:space:]]*:[[:space:]]*"accepted"' "$RESULT_FILE" || fail "Candidate receipt should be accepted."
grep -Eq '"receiptConsumed"[[:space:]]*:[[:space:]]*true' "$RESULT_FILE" || fail "Candidate receipt should be consumed."
grep -Eq '"memoryVersionCreated"[[:space:]]*:[[:space:]]*true' "$RESULT_FILE" || fail "Accepted Candidate should create a MemoryVersion."
grep -Eq '"formalMemoryPresentationVisible"[[:space:]]*:[[:space:]]*true' "$RESULT_FILE" || fail "Confirmed Candidate should present its formal memory state."
grep -Eq '"formalMemoryPresentationText"[[:space:]]*:[[:space:]]*".*正式记忆' "$RESULT_FILE" || fail "Formal memory presentation wording drifted."
grep -Eq '"candidateRemovedAfterReview"[[:space:]]*:[[:space:]]*true' "$RESULT_FILE" || fail "Reviewed Candidate should leave the pending Inbox."
grep -Eq '"batchCandidateCount"[[:space:]]*:[[:space:]]*2' "$RESULT_FILE" || fail "Batch smoke should render two batch candidates."
grep -Eq '"batchAcceptedCount"[[:space:]]*:[[:space:]]*2' "$RESULT_FILE" || fail "Batch smoke should accept every selected candidate."
grep -Eq '"batchSequenceCompleted"[[:space:]]*:[[:space:]]*true' "$RESULT_FILE" || fail "Batch smoke should complete the sequential review path."
grep -Eq '"reviewHistoryVisible"[[:space:]]*:[[:space:]]*true' "$RESULT_FILE" || fail "Review history should render after terminal decisions."
grep -Eq '"reviewHistoryCount"[[:space:]]*:[[:space:]]*2' "$RESULT_FILE" || fail "Review history should preserve both reviewed candidates."
grep -Eq '"reviewHistoryTerminalStatesVisible"[[:space:]]*:[[:space:]]*true' "$RESULT_FILE" || fail "Review history should expose terminal decisions."
grep -Eq '"reviewHistoryMemoryStateVisible"[[:space:]]*:[[:space:]]*true' "$RESULT_FILE" || fail "Review history should expose formal memory activation state."
grep -Eq '"memoryVersionHistoryVisible"[[:space:]]*:[[:space:]]*true' "$RESULT_FILE" || fail "Activated review history should open formal MemoryVersion history."
grep -Eq '"memoryVersionHistoryCount"[[:space:]]*:[[:space:]]*1' "$RESULT_FILE" || fail "MemoryVersion history should preserve the current version."
grep -Eq '"memoryVersionHistoryCurrentStateVisible"[[:space:]]*:[[:space:]]*true' "$RESULT_FILE" || fail "MemoryVersion history should identify exactly one current version."
grep -Eq '"launchArgument"[[:space:]]*:[[:space:]]*"DJEnableOwnerTruthCandidateReviewQA"' "$RESULT_FILE" || fail "QA launch argument drifted."

xcrun simctl io "$SIMULATOR_UDID" screenshot "$SCREENSHOT_PATH" >/dev/null
xcrun simctl terminate "$SIMULATOR_UDID" "$BUNDLE_ID" >/dev/null 2>&1 || true

echo "[owner-truth-candidate-inbox-smoke] Build log: $INSTALL_OUTPUT_DIR/build.log"
echo "[owner-truth-candidate-inbox-smoke] Runtime log: $RUNTIME_LOG"
echo "[owner-truth-candidate-inbox-smoke] OS log: $OS_LOG"
echo "[owner-truth-candidate-inbox-smoke] Result: $RESULT_COPY_PATH"
echo "[owner-truth-candidate-inbox-smoke] Screenshot: $SCREENSHOT_PATH"

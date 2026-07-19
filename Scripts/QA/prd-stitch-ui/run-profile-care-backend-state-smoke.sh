#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../../.." && pwd)"
WORKSPACE_ROOT="$(cd "$ROOT_DIR/.." && pwd)"
BACKEND_ROOT="${BACKEND_ROOT:-$WORKSPACE_ROOT/DreamJourneyBackend}"

SCHEME="${SCHEME:-DreamJourney}"
CONFIGURATION="${CONFIGURATION:-Debug}"
SIMULATOR_NAME="${SIMULATOR_NAME:-iPhone 16}"
LOCAL_QA_BUNDLE_ID="${LOCAL_QA_BUNDLE_ID:-com.yxj.dreamjourney.app}"
LOCAL_QA_TEAM_ID="${LOCAL_QA_TEAM_ID:-2BTR77V3R8}"
SWIFT_ACTIVE_COMPILATION_CONDITIONS='DEBUG UI_QA_SIMULATOR'
DERIVED_DATA_PATH="${DERIVED_DATA_PATH:-$ROOT_DIR/tmp/visual-qa/prd-stitch-ui/DerivedDataProfileCareBackendStateSmoke}"
FAILURE_DERIVED_DATA_PATH="${FAILURE_DERIVED_DATA_PATH:-${DERIVED_DATA_PATH}Failure}"
OUTPUT_ROOT="${OUTPUT_ROOT:-$ROOT_DIR/tmp/visual-qa/prd-stitch-ui/profile-care-backend-state-smoke}"
RUN_ID="${RUN_ID:-$(date +%Y%m%d-%H%M%S)}"
MARKER="${MARKER:-$RUN_ID}"
OUTPUT_DIR="$OUTPUT_ROOT/$RUN_ID"
INSTALL_DIR="$OUTPUT_DIR/install"
FAILURE_INSTALL_DIR="$OUTPUT_DIR/failure-retry-install"
FIXTURE_RESULT="$OUTPUT_DIR/backend-care-state-uiqa-fixtures-result.json"
FIXTURE_LOG="$OUTPUT_DIR/backend-care-state-uiqa-fixtures.log"
SESSION_FIXTURE="$OUTPUT_DIR/backend-care-auth-sessions.json"
CLEANUP_MANIFEST="$OUTPUT_DIR/backend-care-auth-cleanup.json"
CLEANUP_RESULT="$OUTPUT_DIR/backend-care-auth-cleanup-result.json"
RESULT_COPY_PATH="$OUTPUT_DIR/profile-care-backend-state-smoke-result.json"
FAILURE_RESULT_COPY_PATH="$OUTPUT_DIR/profile-care-backend-failure-retry-smoke-result.json"
PRIVATE_XCCONFIG="$OUTPUT_DIR/backend-private.xcconfig"
UNREACHABLE_PRIVATE_XCCONFIG="$OUTPUT_DIR/backend-unreachable.xcconfig"
FAILURE_RUNTIME_LOG="$OUTPUT_DIR/failure-retry-runtime.log"
FAILURE_OS_LOG="$OUTPUT_DIR/failure-retry-oslog.log"
FAILURE_SCREENSHOT_PATH="$OUTPUT_DIR/04-profile-care-backend-failure-retry.png"
COMPLETION_PATTERN="ProfileCareBackendStateSmoke completed"
FAILURE_COMPLETION_PATTERN="ProfileCareBackendFailureRetrySmoke completed"
LOG_WAIT_TIMEOUT="${LOG_WAIT_TIMEOUT:-90}"
RUN_PROFILE_CARE_FAILURE_RETRY_ONLY="${RUN_PROFILE_CARE_FAILURE_RETRY_ONLY:-0}"

# The authenticated fixture runs inside the existing backend API container.
# The database address is intentionally never exported to the local host.
BACKEND_REMOTE_HOST="${BACKEND_REMOTE_HOST:-miao-server}"
BACKEND_REMOTE_ROOT="${BACKEND_REMOTE_ROOT:-/opt/services/dreamjourney/DreamJourneyBackend}"
REMOTE_RUN_SUFFIX="$(printf '%s' "$RUN_ID" | tr -cd 'A-Za-z0-9_-')"
REMOTE_RUN_DIR="/tmp/dreamjourney-profile-care-uiqa-${REMOTE_RUN_SUFFIX:-run}"
REMOTE_SCRIPT_PATH="$REMOTE_RUN_DIR/backend-care-state-uiqa-fixtures.py"
REMOTE_CONTAINER_PREFIX="/tmp/dreamjourney-profile-care-uiqa-${REMOTE_RUN_SUFFIX:-run}"
REMOTE_CONTAINER_SCRIPT="${REMOTE_CONTAINER_PREFIX}-fixtures.py"
REMOTE_CONTAINER_SESSION="${REMOTE_CONTAINER_PREFIX}-sessions.json"
REMOTE_CONTAINER_CLEANUP="${REMOTE_CONTAINER_PREFIX}-cleanup.json"
REMOTE_FIXTURE_SEEDED=0
REMOTE_FIXTURE_CLEANED=0

mkdir -p "$OUTPUT_DIR"
chmod 700 "$OUTPUT_DIR"
cd "$ROOT_DIR"

CONSOLE_PID=""
OSLOG_PID=""

shell_quote() {
  printf '%q' "$1"
}

remote_exec() {
  ssh -o BatchMode=yes -o ConnectTimeout=10 "$BACKEND_REMOTE_HOST" "$1"
}

stop_log_streams() {
  if [[ -n "$CONSOLE_PID" ]]; then
    kill "$CONSOLE_PID" >/dev/null 2>&1 || true
    CONSOLE_PID=""
  fi
  if [[ -n "$OSLOG_PID" ]]; then
    kill "$OSLOG_PID" >/dev/null 2>&1 || true
    OSLOG_PID=""
  fi
}

cleanup_remote_fixture() {
  if [[ "$REMOTE_FIXTURE_CLEANED" == "1" ]]; then
    return 0
  fi

  if [[ "$REMOTE_FIXTURE_SEEDED" == "1" ]] && remote_exec "cd $(shell_quote "$BACKEND_REMOTE_ROOT") && sudo docker compose exec -T api test -f $(shell_quote "$REMOTE_CONTAINER_CLEANUP")" >/dev/null 2>&1; then
    if ! remote_exec "cd $(shell_quote "$BACKEND_REMOTE_ROOT") && sudo docker compose exec -T -e DREAMJOURNEY_BACKEND_ROOT=/app api python $(shell_quote "$REMOTE_CONTAINER_SCRIPT") clean $(shell_quote "$REMOTE_CONTAINER_CLEANUP")" > "$CLEANUP_RESULT" 2>> "$FIXTURE_LOG"; then
      return 1
    fi
    if ! python3 - "$CLEANUP_RESULT" <<'PY'
import json
import sys

payload = json.load(open(sys.argv[1], encoding="utf-8"))
if payload.get("completed") is not True or payload.get("cleanupVerification") != "fixtureUsersAbsent":
    raise SystemExit(f"cleanup contract mismatch: {payload}")
if not payload.get("cleanedUserIds"):
    raise SystemExit(f"cleanup user ids missing: {payload}")
PY
    then
      return 1
    fi
  fi
  REMOTE_FIXTURE_SEEDED=0
  if ! remote_exec "cd $(shell_quote "$BACKEND_REMOTE_ROOT") && sudo docker compose exec -T api rm -f $(shell_quote "$REMOTE_CONTAINER_SCRIPT") $(shell_quote "$REMOTE_CONTAINER_SESSION") $(shell_quote "$REMOTE_CONTAINER_CLEANUP") >/dev/null 2>&1 || true; sudo rm -rf $(shell_quote "$REMOTE_RUN_DIR")" >> "$FIXTURE_LOG" 2>&1; then
    return 1
  fi
  REMOTE_FIXTURE_CLEANED=1
}

cleanup() {
  stop_log_streams
  cleanup_remote_fixture || true
  rm -f "$PRIVATE_XCCONFIG" "$UNREACHABLE_PRIVATE_XCCONFIG" "$SESSION_FIXTURE" "$CLEANUP_MANIFEST"
}
trap cleanup EXIT

fail() {
  echo "[profile-care-backend-state-smoke] $*" >&2
  if [[ -f "$FIXTURE_LOG" ]]; then
    echo "[profile-care-backend-state-smoke] fixture log tail:" >&2
    tail -80 "$FIXTURE_LOG" >&2 || true
  fi
  for log_path in "$OUTPUT_DIR"/runtime-*.log "$OUTPUT_DIR"/oslog-*.log "$FAILURE_RUNTIME_LOG" "$FAILURE_OS_LOG"; do
    if [[ -f "$log_path" ]]; then
      echo "[profile-care-backend-state-smoke] $(basename "$log_path") tail:" >&2
      tail -80 "$log_path" >&2 || true
    fi
  done
  stop_log_streams
  exit 1
}

finalize_remote_fixture_cleanup() {
  cleanup_remote_fixture || fail "Authenticated backend care fixture cleanup failed."
}

resolve_deployed_backend_config() {
  python3 - "$BACKEND_ROOT" "${DEPLOYED_BACKEND_ACCESS_DOC:-}" <<'PY'
import re
import sys
from pathlib import Path

backend_root = Path(sys.argv[1])
explicit = sys.argv[2].strip()
candidates = []
if explicit:
    candidates.append(Path(explicit))
candidates.extend([
    backend_root / "private/deployed-backend-access.md",
    backend_root / "deployed-backend-access.md",
])

for path in candidates:
    if not path.exists():
        continue
    content = path.read_text(encoding="utf-8")
    for line in content.splitlines():
        stripped = line.strip()
        if stripped.startswith("DreamJourneyBackendBaseURL="):
            print(stripped.split("=", 1)[1].strip().strip("'\""))
            raise SystemExit(0)
    match = re.search(r"https?://[A-Za-z0-9._~:/?#\[\]@!$&'()*+,;=%-]+", content)
    if match:
        print(match.group(0).rstrip("/,"))
        raise SystemExit(0)
raise SystemExit(0)
PY
}

BACKEND_BASE_URL="${BACKEND_BASE_URL:-$(resolve_deployed_backend_config || true)}"
[[ -n "$BACKEND_BASE_URL" ]] || fail "BACKEND_BASE_URL is required. Export it or provide deployed-backend-access.md."

seed_remote_authenticated_fixture() {
  local fixture_command="${1:-seed}"
  local remote_command
  remote_command="mkdir -p $(shell_quote "$REMOTE_RUN_DIR") && chmod 700 $(shell_quote "$REMOTE_RUN_DIR")"
  remote_exec "$remote_command" >> "$FIXTURE_LOG" 2>&1 || fail "Unable to prepare remote QA fixture directory."
  scp -q "$SCRIPT_DIR/backend-care-state-uiqa-fixtures.py" "$BACKEND_REMOTE_HOST:$REMOTE_SCRIPT_PATH" >> "$FIXTURE_LOG" 2>&1 || fail "Unable to upload remote QA fixture helper."

  # Mark cleanup as pending before the fixture command. If a later container
  # copy fails after Postgres users were created, the manifest is still used
  # by the EXIT trap to remove them rather than leaving QA data behind.
  REMOTE_FIXTURE_SEEDED=1
  remote_command="cd $(shell_quote "$BACKEND_REMOTE_ROOT") && container_id=\$(sudo docker compose ps -q api) && test -n \"\$container_id\" && sudo docker cp $(shell_quote "$REMOTE_SCRIPT_PATH") \"\$container_id:$(shell_quote "$REMOTE_CONTAINER_SCRIPT")\" && sudo docker compose exec -T -e DREAMJOURNEY_BACKEND_ROOT=/app api python $(shell_quote "$REMOTE_CONTAINER_SCRIPT") $(shell_quote "$fixture_command") $(shell_quote "$BACKEND_BASE_URL") $(shell_quote "$MARKER") $(shell_quote "$REMOTE_CONTAINER_SESSION") $(shell_quote "$REMOTE_CONTAINER_CLEANUP") > $(shell_quote "$REMOTE_RUN_DIR/fixture-result.json") 2> $(shell_quote "$REMOTE_RUN_DIR/fixture.log") && sudo docker cp \"\$container_id:$(shell_quote "$REMOTE_CONTAINER_SESSION")\" $(shell_quote "$REMOTE_RUN_DIR/session-fixture.json") && sudo docker cp \"\$container_id:$(shell_quote "$REMOTE_CONTAINER_CLEANUP")\" $(shell_quote "$REMOTE_RUN_DIR/cleanup-manifest.json") && sudo chown \$(id -u):\$(id -g) $(shell_quote "$REMOTE_RUN_DIR/session-fixture.json") $(shell_quote "$REMOTE_RUN_DIR/cleanup-manifest.json") && chmod 600 $(shell_quote "$REMOTE_RUN_DIR/session-fixture.json") $(shell_quote "$REMOTE_RUN_DIR/cleanup-manifest.json")"
  if ! remote_exec "$remote_command" >> "$FIXTURE_LOG" 2>&1; then
    remote_exec "tail -80 $(shell_quote "$REMOTE_RUN_DIR/fixture.log")" >> "$FIXTURE_LOG" 2>&1 || true
    fail "Authenticated backend care fixture seed failed."
  fi
  scp -q "$BACKEND_REMOTE_HOST:$REMOTE_RUN_DIR/fixture-result.json" "$FIXTURE_RESULT" >> "$FIXTURE_LOG" 2>&1 || fail "Unable to download fixture result."
  scp -q "$BACKEND_REMOTE_HOST:$REMOTE_RUN_DIR/session-fixture.json" "$SESSION_FIXTURE" >> "$FIXTURE_LOG" 2>&1 || fail "Unable to download session fixture."
  scp -q "$BACKEND_REMOTE_HOST:$REMOTE_RUN_DIR/cleanup-manifest.json" "$CLEANUP_MANIFEST" >> "$FIXTURE_LOG" 2>&1 || fail "Unable to download cleanup manifest."
  chmod 600 "$SESSION_FIXTURE" "$CLEANUP_MANIFEST"
}

read_fixture_value() {
  local key="$1"
  python3 - "$FIXTURE_RESULT" "$key" <<'PY'
import json
import sys

payload = json.load(open(sys.argv[1], encoding="utf-8"))
value = payload.get(sys.argv[2])
if not value:
    raise SystemExit(f"missing fixture value: {sys.argv[2]}")
print(value)
PY
}

write_simulator_session_fixture() {
  local data_container="$1"
  local user_id="$2"
  python3 - "$SESSION_FIXTURE" "$data_container/Documents/uiqa-profile-care-auth-session.json" "$user_id" <<'PY'
import json
import os
import sys
from pathlib import Path

source = Path(sys.argv[1])
destination = Path(sys.argv[2])
user_id = sys.argv[3]
payload = json.loads(source.read_text(encoding="utf-8"))
users = payload.get("users") or []
selected = next((item for item in users if item.get("userId") == user_id), None)
if not isinstance(selected, dict):
    raise SystemExit("session fixture user missing")
required = ("userId", "phone", "nickname", "auth")
if any(not selected.get(key) for key in required):
    raise SystemExit("session fixture user is incomplete")
destination.parent.mkdir(parents=True, exist_ok=True)
destination.write_text(json.dumps({key: selected[key] for key in required}, ensure_ascii=False), encoding="utf-8")
os.chmod(destination, 0o600)
PY
}

wait_for_result() {
  local result_file="$1"
  local completion_pattern="$2"
  local runtime_log="$3"
  local os_log="$4"
  local deadline=$((SECONDS + LOG_WAIT_TIMEOUT))
  while [[ ! -s "$result_file" ]] && ! grep -q "$completion_pattern" "$runtime_log" "$os_log" 2>/dev/null; do
    if (( SECONDS >= deadline )); then
      fail "Timed out waiting for $completion_pattern"
    fi
    sleep 1
  done
  [[ -s "$result_file" ]] || fail "App did not write $(basename "$result_file")"
}

assert_state_case() {
  local result_path="$1"
  local case_name="$2"
  python3 - "$result_path" "$FIXTURE_RESULT" "$case_name" <<'PY'
import json
import sys

result_path, fixture_path, case_name = sys.argv[1:4]
result = json.load(open(result_path, encoding="utf-8"))
fixture = json.load(open(fixture_path, encoding="utf-8"))
expected = {
    "active": ("profileCareStateAvailable", "backend"),
    "empty": ("profileCareStateEmpty", "backendErrorFallback"),
    "stale": ("profileCareStateStale", "backend"),
}
if case_name not in expected:
    raise SystemExit(f"unsupported case: {case_name}")
if result.get("completed") is not True:
    raise SystemExit(f"profile care state case did not complete: {result}")
if result.get("backendConfigured") is not True or result.get("profileTabSelected") is not True:
    raise SystemExit(f"backend/profile state invalid: {result}")
states = result.get("states") or []
if len(states) != 1 or states[0].get("name") != case_name:
    raise SystemExit(f"state case mismatch: {result}")
state = states[0]
expected_state, expected_source = expected[case_name]
if state.get("profileState") != expected_state or state.get("source") != expected_source:
    raise SystemExit(f"state contract mismatch: {state}")
if (state.get("dashboard") or {}).get("dashboardState") != expected_state:
    raise SystemExit(f"dashboard state mismatch: {state}")
if case_name == "active":
    if state.get("profileRetryVisible") is not False:
        raise SystemExit(f"active state should not show retry: {state}")
    if state.get("rawRiskLevel") != fixture.get("careActiveRiskLevel"):
        raise SystemExit(f"active raw risk mismatch: {state}")
    retry = result.get("retry") or {}
    expected_user_id = fixture.get("activeUserId")
    if not (
        retry.get("retryActionFired") is True
        and retry.get("retryButtonVisible") is True
        and retry.get("retryInitialState") == "profileCareStateStale"
        and retry.get("retryIntermediateState") == "profileCareStateLoading"
        and "正在重新同步关怀信号" in str(retry.get("retryIntermediateSyncCaption") or "")
        and retry.get("retryFinalState") == "profileCareStateAvailable"
        and retry.get("retryRequestCountAdvanced") is True
        and retry.get("retryRequestedUserId") == expected_user_id
    ):
        raise SystemExit(f"active retry contract mismatch: {retry}")
else:
    if state.get("profileRetryVisible") is not True or state.get("profileRetryActionTitle") != "重新同步":
        raise SystemExit(f"retry affordance mismatch: {state}")
PY
}

aggregate_state_results() {
  python3 - "$FIXTURE_RESULT" "$RESULT_COPY_PATH" "$OUTPUT_DIR" <<'PY'
import json
import sys
from pathlib import Path

fixture_path, output_path, output_dir = map(Path, sys.argv[1:4])
fixture = json.loads(fixture_path.read_text(encoding="utf-8"))
records = []
retry = {}
for name in ("active", "empty", "stale"):
    path = output_dir / f"profile-care-backend-state-{name}-smoke-result.json"
    record = json.loads(path.read_text(encoding="utf-8"))
    records.extend(record.get("states") or [])
    if name == "active":
        retry = record.get("retry") or {}
payload = {
    "completed": True,
    "backendConfigured": True,
    "profileTabSelected": True,
    "failedStateCoveredByLocalSmoke": True,
    "states": records,
    "retry": retry,
    "fixtureHealthStore": fixture.get("healthStore"),
}
output_path.write_text(json.dumps(payload, ensure_ascii=False, sort_keys=True), encoding="utf-8")
PY
}

run_failure_retry_case() {
  local active_user_id="$1"

  echo "[profile-care-backend-state-smoke] Building UIQA app with unreachable backend for failure retry..."
  OUTPUT_DIR="$FAILURE_INSTALL_DIR" \
  DERIVED_DATA_PATH="$FAILURE_DERIVED_DATA_PATH" \
  SCHEME="$SCHEME" \
  SIMULATOR_NAME="$SIMULATOR_NAME" \
  CONFIGURATION="$CONFIGURATION" \
  SWIFT_ACTIVE_COMPILATION_CONDITIONS="$SWIFT_ACTIVE_COMPILATION_CONDITIONS" \
  LOCAL_BUNDLE_ID="$LOCAL_QA_BUNDLE_ID" \
  LOCAL_DEVELOPMENT_TEAM="$LOCAL_QA_TEAM_ID" \
  XCCONFIG_PATH="$UNREACHABLE_PRIVATE_XCCONFIG" \
    "$ROOT_DIR/Scripts/QA/prd-stitch-ui/run-installable-simulator-uiqa.sh"

  # shellcheck disable=SC1090
  source "$FAILURE_INSTALL_DIR/install.env"
  FAILURE_RESULT_FILE="$DATA_CONTAINER/Documents/profile-care-backend-failure-retry-smoke-result.json"
  rm -f "$FAILURE_RESULT_FILE"
  write_simulator_session_fixture "$DATA_CONTAINER" "$active_user_id" || fail "Unable to prepare failure retry simulator session fixture."
  touch "$FAILURE_RUNTIME_LOG" "$FAILURE_OS_LOG"
  xcrun simctl spawn "$SIMULATOR_UDID" log stream \
    --style compact \
    --level debug \
    --predicate 'process == "DreamJourney"' > "$FAILURE_OS_LOG" 2>&1 &
  OSLOG_PID="$!"
  sleep 1
  echo "[profile-care-backend-state-smoke] Launching failure retry harness..."
  xcrun simctl launch --console "$SIMULATOR_UDID" "$BUNDLE_ID" \
    DJUITestBypassLogin \
    DJEnableProfileHiddenBranches \
    DJRunProfileCareBackendFailureRetrySmoke \
    "DJCareFailureRetryUserId=$active_user_id" \
    "DJCareSessionUserId=$active_user_id" > "$FAILURE_RUNTIME_LOG" 2>&1 &
  CONSOLE_PID="$!"
  wait_for_result "$FAILURE_RESULT_FILE" "$FAILURE_COMPLETION_PATTERN" "$FAILURE_RUNTIME_LOG" "$FAILURE_OS_LOG"
  cp "$FAILURE_RESULT_FILE" "$FAILURE_RESULT_COPY_PATH"

  python3 - "$FAILURE_RESULT_COPY_PATH" "$FIXTURE_RESULT" <<'PY'
import json
import sys

result = json.load(open(sys.argv[1], encoding="utf-8"))
fixture = json.load(open(sys.argv[2], encoding="utf-8"))
if result.get("completed") is not True:
    raise SystemExit(f"profile care backend failure retry smoke did not complete: {result}")
if result.get("backendConfigured") is not True or result.get("profileTabSelected") is not True:
    raise SystemExit(f"backend/profile state invalid: {result}")
retry = result.get("retry") or {}
if not (
    retry.get("retryActionFired") is True
    and retry.get("retryButtonVisible") is True
    and retry.get("retryFailureInitialState") == "profileCareStateFailed"
    and retry.get("retryIntermediateState") == "profileCareStateLoading"
    and "正在重新同步关怀信号" in str(retry.get("retryIntermediateSyncCaption") or "")
    and retry.get("retryFailureFinalState") == "profileCareStateFailed"
    and retry.get("retryFailureFinalRetryVisible") is True
    and retry.get("retryRequestCountAdvanced") is True
    and retry.get("retryRequestedUserId") == fixture.get("activeUserId")
):
    raise SystemExit(f"failure retry contract mismatch: {retry}")
PY

  xcrun simctl io "$SIMULATOR_UDID" screenshot "$FAILURE_SCREENSHOT_PATH" >/dev/null
  xcrun simctl terminate "$SIMULATOR_UDID" "$BUNDLE_ID" >/dev/null 2>&1 || true
  stop_log_streams
}

run_state_case() {
  local case_name="$1"
  local user_id="$2"
  local screenshot_path="$3"
  local result_file="$DATA_CONTAINER/Documents/profile-care-backend-state-smoke-result.json"
  local result_copy="$OUTPUT_DIR/profile-care-backend-state-${case_name}-smoke-result.json"
  local runtime_log="$OUTPUT_DIR/runtime-${case_name}.log"
  local os_log="$OUTPUT_DIR/oslog-${case_name}.log"

  rm -f "$result_file"
  write_simulator_session_fixture "$DATA_CONTAINER" "$user_id" || fail "Unable to prepare $case_name simulator session fixture."
  touch "$runtime_log" "$os_log"
  xcrun simctl spawn "$SIMULATOR_UDID" log stream \
    --style compact \
    --level debug \
    --predicate 'process == "DreamJourney"' > "$os_log" 2>&1 &
  OSLOG_PID="$!"
  sleep 1
  echo "[profile-care-backend-state-smoke] Launching $case_name care state harness..."
  xcrun simctl launch --console "$SIMULATOR_UDID" "$BUNDLE_ID" \
    DJUITestBypassLogin \
    DJEnableProfileHiddenBranches \
    DJRunProfileCareBackendStateSmoke \
    "DJCareCaseName=$case_name" \
    "DJCareStateUserId=$user_id" \
    "DJCareSessionUserId=$user_id" > "$runtime_log" 2>&1 &
  CONSOLE_PID="$!"
  wait_for_result "$result_file" "$COMPLETION_PATTERN" "$runtime_log" "$os_log"
  cp "$result_file" "$result_copy"
  assert_state_case "$result_copy" "$case_name"
  xcrun simctl io "$SIMULATOR_UDID" screenshot "$screenshot_path" >/dev/null
  xcrun simctl terminate "$SIMULATOR_UDID" "$BUNDLE_ID" >/dev/null 2>&1 || true
  stop_log_streams
}

if [[ "$RUN_PROFILE_CARE_FAILURE_RETRY_ONLY" == "1" ]]; then
  seed_remote_authenticated_fixture "seed-failure-retry"
else
  seed_remote_authenticated_fixture
fi

ACTIVE_USER_ID="$(read_fixture_value activeUserId)"

if [[ "$RUN_PROFILE_CARE_FAILURE_RETRY_ONLY" != "1" ]]; then
  EMPTY_USER_ID="$(read_fixture_value missingUserId)"
  STALE_USER_ID="$(read_fixture_value staleUserId)"
fi

python3 - "$PRIVATE_XCCONFIG" "$BACKEND_BASE_URL" <<'PY'
import sys
from pathlib import Path

path, base_url = sys.argv[1:3]
escaped_base_url = base_url.replace("//", "/$()/")
Path(path).write_text("DREAMJOURNEY_BACKEND_BASE_URL = " + escaped_base_url + "\n", encoding="utf-8")
PY
chmod 600 "$PRIVATE_XCCONFIG"

python3 - "$UNREACHABLE_PRIVATE_XCCONFIG" <<'PY'
import sys
from pathlib import Path

Path(sys.argv[1]).write_text(
    "DREAMJOURNEY_BACKEND_BASE_URL = http:/$()/127.0.0.1:9\n",
    encoding="utf-8",
)
PY
chmod 600 "$UNREACHABLE_PRIVATE_XCCONFIG"

if [[ "$RUN_PROFILE_CARE_FAILURE_RETRY_ONLY" == "1" ]]; then
  run_failure_retry_case "$ACTIVE_USER_ID"
  finalize_remote_fixture_cleanup
  echo "[profile-care-backend-state-smoke] Failure retry result: $FAILURE_RESULT_COPY_PATH"
  echo "[profile-care-backend-state-smoke] Screenshot: $FAILURE_SCREENSHOT_PATH"
  echo "[profile-care-backend-state-smoke] Cleanup result: $CLEANUP_RESULT"
  exit 0
fi

echo "[profile-care-backend-state-smoke] Building UIQA app with deployed backend settings..."
OUTPUT_DIR="$INSTALL_DIR" \
DERIVED_DATA_PATH="$DERIVED_DATA_PATH" \
SCHEME="$SCHEME" \
SIMULATOR_NAME="$SIMULATOR_NAME" \
CONFIGURATION="$CONFIGURATION" \
SWIFT_ACTIVE_COMPILATION_CONDITIONS="$SWIFT_ACTIVE_COMPILATION_CONDITIONS" \
LOCAL_BUNDLE_ID="$LOCAL_QA_BUNDLE_ID" \
LOCAL_DEVELOPMENT_TEAM="$LOCAL_QA_TEAM_ID" \
XCCONFIG_PATH="$PRIVATE_XCCONFIG" \
  "$ROOT_DIR/Scripts/QA/prd-stitch-ui/run-installable-simulator-uiqa.sh"

# shellcheck disable=SC1090
source "$INSTALL_DIR/install.env"
run_state_case active "$ACTIVE_USER_ID" "$OUTPUT_DIR/01-profile-care-backend-active.png"
run_state_case empty "$EMPTY_USER_ID" "$OUTPUT_DIR/02-profile-care-backend-empty.png"
run_state_case stale "$STALE_USER_ID" "$OUTPUT_DIR/03-profile-care-backend-stale.png"
aggregate_state_results

run_failure_retry_case "$ACTIVE_USER_ID"
finalize_remote_fixture_cleanup

echo "[profile-care-backend-state-smoke] Fixture result: $FIXTURE_RESULT"
echo "[profile-care-backend-state-smoke] Result: $RESULT_COPY_PATH"
echo "[profile-care-backend-state-smoke] Failure retry result: $FAILURE_RESULT_COPY_PATH"
echo "[profile-care-backend-state-smoke] Cleanup result: $CLEANUP_RESULT"
echo "[profile-care-backend-state-smoke] Screenshots: $OUTPUT_DIR/01-profile-care-backend-active.png, $OUTPUT_DIR/02-profile-care-backend-empty.png, $OUTPUT_DIR/03-profile-care-backend-stale.png, $FAILURE_SCREENSHOT_PATH"

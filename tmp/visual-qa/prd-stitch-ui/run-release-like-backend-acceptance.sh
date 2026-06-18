#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../../.." && pwd)"
WORKSPACE_ROOT="$(cd "$ROOT_DIR/.." && pwd)"
BACKEND_ROOT="${BACKEND_ROOT:-$WORKSPACE_ROOT/DreamJourneyBackend}"

RUN_ID="${RUN_ID:-$(date +%Y%m%d-%H%M%S)-release-like-backend}"
MARKER="${MARKER:-$RUN_ID}"
USER_ID="${USER_ID:-release_like_${RUN_ID//[^A-Za-z0-9]/_}}"
IOS_USER_ID="${IOS_USER_ID:-user_9999}"
BACKEND_BASE_URL="${BACKEND_BASE_URL:-}"
BACKEND_API_TOKEN="${BACKEND_API_TOKEN:-}"
OUTPUT_ROOT="${OUTPUT_ROOT:-$ROOT_DIR/tmp/visual-qa/prd-stitch-ui/release-like-backend-acceptance}"
OUTPUT_DIR="$OUTPUT_ROOT/$RUN_ID"
SEED_RESULT="$OUTPUT_DIR/postgres-persistence-seed.json"
SEED_LOG="$OUTPUT_DIR/postgres-persistence-seed.log"
VERIFY_RESULT="$OUTPUT_DIR/postgres-persistence-verify.json"
VERIFY_LOG="$OUTPUT_DIR/postgres-persistence-verify.log"
IOS_SMOKE_ROOT="$OUTPUT_DIR/ios-backend-env-smoke"
IOS_SMOKE_LOG="$OUTPUT_DIR/ios-backend-env-smoke.log"
BACKEND_VERIFY_LOG="$OUTPUT_DIR/backend-verify.log"
REPORT_PATH="$OUTPUT_DIR/report.md"
LOCAL_ENV_CREATED=0
USED_COMPOSE=0

mkdir -p "$OUTPUT_DIR"

fail() {
  echo "[release-like-backend] $*" >&2
  local token_status="not configured"
  if [[ -n "$BACKEND_API_TOKEN" ]]; then
    token_status="configured, value intentionally omitted"
  fi
  cat > "$REPORT_PATH" <<EOF
# Release-like Backend Acceptance

Run ID: \`$RUN_ID\`

Status: blocked

Reason: $*

## Environment

- Backend root: \`$BACKEND_ROOT\`
- Backend base URL: \`${BACKEND_BASE_URL:-not configured}\`
- Backend API token: $token_status
- Docker available: $(command -v docker >/dev/null 2>&1 && echo yes || echo no)
- Postgres mode required: yes

## Expected Next Run

Provide either:

1. \`BACKEND_BASE_URL\` and \`BACKEND_API_TOKEN\` for a deployed FastAPI/Postgres backend, or
2. Docker Compose plus the sibling \`DreamJourneyBackend\` repo so this script can run the local Postgres stack.

Then run:

\`\`\`bash
RUN_ID=$RUN_ID tmp/visual-qa/prd-stitch-ui/run-release-like-backend-acceptance.sh
\`\`\`
EOF
  exit 1
}

read_env_value() {
  local key="$1"
  local env_file="$2"
  python3 - "$key" "$env_file" <<'PY'
import sys

key, path = sys.argv[1:3]
try:
    lines = open(path, "r", encoding="utf-8").read().splitlines()
except FileNotFoundError:
    raise SystemExit(0)

for line in lines:
    stripped = line.strip()
    if not stripped or stripped.startswith("#") or "=" not in stripped:
        continue
    name, value = stripped.split("=", 1)
    if name.strip() == key:
        print(value.strip().strip("'\""))
        break
PY
}

wait_for_health() {
  local deadline=$((SECONDS + 90))
  while true; do
    if python3 - "$BACKEND_BASE_URL" <<'PY' >/dev/null 2>&1
import json
import sys
import urllib.request

base_url = sys.argv[1].rstrip("/")
with urllib.request.urlopen(f"{base_url}/health", timeout=3) as response:
    payload = json.loads(response.read().decode("utf-8"))
if payload.get("status") != "ok" or payload.get("store") != "postgres":
    raise SystemExit(1)
PY
    then
      return 0
    fi
    if (( SECONDS >= deadline )); then
      return 1
    fi
    sleep 2
  done
}

prepare_local_compose_backend() {
  [[ -d "$BACKEND_ROOT" ]] || fail "Backend repo not found at $BACKEND_ROOT"
  command -v docker >/dev/null 2>&1 || fail "Docker is not available; cannot start the local FastAPI/Postgres stack."
  (cd "$BACKEND_ROOT" && docker compose version >/dev/null) || fail "docker compose is not available."

  if [[ ! -f "$BACKEND_ROOT/.env" ]]; then
    [[ -f "$BACKEND_ROOT/.env.example" ]] || fail "Backend .env is missing and .env.example was not found."
    cp "$BACKEND_ROOT/.env.example" "$BACKEND_ROOT/.env"
    LOCAL_ENV_CREATED=1
  fi

  if ! grep -q '^BACKEND_API_TOKEN=' "$BACKEND_ROOT/.env"; then
    local generated_token
    generated_token="$(python3 - <<'PY'
import secrets
print("dj-local-release-like-" + secrets.token_urlsafe(24))
PY
)"
    printf '\nBACKEND_API_TOKEN=%s\n' "$generated_token" >> "$BACKEND_ROOT/.env"
  fi

  BACKEND_API_TOKEN="${BACKEND_API_TOKEN:-$(read_env_value BACKEND_API_TOKEN "$BACKEND_ROOT/.env")}"
  [[ -n "$BACKEND_API_TOKEN" ]] || fail "BACKEND_API_TOKEN is still empty after preparing backend .env."

  BACKEND_BASE_URL="${BACKEND_BASE_URL:-http://127.0.0.1:3100}"
  USED_COMPOSE=1

  (cd "$BACKEND_ROOT" && docker compose up -d --build)
  wait_for_health || fail "Timed out waiting for local Postgres backend health at $BACKEND_BASE_URL."
}

restart_backend_for_persistence_check() {
  if (( USED_COMPOSE == 1 )); then
    (cd "$BACKEND_ROOT" && docker compose restart api)
    wait_for_health || fail "Timed out waiting for backend health after API restart."
    return 0
  fi

  if [[ -n "${RELEASE_LIKE_RESTART_COMMAND:-}" ]]; then
    bash -lc "$RELEASE_LIKE_RESTART_COMMAND"
    wait_for_health || fail "Timed out waiting for backend health after RELEASE_LIKE_RESTART_COMMAND."
    return 0
  fi

  echo "[release-like-backend] RELEASE_LIKE_RESTART_COMMAND not set; external backend persistence check will verify read-after-write without API restart."
}

if [[ -z "$BACKEND_BASE_URL" ]]; then
  prepare_local_compose_backend
else
  [[ -n "$BACKEND_API_TOKEN" ]] || fail "BACKEND_API_TOKEN is required when BACKEND_BASE_URL is provided."
  wait_for_health || fail "Backend health is not ok/postgres at $BACKEND_BASE_URL."
fi

echo "[release-like-backend] Running backend verify script..."
if [[ -d "$BACKEND_ROOT" ]]; then
  if ! (cd "$BACKEND_ROOT" && BACKEND_API_TOKEN= ./scripts/verify_backend.sh) > "$BACKEND_VERIFY_LOG" 2>&1; then
    fail "Backend verify script failed. See \`backend-verify.log\`."
  fi
fi

echo "[release-like-backend] Seeding Postgres persistence contract..."
if ! python3 "$SCRIPT_DIR/backend-postgres-persistence-check.py" \
    "$BACKEND_BASE_URL" \
    "$USER_ID" \
    "$BACKEND_API_TOKEN" \
    "$MARKER" \
    seed > "$SEED_RESULT" 2> "$SEED_LOG"; then
  fail "Postgres persistence seed contract failed. See \`postgres-persistence-seed.log\`."
fi

echo "[release-like-backend] Restarting/verifying backend persistence boundary..."
restart_backend_for_persistence_check
if ! python3 "$SCRIPT_DIR/backend-postgres-persistence-check.py" \
    "$BACKEND_BASE_URL" \
    "$USER_ID" \
    "$BACKEND_API_TOKEN" \
    "$MARKER" \
    verify > "$VERIFY_RESULT" 2> "$VERIFY_LOG"; then
  fail "Postgres persistence verify contract failed. See \`postgres-persistence-verify.log\`."
fi

echo "[release-like-backend] Running iOS backend environment smoke..."
if ! BACKEND_BASE_URL="$BACKEND_BASE_URL" \
    BACKEND_API_TOKEN="$BACKEND_API_TOKEN" \
    USER_ID="$IOS_USER_ID" \
    RUN_ID="$RUN_ID" \
    OUTPUT_ROOT="$IOS_SMOKE_ROOT" \
    "$SCRIPT_DIR/run-backend-env-smoke.sh" > "$IOS_SMOKE_LOG" 2>&1; then
  fail "iOS backend environment smoke failed. See \`ios-backend-env-smoke.log\`."
fi

cat > "$REPORT_PATH" <<EOF
# Release-like Backend Acceptance

Run ID: \`$RUN_ID\`

Status: passed

## Environment

- Backend root: \`$BACKEND_ROOT\`
- Backend base URL: \`$BACKEND_BASE_URL\`
- Backend API token: configured, value intentionally omitted
- Store requirement: Postgres
- Local compose used: \`$USED_COMPOSE\`
- Local .env created by this run: \`$LOCAL_ENV_CREATED\`
- Persistence user ID: \`$USER_ID\`
- iOS smoke user ID: \`$IOS_USER_ID\`

## Scope

- Verifies \`/health\` reports \`store=postgres\`.
- Seeds Archive, KB, Family, and Care data with a stable marker.
- Restarts API when local compose or \`RELEASE_LIKE_RESTART_COMMAND\` is available.
- Verifies the same marker is still readable after the restart boundary.
- Runs the existing iOS \`run-backend-env-smoke.sh\` against the same backend and token.

## Evidence

- Seed result: \`postgres-persistence-seed.json\`
- Verify result: \`postgres-persistence-verify.json\`
- Backend verify log: \`backend-verify.log\`
- iOS backend smoke directory: \`ios-backend-env-smoke/$RUN_ID\`
- iOS backend smoke log: \`ios-backend-env-smoke.log\`

EOF

echo "[release-like-backend] Seed result: $SEED_RESULT"
echo "[release-like-backend] Verify result: $VERIFY_RESULT"
echo "[release-like-backend] iOS smoke root: $IOS_SMOKE_ROOT/$RUN_ID"
echo "[release-like-backend] Report: $REPORT_PATH"

#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT_DIR"

PYTHON_BIN="${PYTHON:-python3}"
source Scripts/backend_env.sh
PYTHON_BIN="$BACKEND_PYTHON"

echo "== Backend unittest =="
STORE_BACKEND=memory PYTHONPATH="$BACKEND_PYTHONPATH" "$PYTHON_BIN" -m unittest discover "$DREAMJOURNEY_BACKEND_REPO/tests"

echo "== Backend py_compile =="
"$PYTHON_BIN" -m compileall -q "$DREAMJOURNEY_BACKEND_REPO/app" "$DREAMJOURNEY_BACKEND_REPO/tests"

echo "== Backend deployment files =="
test -f "$DREAMJOURNEY_BACKEND_REPO/Dockerfile"
test -f "$DREAMJOURNEY_BACKEND_REPO/docker-compose.yml"
test -f "$DREAMJOURNEY_BACKEND_REPO/.env.example"
test -f "$DREAMJOURNEY_BACKEND_REPO/requirements.txt"
grep -q "psycopg" "$DREAMJOURNEY_BACKEND_REPO/requirements.txt"

echo "== Backend FastAPI smoke =="
if "$PYTHON_BIN" - <<'PY' >/dev/null 2>&1
import fastapi
import httpx
PY
then
  STORE_BACKEND=memory PYTHONPATH="$BACKEND_PYTHONPATH" "$PYTHON_BIN" - <<'PY'
from fastapi.testclient import TestClient
from app.main import app

client = TestClient(app)
health = client.get("/health")
assert health.status_code == 200, health.text
assert health.json()["status"] == "ok"
config = client.get("/config/runtime")
assert config.status_code == 200, config.text
assert "capabilities" in config.json()
print("FastAPI smoke verification passed")
PY
else
  echo "FastAPI/httpx not installed locally; skipping runtime smoke. Docker image installs requirements.txt."
fi

echo "== Backend diff --check =="
git -C "$DREAMJOURNEY_BACKEND_REPO" diff --check
git -C "$DREAMJOURNEY_BACKEND_REPO" diff --cached --check
git diff --check -- docs/backend Scripts/verify_backend.sh Scripts/backend_env.sh Scripts/backend_repo.py .gitignore
git diff --cached --check -- docs/backend Scripts/verify_backend.sh Scripts/backend_env.sh Scripts/backend_repo.py .gitignore

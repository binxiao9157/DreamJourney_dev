#!/usr/bin/env bash

resolve_dreamjourney_backend_repo() {
  local root_dir="$1"
  local candidates=()

  if [ -n "${DREAMJOURNEY_BACKEND_REPO:-}" ]; then
    candidates+=("$DREAMJOURNEY_BACKEND_REPO")
  fi
  candidates+=("$root_dir/DreamJourneyBackend")
  candidates+=("$HOME/Documents/Codex/Video/DreamJourneyBackend")

  local candidate
  for candidate in "${candidates[@]}"; do
    if [ -f "$candidate/app/main.py" ] && [ -d "$candidate/tests" ]; then
      (cd "$candidate" && pwd)
      return 0
    fi
  done

  {
    echo "DreamJourneyBackend repository not found."
    echo "Set DREAMJOURNEY_BACKEND_REPO=/path/to/DreamJourneyBackend."
    echo "Searched:"
    for candidate in "${candidates[@]}"; do
      echo "- $candidate"
    done
  } >&2
  return 1
}

DREAMJOURNEY_BACKEND_REPO="$(resolve_dreamjourney_backend_repo "$ROOT_DIR")"
export DREAMJOURNEY_BACKEND_REPO

BACKEND_PYTHON="${PYTHON:-python3}"
if [ -x "$DREAMJOURNEY_BACKEND_REPO/.venv/bin/python" ]; then
  BACKEND_PYTHON="$DREAMJOURNEY_BACKEND_REPO/.venv/bin/python"
fi
export BACKEND_PYTHON

BACKEND_PYTHONPATH="$DREAMJOURNEY_BACKEND_REPO${PYTHONPATH:+:$PYTHONPATH}"
export BACKEND_PYTHONPATH

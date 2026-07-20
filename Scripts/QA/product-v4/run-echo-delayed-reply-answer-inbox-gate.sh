#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
cd "$ROOT_DIR"

python3 Scripts/QA/product-v4/echo-delayed-reply-answer-inbox-static-check.py

echo "Echo delayed reply Answer Inbox gate passed"

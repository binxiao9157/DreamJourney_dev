#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"

python3 "$ROOT_DIR/Scripts/QA/product-v4/voice-clone-local-owner-scope-static-check.py"
python3 "$ROOT_DIR/Scripts/QA/product-v4/voice-tts-account-lease-check.py"

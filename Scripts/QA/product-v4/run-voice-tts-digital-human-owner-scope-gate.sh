#!/bin/bash

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"

bash "$ROOT/Scripts/QA/product-v4/run-voice-clone-local-owner-scope-gate.sh"
bash "$ROOT/Scripts/QA/product-v4/run-memoir-tts-cache-owner-scope-gate.sh"
bash "$ROOT/Scripts/QA/product-v4/run-digital-human-context-owner-scope-gate.sh"
python3 "$ROOT/Scripts/QA/product-v4/echo-runtime-account-lease-check.py"
python3 "$ROOT/Scripts/QA/product-v4/product-v4-digital-human-secure-path-check.py"
bash "$ROOT/Scripts/QA/product-v4/run-account-store-inventory-gate.sh"

echo "Voice/TTS/Digital Human owner-scope gate passed"

#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
cd "$ROOT_DIR"

python3 Scripts/QA/product-v4/voice-tts-dh-account-lifecycle-check.py
bash Scripts/QA/product-v4/run-voice-clone-local-owner-scope-gate.sh
bash Scripts/QA/product-v4/run-memoir-tts-cache-owner-scope-gate.sh
bash Scripts/QA/product-v4/run-digital-human-context-owner-scope-gate.sh

echo "PASS: Voice/TTS/DigitalHuman account lifecycle QA gate"

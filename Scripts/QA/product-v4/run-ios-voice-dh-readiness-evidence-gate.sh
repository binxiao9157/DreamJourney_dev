#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/../../.." && pwd)"
cd "$ROOT_DIR"

Scripts/QA/product-v4/run-ios-voice-dh-exit-disclosure-gate.sh
python3 Scripts/QA/product-v4/product-v4-voice-dh-readiness-evidence-check.py

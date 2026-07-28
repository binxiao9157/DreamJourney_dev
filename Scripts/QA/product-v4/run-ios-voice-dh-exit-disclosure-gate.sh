#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/../../.." && pwd)"
cd "$ROOT_DIR"

python3 Scripts/QA/product-v4/product-v4-voice-dh-exit-disclosure-check.py

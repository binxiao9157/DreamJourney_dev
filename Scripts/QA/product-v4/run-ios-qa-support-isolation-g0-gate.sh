#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"

cd "$ROOT_DIR"
python3 Scripts/QA/product-v4/product-v4-ios-qa-support-isolation-check.py
bash Scripts/QA/product-v4/run-ios-audio-owner-lease-gate.sh

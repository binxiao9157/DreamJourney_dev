#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
BUILD_DIR="${TMPDIR:-/tmp}/dreamjourney-v4-time-letter-notification-lifecycle"
cd "$ROOT_DIR"

mkdir -p "$BUILD_DIR"
swiftc -parse-as-library \
  "$ROOT_DIR/Scripts/QA/product-v4/time-letter-notification-lifecycle-model-smoke.swift" \
  -o "$BUILD_DIR/time-letter-notification-lifecycle-model-smoke"
"$BUILD_DIR/time-letter-notification-lifecycle-model-smoke"
python3 Scripts/QA/product-v4/time-letter-notification-lifecycle-static-check.py
Scripts/QA/product-v4/run-legacy-timer-callback-inventory-gate.sh
Scripts/QA/product-v4/run-message-notification-owner-scope-gate.sh

echo "TimeLetter notification lifecycle G0 gate passed"

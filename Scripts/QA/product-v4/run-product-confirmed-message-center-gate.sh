#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
cd "$ROOT_DIR"

python3 scripts/QA/product-v4/product-confirmed-message-center-check.py
swiftc \
  DreamJourney/Sources/Modules/Archive/InAppMessageCenter.swift \
  Scripts/QA/product-v4/in-app-message-owner-scope-model-smoke.swift \
  -o "${TMPDIR:-/tmp}/dreamjourney-pc-b4-message-center-smoke"
"${TMPDIR:-/tmp}/dreamjourney-pc-b4-message-center-smoke"

if [[ "${RUN_PRODUCT_CONFIRMED_MESSAGE_CENTER_UIQA:-0}" == "1" ]]; then
  bash Scripts/QA/product-v4/run-product-confirmed-message-center-uiqa-smoke.sh
fi

echo "PC-B4 message center gate passed"

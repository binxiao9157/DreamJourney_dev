#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"

python3 "$ROOT/Scripts/QA/product-v4/product-v4-ios-lifecycle-event-forwarding-check.py"
python3 "$ROOT/Scripts/QA/product-v4/product-v4-ios-lifecycle-consumer-inventory-check.py"
bash "$ROOT/Scripts/QA/product-v4/run-account-lifecycle-entrypoint-gate.sh"

#!/usr/bin/env bash
set -euo pipefail

# G0 inventory only. This validates value-free source metadata and does not
# schedule notifications, run a poll, send a heartbeat, or modify product UI.
ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"

python3 "$ROOT/Scripts/QA/product-v4/legacy-timer-callback-inventory-check.py"
python3 "$ROOT/Scripts/QA/product-v4/product-v4-current-handoff-check.py"

echo "iOS legacy timer/callback inventory G0 gate passed"

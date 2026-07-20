#!/usr/bin/env bash
set -euo pipefail

# G0-only cross-repository planning gate. It validates checked-in inventories
# and the conservative manifest; it does not inspect a live host or change any
# scheduler, notification, worker, Provider, route, credential, or UI state.
ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
BACKEND="$ROOT/../DreamJourneyBackend"

bash "$ROOT/Scripts/QA/product-v4/run-time-letter-notification-lifecycle-gate.sh"
bash "$BACKEND/scripts/run-backend-legacy-timer-callback-inventory-gate.sh"
python3 "$ROOT/Scripts/QA/product-v4/retirement-candidate-manifest-check.py"
python3 "$ROOT/Scripts/QA/product-v4/product-v4-current-handoff-check.py"

echo "WI-S1-02-10 retirement candidate manifest G0 gate passed"

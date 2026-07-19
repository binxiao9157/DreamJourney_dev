#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"

python3 "$ROOT/Scripts/QA/product-v4/product-v4-ios-voice-dh-client-port-check.py"

echo "iOS Voice/Digital Human typed client-port gate passed"

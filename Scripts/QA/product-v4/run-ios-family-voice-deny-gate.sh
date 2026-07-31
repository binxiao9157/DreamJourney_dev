#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"

python3 "$ROOT/Scripts/QA/product-v4/product-v4-ios-family-voice-deny-check.py"

echo "iOS family voice deny gate passed"

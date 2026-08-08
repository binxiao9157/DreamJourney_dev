#!/usr/bin/env bash
set -euo pipefail

# R4 non-device client gate. This validates only typed runtime/challenge state
# consumption and the public login boundary; it never contacts an SMS provider.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../../.." && pwd)"

cd "$ROOT_DIR"

python3 "$SCRIPT_DIR/product-v4-identity-challenge-client-check.py"
bash "$SCRIPT_DIR/run-identity-challenge-client-model-smoke.sh"
swift "$ROOT_DIR/Scripts/QA/prd-stitch-ui/login-password-contract-check.swift"

echo "Identity challenge R4 client gate passed"

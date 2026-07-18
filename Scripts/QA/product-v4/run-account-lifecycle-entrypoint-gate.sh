#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
cd "$ROOT_DIR"

python3 Scripts/QA/product-v4/account-lifecycle-entrypoint-static-check.py
bash Scripts/QA/product-v4/run-account-lifecycle-coordinator-gate.sh
bash Scripts/QA/product-v4/run-account-lifecycle-module-registry-gate.sh

echo "PASS: Product V4 account lifecycle entry-point gate"

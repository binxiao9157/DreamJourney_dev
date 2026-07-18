#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
cd "$ROOT_DIR"

python3 Scripts/QA/product-v4/product-v4-account-lifecycle-module-registry-check.py

echo "Product V4 account lifecycle module registry gate passed"

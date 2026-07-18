#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
PYTHON_BIN="${PYTHON_BIN:-python3}"

cd "$ROOT_DIR"
"$PYTHON_BIN" Scripts/QA/product-v4/owner-truth-schema-contract-check.py
"$PYTHON_BIN" Scripts/QA/product-v4/owner-truth-archive-compatibility-check.py
swift test

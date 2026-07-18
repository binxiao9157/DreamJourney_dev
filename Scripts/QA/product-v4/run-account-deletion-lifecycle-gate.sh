#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
cd "$ROOT_DIR"

xcrun swift Scripts/QA/product-v4/account-deletion-lifecycle-model-smoke.swift
python3 Scripts/QA/product-v4/account-deletion-lifecycle-static-check.py

bash Scripts/QA/product-v4/run-account-lifecycle-coordinator-gate.sh
bash Scripts/QA/product-v4/run-account-lifecycle-module-registry-gate.sh
bash Scripts/QA/product-v4/run-account-lifecycle-entrypoint-gate.sh

git diff --check -- \
  Scripts/QA/product-v4/account-deletion-lifecycle-model-smoke.swift \
  Scripts/QA/product-v4/account-deletion-lifecycle-static-check.py \
  Scripts/QA/product-v4/run-account-deletion-lifecycle-gate.sh

echo "PASS: WI-S0-01-08C account deletion lifecycle gate"

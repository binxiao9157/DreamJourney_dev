#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
cd "$ROOT_DIR"

python3 Scripts/QA/product-v4/account-explicit-draft-deletion-purge-check.py
bash Scripts/QA/product-v4/run-archive-local-storage-gate.sh
bash Scripts/QA/product-v4/run-account-private-media-store-gate.sh
bash Scripts/QA/product-v4/run-memoir-owner-storage-gate.sh
bash Scripts/QA/product-v4/run-memory-map-owner-storage-gate.sh

git diff --check -- \
  Scripts/QA/product-v4/account-explicit-draft-deletion-purge-check.py \
  Scripts/QA/product-v4/run-account-explicit-draft-deletion-purge-gate.sh

echo "PASS: WI-S0-01-08C explicit draft deletion purge gate"

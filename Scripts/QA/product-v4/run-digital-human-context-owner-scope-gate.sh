#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
cd "$ROOT_DIR"

python3 Scripts/QA/product-v4/digital-human-context-owner-scope-check.py

echo "Digital-human context owner-scope gate passed"

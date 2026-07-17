#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
cd "$ROOT_DIR"

python3 Scripts/QA/product-v4/product-v4-account-store-inventory-check.py
swift Scripts/QA/prd-stitch-ui/auth-session-ownership-shadow-check.swift
swift Scripts/QA/prd-stitch-ui/archive-ownership-visibility-check.swift
Scripts/QA/prd-stitch-ui/run-knowledge-semantic-cache-isolation-model-smoke.sh
Scripts/QA/prd-stitch-ui/run-family-authorization-freshness-model-smoke.sh
Scripts/QA/prd-stitch-ui/run-knowledge-widget-snapshot-store-model-smoke.sh
Scripts/QA/prd-stitch-ui/run-echo-trace-owner-isolation-model-smoke.sh

echo "Product V4 account store inventory gate passed"

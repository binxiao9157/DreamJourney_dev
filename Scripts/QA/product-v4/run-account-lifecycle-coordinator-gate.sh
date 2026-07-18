#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
BUILD_DIR="$(mktemp -d "${TMPDIR:-/tmp}/dreamjourney-account-lifecycle.XXXXXX")"
trap 'rm -rf "$BUILD_DIR"' EXIT

cd "$ROOT_DIR"

python3 Scripts/QA/product-v4/product-v4-account-lifecycle-coordinator-check.py

swiftc \
  Scripts/QA/product-v4/account-lifecycle-coordinator-model-smoke.swift \
  -o "$BUILD_DIR/account-lifecycle-coordinator-model-smoke"
"$BUILD_DIR/account-lifecycle-coordinator-model-smoke"

echo "PASS: Product V4 AccountLifecycleCoordinator QA gate"

#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
BUILD_DIR="$(mktemp -d "${TMPDIR:-/tmp}/dreamjourney-kblite-account-lease.XXXXXX")"
trap 'rm -rf "$BUILD_DIR"' EXIT

cd "$ROOT_DIR"

python3 Scripts/QA/product-v4/kblite-account-lease-check.py
swiftc \
  -parse-as-library \
  DreamJourney/Sources/App/AccountLease.swift \
  DreamJourney/Sources/App/AccountSessionActor.swift \
  Scripts/QA/product-v4/kblite-account-lease-model-smoke.swift \
  -o "$BUILD_DIR/kblite-account-lease-model-smoke"
"$BUILD_DIR/kblite-account-lease-model-smoke"

echo "KBLite AccountLease gate passed"

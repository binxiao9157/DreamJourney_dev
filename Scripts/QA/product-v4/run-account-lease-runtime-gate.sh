#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
BUILD_DIR="$(mktemp -d "${TMPDIR:-/tmp}/dreamjourney-account-lease.XXXXXX")"
trap 'rm -rf "$BUILD_DIR"' EXIT

cd "$ROOT_DIR"

python3 Scripts/QA/product-v4/product-v4-account-lease-runtime-check.py
swiftc \
  DreamJourney/Sources/App/AccountLease.swift \
  DreamJourney/Sources/App/AccountSessionActor.swift \
  Scripts/QA/product-v4/account-lease-runtime-model-smoke.swift \
  -o "$BUILD_DIR/account-lease-runtime-model-smoke"
"$BUILD_DIR/account-lease-runtime-model-smoke"

echo "Product V4 AccountLease runtime gate passed"

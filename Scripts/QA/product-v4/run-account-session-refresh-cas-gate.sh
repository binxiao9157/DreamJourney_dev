#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
BUILD_DIR="$(mktemp -d "${TMPDIR:-/tmp}/dreamjourney-account-refresh-cas.XXXXXX")"
trap 'rm -rf "$BUILD_DIR"' EXIT

cd "$ROOT_DIR"

python3 Scripts/QA/product-v4/product-v4-account-session-refresh-cas-check.py
swiftc \
  DreamJourney/Sources/App/AccountSessionActor.swift \
  Scripts/QA/product-v4/account-session-refresh-cas-model-smoke.swift \
  -o "$BUILD_DIR/account-session-refresh-cas-model-smoke"
"$BUILD_DIR/account-session-refresh-cas-model-smoke"

echo "Product V4 AccountSession refresh CAS gate passed"

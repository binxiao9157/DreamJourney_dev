#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
BUILD_DIR="$(mktemp -d "${TMPDIR:-/tmp}/dreamjourney-account-session-actor.XXXXXX")"
trap 'rm -rf "$BUILD_DIR"' EXIT

cd "$ROOT_DIR"

python3 Scripts/QA/product-v4/product-v4-account-session-actor-check.py
swiftc \
  DreamJourney/Sources/App/AccountSessionActor.swift \
  Scripts/QA/product-v4/account-session-actor-model-smoke.swift \
  -o "$BUILD_DIR/account-session-actor-model-smoke"
"$BUILD_DIR/account-session-actor-model-smoke"

echo "Product V4 AccountSessionActor gate passed"

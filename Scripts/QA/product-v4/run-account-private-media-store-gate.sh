#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
BUILD_DIR="$(mktemp -d "${TMPDIR:-/tmp}/dreamjourney-account-private-media.XXXXXX")"
trap 'rm -rf "$BUILD_DIR"' EXIT

cd "$ROOT_DIR"

python3 Scripts/QA/product-v4/account-private-media-store-static-check.py
python3 Scripts/QA/product-v4/media-capture-account-lease-check.py
python3 Scripts/QA/product-v4/ai-recording-dialog-account-lease-check.py

swiftc -parse-as-library \
  DreamJourney/Sources/App/AccountSessionActor.swift \
  DreamJourney/Sources/App/AccountLease.swift \
  DreamJourney/Sources/Services/AccountPrivateMediaStore.swift \
  Scripts/QA/product-v4/account-private-media-store-model-smoke.swift \
  -o "$BUILD_DIR/account-private-media-store-model-smoke"

"$BUILD_DIR/account-private-media-store-model-smoke"

echo "Account private media store gate passed"

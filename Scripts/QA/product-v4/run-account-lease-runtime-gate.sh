#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
BUILD_DIR="$(mktemp -d "${TMPDIR:-/tmp}/dreamjourney-account-lease.XXXXXX")"
trap 'rm -rf "$BUILD_DIR"' EXIT

cd "$ROOT_DIR"

python3 Scripts/QA/product-v4/product-v4-account-lease-runtime-check.py

ACCOUNT_LEASE_STATIC_CHECKS=(
  archive-account-lease-static-check.py
  family-account-lease-static-check.py
  knowledge-sync-account-lease-check.py
  media-capture-account-lease-check.py
  message-notification-account-lease-check.py
  profile-voice-clone-account-lease-check.py
  voice-tts-account-lease-check.py
  dialog-engine-account-lease-check.py
  ai-recording-dialog-account-lease-check.py
  echo-runtime-account-lease-check.py
)

for check in "${ACCOUNT_LEASE_STATIC_CHECKS[@]}"; do
  python3 "Scripts/QA/product-v4/$check"
done

swift Scripts/QA/product-v4/dialog-engine-provider-operation-model-smoke.swift

swiftc \
  DreamJourney/Sources/App/AccountLease.swift \
  DreamJourney/Sources/App/AccountSessionActor.swift \
  Scripts/QA/product-v4/account-lease-runtime-model-smoke.swift \
  -o "$BUILD_DIR/account-lease-runtime-model-smoke"
"$BUILD_DIR/account-lease-runtime-model-smoke"

bash Scripts/QA/product-v4/run-kblite-account-lease-gate.sh
swift Scripts/QA/prd-stitch-ui/family-context-reconciliation-check.swift
swift Scripts/QA/prd-stitch-ui/knowledge-widget-privacy-lifecycle-check.swift
bash Scripts/QA/prd-stitch-ui/run-knowledge-widget-snapshot-store-model-smoke.sh

echo "Product V4 AccountLease runtime gate passed"

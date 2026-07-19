#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
BUILD_DIR="$(mktemp -d "${TMPDIR:-/tmp}/dreamjourney-qa-launch-configuration.XXXXXX")"
trap 'rm -rf "$BUILD_DIR"' EXIT

cd "$ROOT_DIR"

python3 Scripts/QA/product-v4/qa-launch-configuration-static-check.py
python3 Scripts/QA/product-v4/qa-non-echo-dispatch-inventory-check.py

swiftc -D DEBUG \
  DreamJourney/Sources/App/FeatureFlagService.swift \
  Scripts/QA/product-v4/qa-launch-configuration-model-smoke.swift \
  -o "$BUILD_DIR/qa-launch-configuration-debug-smoke"
DJ_EXPECT_QA_CONFIGURATION=1 "$BUILD_DIR/qa-launch-configuration-debug-smoke" \
  DJQAExact \
  'DJQAPrefix= value ' \
  'DJQAEmpty=   ' \
  DJRunEchoTraceExportSmoke \
  DJRunDigitalHumanLivePanelSmoke \
  DJRunProfileCareStateSmoke

swiftc \
  DreamJourney/Sources/App/FeatureFlagService.swift \
  Scripts/QA/product-v4/qa-launch-configuration-model-smoke.swift \
  -o "$BUILD_DIR/qa-launch-configuration-release-smoke"
DJ_EXPECT_QA_CONFIGURATION=0 "$BUILD_DIR/qa-launch-configuration-release-smoke" \
  DJQAExact \
  'DJQAPrefix=value' \
  DJRunDigitalHumanLivePanelSmoke \
  DJRunProfileCareStateSmoke

git diff --check -- \
  DreamJourney/Sources/App/FeatureFlagService.swift \
  DreamJourney/Sources/AppDelegate.swift \
  DreamJourney/Sources/Modules/Echo/EchoViewController.swift \
  Scripts/QA/product-v4/global-private-store-retirement-uiqa-check.py \
  Scripts/QA/product-v4/product-v4-ios-owner-truth-candidate-client-check.py \
  Scripts/QA/product-v4/qa-launch-configuration-static-check.py \
  Scripts/QA/product-v4/qa-non-echo-dispatch-inventory-check.py \
  Scripts/QA/product-v4/qa-launch-configuration-model-smoke.swift \
  Scripts/QA/product-v4/run-qa-launch-configuration-gate.sh

echo "PASS: WI-S1-03-10 QA launch configuration gate"

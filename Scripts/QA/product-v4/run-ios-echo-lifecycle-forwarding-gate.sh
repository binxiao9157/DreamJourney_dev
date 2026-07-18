#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
HOSTED_BUILD_DESTINATION="${DJ_IOS_TEST_BUILD_DESTINATION:-generic/platform=iOS}"

python3 "$ROOT/Scripts/QA/product-v4/product-v4-ios-echo-lifecycle-forwarding-check.py"
python3 "$ROOT/Scripts/QA/product-v4/product-v4-ios-lifecycle-consumer-inventory-check.py"
python3 "$ROOT/Scripts/QA/product-v4/product-v4-ios-lifecycle-event-forwarding-check.py"
swift "$ROOT/Scripts/QA/prd-stitch-ui/echo-digital-human-phase2-stability-check.swift" "$ROOT"
swift test \
  --package-path "$ROOT" \
  --scratch-path "${DJ_SWIFT_TEST_SCRATCH_PATH:-$ROOT/.build/product-v4-echo-lifecycle}"
xcodebuild build-for-testing \
  -workspace "$ROOT/DreamJourney.xcworkspace" \
  -scheme DreamJourney \
  -configuration Debug \
  -destination "$HOSTED_BUILD_DESTINATION" \
  CODE_SIGNING_ALLOWED=NO

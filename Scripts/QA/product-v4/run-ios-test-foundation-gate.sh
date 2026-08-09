#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
HOSTED_BUILD_DESTINATION="${DJ_IOS_TEST_BUILD_DESTINATION:-generic/platform=iOS}"

python3 "$ROOT/Scripts/QA/product-v4/product-v4-ios-workspace-ci-contract-check.py"
python3 "$ROOT/Scripts/QA/product-v4/product-v4-ios-lifecycle-event-forwarding-check.py"
swift "$ROOT/Scripts/QA/prd-stitch-ui/iphoneos-generic-build-check.swift" "$ROOT"
swift "$ROOT/Scripts/QA/prd-stitch-ui/installable-simulator-uiqa-bundle-guard-check.swift" "$ROOT"
python3 "$ROOT/Scripts/QA/product-v4/product-v4-ios-test-foundation-check.py"
swift test \
  --package-path "$ROOT" \
  --scratch-path "${DJ_SWIFT_TEST_SCRATCH_PATH:-$ROOT/.build/product-v4-xctest}"

# Keep the generic iPhoneOS build-for-testing default for CI environments that
# do not boot a simulator. A runnable destination executes hosted XCTest below;
# the dedicated simulator runtime gate discovers a booted device automatically.
if [[ -n "${DJ_IOS_TEST_DESTINATION:-}" ]]; then
  xcodebuild test \
    -workspace "$ROOT/DreamJourney.xcworkspace" \
    -scheme DreamJourney \
    -configuration Debug \
    -destination "$DJ_IOS_TEST_DESTINATION" \
    -only-testing:DreamJourneyTests \
    CODE_SIGNING_ALLOWED=NO
  exit 0
fi

xcodebuild build-for-testing \
  -workspace "$ROOT/DreamJourney.xcworkspace" \
  -scheme DreamJourney \
  -configuration Debug \
  -destination "$HOSTED_BUILD_DESTINATION" \
  CODE_SIGNING_ALLOWED=NO

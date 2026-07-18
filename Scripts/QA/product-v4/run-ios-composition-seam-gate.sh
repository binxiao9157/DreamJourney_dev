#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
HOSTED_BUILD_DESTINATION="${DJ_IOS_TEST_BUILD_DESTINATION:-generic/platform=iOS}"

python3 "$ROOT/Scripts/QA/product-v4/product-v4-ios-composition-seam-check.py"
swift test \
  --package-path "$ROOT" \
  --scratch-path "${DJ_SWIFT_TEST_SCRATCH_PATH:-$ROOT/.build/product-v4-composition}"

xcodebuild build-for-testing \
  -workspace "$ROOT/DreamJourney.xcworkspace" \
  -scheme DreamJourney \
  -configuration Debug \
  -destination "$HOSTED_BUILD_DESTINATION" \
  CODE_SIGNING_ALLOWED=NO

#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
HOSTED_BUILD_DESTINATION="${DJ_IOS_TEST_BUILD_DESTINATION:-generic/platform=iOS}"
IOS_TEST_DESTINATION="${DJ_IOS_TEST_DESTINATION:-platform=iOS Simulator,name=iPhone 17 Pro}"

python3 "$ROOT/Scripts/QA/product-v4/product-v4-ios-owner-truth-closed-pilot-candidate-review-check.py"
xcodebuild test \
  -workspace "$ROOT/DreamJourney.xcworkspace" \
  -scheme DreamJourney \
  -configuration Debug \
  -destination "$IOS_TEST_DESTINATION" \
  -only-testing:DreamJourneyTests/OwnerTruthContractsTests \
  CODE_SIGNING_ALLOWED=NO
xcodebuild build-for-testing \
  -workspace "$ROOT/DreamJourney.xcworkspace" \
  -scheme DreamJourney \
  -configuration Debug \
  -destination "$HOSTED_BUILD_DESTINATION" \
  CODE_SIGNING_ALLOWED=NO

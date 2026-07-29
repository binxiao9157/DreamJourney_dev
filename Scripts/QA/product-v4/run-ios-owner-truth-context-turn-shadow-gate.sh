#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
HOSTED_BUILD_DESTINATION="${DJ_IOS_TEST_BUILD_DESTINATION:-generic/platform=iOS}"

python3 "$ROOT/Scripts/QA/product-v4/product-v4-ios-owner-truth-context-turn-shadow-check.py"

# CI may provide a runnable simulator destination to execute the focused
# coordinator tests.  Otherwise this remains a non-device build gate.
if [[ -n "${DJ_IOS_TEST_DESTINATION:-}" ]]; then
  xcodebuild test \
    -workspace "$ROOT/DreamJourney.xcworkspace" \
    -scheme DreamJourney \
    -configuration Debug \
    -destination "$DJ_IOS_TEST_DESTINATION" \
    -only-testing:DreamJourneyTests/EchoApplicationCoordinatorTests \
    CODE_SIGNING_ALLOWED=NO
  exit 0
fi

xcodebuild build-for-testing \
  -workspace "$ROOT/DreamJourney.xcworkspace" \
  -scheme DreamJourney \
  -configuration Debug \
  -destination "$HOSTED_BUILD_DESTINATION" \
  CODE_SIGNING_ALLOWED=NO

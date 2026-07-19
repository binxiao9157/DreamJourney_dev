#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
HOSTED_BUILD_DESTINATION="${DJ_IOS_TEST_BUILD_DESTINATION:-generic/platform=iOS}"

python3 "$ROOT/Scripts/QA/product-v4/product-v4-ios-echo-turn-reducer-check.py"

# The complete hosted test bundle links provider SDKs that are unavailable to
# SwiftPM. Build it for iPhoneOS by default; CI may pass a runnable simulator
# destination to execute only the reducer tests.
if [[ -n "${DJ_IOS_TEST_DESTINATION:-}" ]]; then
  xcodebuild test \
    -workspace "$ROOT/DreamJourney.xcworkspace" \
    -scheme DreamJourney \
    -configuration Debug \
    -destination "$DJ_IOS_TEST_DESTINATION" \
    -only-testing:DreamJourneyTests/EchoTurnIntentReducerTests \
    CODE_SIGNING_ALLOWED=NO
  exit 0
fi

xcodebuild build-for-testing \
  -workspace "$ROOT/DreamJourney.xcworkspace" \
  -scheme DreamJourney \
  -configuration Debug \
  -destination "$HOSTED_BUILD_DESTINATION" \
  CODE_SIGNING_ALLOWED=NO
